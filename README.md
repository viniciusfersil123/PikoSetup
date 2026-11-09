# PikoSetup

A graphical installer for the **PikoPD** toolchain. It prepares Ubuntu or macOS to build Pure Data (`.pd`) patches into UF2 firmware for Raspberry Pi Pico.

## Install

Open the graphical installer from this repository and choose the operating system:

```bash
./piko-setup
```

The window has an **Install** button and displays the installer's output. The operating system choice and selected patch and board configuration are saved in `~/.config/pikosetup/preferences.json`. After a successful installation, the button changes to **Run / Flash**. **Run / Flash** builds the selected patch and flashes the firmware to the Pico. Connect the board in BOOTSEL mode and confirm the flash in the dialog. Ubuntu's authorization dialog handles administrative access. If Tkinter is missing on Ubuntu, the launcher asks for authorization to install `python3-tk` before opening the window.

On future launches, the app checks whether the toolchain is installed. If it is, the window opens directly with **Run / Flash**.

On macOS, you can also double-click `piko-setup-mac.command` in Finder, or run
`./piko-setup-mac.command`. This launcher works without a preinstalled Python,
provided Xcode Command Line Tools and Homebrew are installed. On first launch,
it installs Homebrew Python 3.13 and its Tk package if needed, then opens the
graphite interface. Later launches reuse them. The regular `./piko-setup` also
switches to this launcher automatically if its Python has missing or obsolete
Tk. Both Intel and Apple Silicon Homebrew prefixes are supported. Keep the
launcher beside `piko-setup` when copying or distributing the project.

On Ubuntu, you can also run the installer from a terminal:

```bash
./install-ubuntu.sh
```

Run it as your normal user, without `sudo`. It will request administrator authorization when needed. An internet connection is required.

On macOS, install Xcode Command Line Tools and [Homebrew](https://brew.sh), then run:

```bash
./install-mac.sh
```

The macOS installer uses Homebrew for CMake, Ninja, picotool,
and Python 3.13 with its Tk package. It installs the complete Arm GNU Toolchain
14.2.rel1 directly from Arm into the workspace, verifies its SHA-256 checksum,
and configures `piko-run` to use it. This includes the C/C++ libraries required
for Pico firmware and needs no administrator password. It selects Homebrew's Python explicitly, so an older system
`python3` does not block installation. An internet connection is required.
An existing Python environment that is broken or older than 3.10 is backed up
inside the workspace before a new one is created.

`apt-get update` checks all APT repositories already configured on the system. If its only error is the missing VirtualBox key (`NO_PUBKEY A2F683C52980AECF`), the installer warns and continues using the Ubuntu package indexes. It does not install or change VirtualBox. Other APT errors stop the installation.

By default, the toolchain is installed in `~/piko-workspace`. To use a different folder:

```bash
PIKO_HOME="$HOME/Documents/PikoPD" ./install-ubuntu.sh
# or on macOS:
PIKO_HOME="$HOME/Documents/PikoPD" ./install-mac.sh
```

## Installed components

- Ubuntu build packages, or macOS build tools from Homebrew, including CMake, Ninja, Python 3, and the `arm-none-eabi` compiler.
- The PikoSetup graphical interface, built with Python Tk.
- The PikoPD repository and example patches.
- Raspberry Pi Pico SDK and pico-extras, including their Git submodules.
- hvcc and PikoPD's Python dependencies (Jinja2 and pyserial) in an isolated Python virtual environment.
- picotool, built and installed on the system.
- `PICO_SDK_PATH` in the detected shell's startup file (Bash, Zsh, or Fish), plus a `piko-run` launcher in the workspace. This name avoids colliding with the `pikoPD` repository on case-insensitive Mac filesystems.

## Build a patch from the terminal

After installation, open a new terminal or run the `source` command printed by the installer. Then:

```bash
cd ~/piko-workspace/pikoPD
../piko-run patches/heavy.pd my_project
```

The generated UF2 file is in the new project's `build` folder. To flash from the terminal, connect the Pico in BOOTSEL mode and add `-f`:

```bash
../piko-run patches/heavy.pd my_project -f
```

## Scope

These installers prepare the Ubuntu or macOS build environment. They do not install Pure Data or PlugData, configure hardware or `board.json`, or install the web configuration tool. The upstream `-s` serial monitor currently uses macOS-specific Terminal integration.

You can rerun the installer to update repositories and complete setup. If a checkout has local changes, the installer preserves them and skips updating that checkout. If a destination folder exists but is not a Git checkout, the installer stops without deleting it.
