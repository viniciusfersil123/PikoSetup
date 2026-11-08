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
brew install cmake ninja pkg-config arm-none-eabi-gcc picotool

python3 - <<'PY' || fail "Python 3.10 or newer is required."
import sys
if sys.version_info < (3, 10):
    raise SystemExit(1)
PY

mkdir -p "$PIKO_HOME"

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
if [[ ! -d "$VENV_DIR" ]]; then
  python3 -m venv "$VENV_DIR"
fi
"$VENV_DIR/bin/python" -m pip install --upgrade pip
clone_or_update https://github.com/Wasted-Audio/hvcc.git "$HVCC_DIR" "hvcc"
"$VENV_DIR/bin/pip" install -e "$HVCC_DIR" jinja2

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
write_shell_config "$HOME/.zshrc" "$sdk_export"
write_shell_config "$HOME/.zprofile" "$sdk_export"

cat > "$PIKO_HOME/pikopd" <<EOF
#!/usr/bin/env bash
set -e
export PICO_SDK_PATH="$PICO_SDK_DIR"
source "$VENV_DIR/bin/activate"
exec python "$PIKOPD_DIR/pikopd.py" "\$@"
EOF
chmod +x "$PIKO_HOME/pikopd"

say "Installation complete"
printf 'Workspace: %s\n' "$PIKO_HOME"
printf 'Build a patch: cd %q && ./pikopd patches/heavy.pd my_project\n' "$PIKOPD_DIR"
printf 'PICO_SDK_PATH is saved in ~/.zshrc and ~/.zprofile. Open a new terminal or run: source ~/.zshrc\n'
