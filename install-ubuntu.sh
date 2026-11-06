#!/usr/bin/env bash
set -Eeuo pipefail

# Installs the PikoPD build toolchain into a user-owned workspace.
# Override the default with: PIKO_HOME="$HOME/somewhere" ./install-ubuntu.sh

PIKO_HOME="${PIKO_HOME:-$HOME/piko-workspace}"
PIKOPD_DIR="$PIKO_HOME/pikoPD"
PICO_SDK_DIR="$PIKO_HOME/pico-sdk"
PICOTOOL_DIR="$PIKO_HOME/picotool"
HVCC_DIR="$PIKO_HOME/hvcc"
VENV_DIR="$PIKO_HOME/venv"

say() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
fail() { printf '\nError: %s\n' "$*" >&2; exit 1; }

[[ "$(uname -s)" == Linux ]] || fail "This installer supports Ubuntu Linux only."
[[ -r /etc/os-release ]] || fail "Cannot identify this Linux distribution."
# shellcheck disable=SC1091
source /etc/os-release
[[ "${ID:-}" == ubuntu ]] || fail "Ubuntu is required (detected: ${PRETTY_NAME:-unknown})."
command -v apt-get >/dev/null || fail "apt-get was not found."
command -v sudo >/dev/null || fail "sudo is required to install Ubuntu packages."
[[ "${EUID}" -ne 0 ]] || fail "Run this script as your normal user, without sudo."

run_as_admin() {
  if [[ "${PIKOPD_GUI:-0}" == 1 ]]; then
    command -v pkexec >/dev/null || fail "pkexec is required by the graphical installer."
    pkexec "$@"
  else
    sudo "$@"
  fi
}

say "Installing system build dependencies"
apt_update_log="$(mktemp)"
if ! run_as_admin apt-get update 2>&1 | tee "$apt_update_log"; then
  other_apt_errors="$(grep -E '^(Err:|Fehl:|E:|W:)' "$apt_update_log" | grep -Fv 'download.virtualbox.org' || true)"
  # apt-get update checks every configured APT source, including unrelated
  # third-party repositories. Ignore only this known VirtualBox missing-key
  # failure: Ubuntu's own package indexes have still been refreshed.
  if grep -Fq 'download.virtualbox.org/virtualbox/debian' "$apt_update_log" \
      && grep -Fq 'NO_PUBKEY A2F683C52980AECF' "$apt_update_log" \
      && [[ -z "$other_apt_errors" ]]; then
    printf '\nWarning: the configured VirtualBox APT source has a missing signing key.\n' >&2
    printf 'Continuing with Ubuntu package indexes; this installer does not modify VirtualBox.\n\n' >&2
  else
    rm -f "$apt_update_log"
    fail "apt-get update failed. Fix the APT source error shown above, then rerun this installer."
  fi
fi
rm -f "$apt_update_log"
run_as_admin apt-get install -y \
  build-essential cmake git ninja-build pkg-config \
  python3 python3-tk python3-venv python3-pip \
  gcc-arm-none-eabi libnewlib-arm-none-eabi libstdc++-arm-none-eabi-newlib

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

say "Building and installing picotool"
clone_or_update https://github.com/raspberrypi/picotool.git "$PICOTOOL_DIR" "picotool"
picotool_build_dir="$PICOTOOL_DIR/build"
cmake_generator_args=(-G Ninja)
if [[ -f "$picotool_build_dir/CMakeCache.txt" ]]; then
  existing_generator="$(sed -n 's/^CMAKE_GENERATOR:INTERNAL=//p' "$picotool_build_dir/CMakeCache.txt" | head -n 1)"
  if [[ -n "$existing_generator" ]]; then
    say "Reusing existing CMake generator: $existing_generator"
    cmake_generator_args=(-G "$existing_generator")
  fi
fi
cmake -S "$PICOTOOL_DIR" -B "$picotool_build_dir" "${cmake_generator_args[@]}" \
  -DPICO_SDK_PATH="$PICO_SDK_DIR" \
  -DCMAKE_BUILD_TYPE=Release
cmake --build "$PICOTOOL_DIR/build" --parallel
run_as_admin cmake --install "$PICOTOOL_DIR/build"

say "Configuring PICO_SDK_PATH in the user's shell startup files"
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

login_shell="${SHELL##*/}"
case "$login_shell" in
  zsh)
    write_shell_config "$HOME/.zshrc" "export PICO_SDK_PATH=$(printf '%q' "$PICO_SDK_DIR")"
    write_shell_config "$HOME/.zprofile" "export PICO_SDK_PATH=$(printf '%q' "$PICO_SDK_DIR")"
    shell_config_to_source="$HOME/.zshrc"
    ;;
  bash)
    write_shell_config "$HOME/.bashrc" "export PICO_SDK_PATH=$(printf '%q' "$PICO_SDK_DIR")"
    write_shell_config "$HOME/.profile" "export PICO_SDK_PATH=$(printf '%q' "$PICO_SDK_DIR")"
    shell_config_to_source="$HOME/.bashrc"
    ;;
  fish)
    fish_config_dir="$HOME/.config/fish/conf.d"
    mkdir -p "$fish_config_dir"
    fish_env="set -gx PICO_SDK_PATH \"$PICO_SDK_DIR\""
    write_shell_config "$fish_config_dir/pikopd.fish" "$fish_env"
    shell_config_to_source="$fish_config_dir/pikopd.fish"
    ;;
  *)
    write_shell_config "$HOME/.profile" "export PICO_SDK_PATH=$(printf '%q' "$PICO_SDK_DIR")"
    shell_config_to_source="$HOME/.profile"
    ;;
esac

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
printf 'PICO_SDK_PATH is saved in %s. Run: source %q (or open a new terminal).\n' "$shell_config_to_source" "$shell_config_to_source"
