#!/bin/bash
set -Eeuo pipefail

# Also works from Finder on a Mac without a working system Python.
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
ROOT="$(cd -- "$(dirname -- "$0")" && pwd)"

fail() {
  printf '\nPikoSetup: %s\n' "$*" >&2
  if [[ -t 0 ]]; then
    read -r -p 'Press Return to close… ' || true
  fi
  exit 1
}

[[ "$(uname -s)" == Darwin ]] || fail "This launcher supports macOS only."
command -v brew >/dev/null || fail "Install Homebrew from https://brew.sh, then reopen this launcher."

# Ask Homebrew for its prefix rather than assuming Intel or Apple Silicon.
python_prefix="$(brew --prefix python@3.13)" || fail "Could not locate Homebrew Python."
python_bin="$python_prefix/bin/python3.13"
probe='import sys, tkinter; sys.exit(sys.version_info < (3, 10) or tkinter.TkVersion < 8.6)'
if ! "$python_bin" -c "$probe" >/dev/null 2>&1; then
  printf '\nPikoSetup: preparing Python and Tk for the Mac interface (first launch)…\n'
  brew install python@3.13 python-tk@3.13 || fail "Could not install Python/Tk. Check the Homebrew output above and reopen this launcher to retry."
fi
"$python_bin" -c "$probe" >/dev/null 2>&1 || fail "Python/Tk is unavailable after installation. Try: brew reinstall python@3.13 python-tk@3.13"
exec "$python_bin" "$ROOT/piko-setup" "$@"
