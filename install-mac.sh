#!/usr/bin/env bash
set -Eeuo pipefail

# Installs the PikoPD build toolchain into a user-owned workspace on macOS.
# Override the default with: PIKO_HOME="$HOME/somewhere" ./install-mac.sh

PIKO_HOME="${PIKO_HOME:-$HOME/piko-workspace}"
PIKOPD_DIR="$PIKO_HOME/pikoPD"
PICO_SDK_DIR="$PIKO_HOME/pico-sdk"
HVCC_DIR="$PIKO_HOME/hvcc"
VENV_DIR="$PIKO_HOME/venv"

say() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
fail() { printf '\nError: %s\n' "$*" >&2; exit 1; }

[[ "$(uname -s)" == Darwin ]] || fail "This installer supports macOS only."
[[ "${EUID}" -ne 0 ]] || fail "Run this script as your normal user, without sudo."
command -v xcode-select >/dev/null || fail "Install Xcode Command Line Tools first: xcode-select --install"
xcode-select -p >/dev/null 2>&1 || fail "Install Xcode Command Line Tools first: xcode-select --install"
command -v brew >/dev/null || fail "Homebrew is required. Install it from https://brew.sh, then rerun this installer."

say "Installing build dependencies with Homebrew"
brew install cmake ninja pkg-config picotool python@3.13 python-tk@3.13

# Use the versioned executable explicitly: macOS may still resolve python3 to
# Apple's Python 3.9 even after Homebrew installs a newer Python.
PYTHON_BIN="$(brew --prefix python@3.13)/bin/python3.13"
"$PYTHON_BIN" - <<'PY' || fail "Homebrew Python could not run. Try: brew reinstall python@3.13"
import sys
if sys.version_info < (3, 10):
    raise SystemExit(1)
PY
say "Using Python: $PYTHON_BIN"

mkdir -p "$PIKO_HOME"

# The Homebrew arm-none-eabi-gcc formula lacks the target C/C++ libraries.
# Install Arm's complete distribution privately, without sudo or brew link conflicts.
case "$(uname -m)" in
  arm64) arm_arch=arm64; arm_sha256=c7c78ffab9bebfce91d99d3c24da6bf4b81c01e16cf551eb2ff9f25b9e0a3818 ;;
  x86_64) arm_arch=x86_64; arm_sha256=2d9e717dd4f7751d18936ae1365d25916534105ebcb7583039eff1092b824505 ;;
  *) fail "Unsupported Mac architecture: $(uname -m)" ;;
esac
arm_name="arm-gnu-toolchain-14.2.rel1-darwin-$arm_arch-arm-none-eabi"
ARM_TOOLCHAIN_DIR="$PIKO_HOME/$arm_name"
if [[ ! -x "$ARM_TOOLCHAIN_DIR/bin/arm-none-eabi-gcc" ]]; then
  say "Installing complete Arm GNU Toolchain"
  arm_tmp="$(mktemp -d "$PIKO_HOME/arm-download.XXXXXX")"
  curl -fL --retry 3 "https://developer.arm.com/-/media/Files/downloads/gnu/14.2.rel1/binrel/$arm_name.tar.xz" -o "$arm_tmp/$arm_name.tar.xz"
  printf '%s  %s\n' "$arm_sha256" "$arm_tmp/$arm_name.tar.xz" | shasum -a 256 -c -
  tar -xf "$arm_tmp/$arm_name.tar.xz" -C "$arm_tmp"
  mv "$arm_tmp/$arm_name" "$ARM_TOOLCHAIN_DIR"
  rm -f "$arm_tmp/$arm_name.tar.xz"
  rmdir "$arm_tmp"
fi
export PICO_TOOLCHAIN_PATH="$ARM_TOOLCHAIN_DIR"
export PATH="$ARM_TOOLCHAIN_DIR/bin:$PATH"
arm_libc="$(arm-none-eabi-gcc -mcpu=cortex-m0plus -mthumb -print-file-name=libc.a)"
[[ -f "$arm_libc" ]] || fail "Arm toolchain is missing libc: $arm_libc"

clone_or_update() {
  local url="$1" dir="$2" name="$3"
  if [[ -d "$dir/.git" ]]; then
    if [[ -n "$(git -C "$dir" status --porcelain)" ]]; then
      printf '\nWarning: preserving local changes in %s; not updating this checkout.\n' "$name" >&2
    else
      say "Updating $name"
      if ! git -C "$dir" pull --ff-only; then
        printf '\nWarning: could not fast-forward %s; continuing with the existing checkout.\n' "$name" >&2
      fi
    fi
  elif [[ -e "$dir" ]]; then
    fail "$dir already exists but is not a Git checkout; move it and rerun."
  else
    say "Downloading $name"
    git clone "$url" "$dir"
  fi
}

say "Setting up PikoPD and Raspberry Pi Pico SDK"
clone_or_update https://github.com/ledlaux/pikoPD.git "$PIKOPD_DIR" "PikoPD"
clone_or_update https://github.com/raspberrypi/pico-sdk.git "$PICO_SDK_DIR" "Pico SDK"
git -C "$PICO_SDK_DIR" submodule update --init --recursive
clone_or_update https://github.com/raspberrypi/pico-extras.git "$PICO_SDK_DIR/pico-extras" "pico-extras"
git -C "$PICO_SDK_DIR/pico-extras" submodule update --init --recursive

say "Installing hvcc in a private Python environment"
if [[ -e "$VENV_DIR" ]] && ! "$VENV_DIR/bin/python" -c 'import sys; sys.exit(sys.version_info < (3, 10))' >/dev/null 2>&1; then
  # Preserve an old or broken environment instead of deleting user files.
  venv_backup="$(mktemp -d "$PIKO_HOME/venv-backup.XXXXXX")"
  mv "$VENV_DIR" "$venv_backup/venv"
  say "Previous Python environment preserved in $venv_backup/venv"
fi
if [[ ! -d "$VENV_DIR" ]]; then
  "$PYTHON_BIN" -m venv "$VENV_DIR"
fi
"$VENV_DIR/bin/python" -m pip install --upgrade pip
clone_or_update https://github.com/Wasted-Audio/hvcc.git "$HVCC_DIR" "hvcc"
"$VENV_DIR/bin/python" -m pip install -e "$HVCC_DIR" -r "$PIKOPD_DIR/requirements.txt"

say "Configuring PICO_SDK_PATH in the user's Zsh startup files"
begin_marker="# >>> PikoPD toolchain >>>"
end_marker="# <<< PikoPD toolchain <<<"
write_shell_config() {
  local config_file="$1" config_line="$2" tmp_config
  tmp_config="$(mktemp)"
  if [[ -f "$config_file" ]]; then
    awk -v begin="$begin_marker" -v end="$end_marker" '
      $0 == begin { skip=1; next }
      $0 == end { skip=0; next }
      !skip { print }
    ' "$config_file" > "$tmp_config"
  fi
  {
    cat "$tmp_config"
    printf '\n%s\n%s\n%s\n' "$begin_marker" "$config_line" "$end_marker"
  } > "$config_file"
  rm -f "$tmp_config"
}

sdk_export="export PICO_SDK_PATH=$(printf '%q' "$PICO_SDK_DIR")"
sdk_export+=$'\n'"export PICO_TOOLCHAIN_PATH=$(printf '%q' "$ARM_TOOLCHAIN_DIR")"
sdk_export+=$'\n'"export PATH=$(printf '%q' "$ARM_TOOLCHAIN_DIR/bin"):\$PATH"
write_shell_config "$HOME/.zshrc" "$sdk_export"
write_shell_config "$HOME/.zprofile" "$sdk_export"

# macOS normally ignores filename case: a launcher named pikopd would
# collide with the pikoPD repository directory, even on a fresh install.
cat > "$PIKO_HOME/piko-run" <<EOF
#!/usr/bin/env bash
set -e
export PICO_SDK_PATH="$PICO_SDK_DIR"
export PICO_TOOLCHAIN_PATH="$ARM_TOOLCHAIN_DIR"
export PATH="$ARM_TOOLCHAIN_DIR/bin:\$PATH"
source "$VENV_DIR/bin/activate"
exec python "$PIKOPD_DIR/pikopd.py" "\$@"
EOF
chmod +x "$PIKO_HOME/piko-run"

say "Installation complete"
printf 'Workspace: %s\n' "$PIKO_HOME"
printf 'Build a patch: cd %q && ../piko-run patches/heavy.pd my_project\n' "$PIKOPD_DIR"
printf 'PICO_SDK_PATH is saved in ~/.zshrc and ~/.zprofile. Open a new terminal or run: source ~/.zshrc\n'
