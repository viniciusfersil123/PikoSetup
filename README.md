# PikoSetup

An Ubuntu installer for the **PikoPD** toolchain. It prepares a clean Ubuntu system to build Pure Data (`.pd`) patches into UF2 firmware for Raspberry Pi Pico.

## Install

Open the graphical installer from this repository:

```bash
./piko-setup
```

The window has an **Install** button and displays the installer's output. After a successful installation, the button changes to **Run / Flash**. Use **Browse…** to choose a Pure Data patch and a board configuration JSON file. The selections are saved in `~/.config/pikosetup/preferences.json` and remain selected when you reopen the program, until you change them. **Run / Flash** builds the selected patch and flashes the firmware to the Pico. Connect the board in BOOTSEL mode and confirm the flash in the dialog. Ubuntu's authorization dialog handles administrative access. If Tkinter is missing, the launcher asks for authorization to install `python3-tk` before opening the window.

On future launches, the app checks whether the toolchain is installed. If it is, the window opens directly with **Run / Flash**.

You can also run the installer from a terminal:

```bash
./install-ubuntu.sh
```

Run it as your normal user, without `sudo`. It will request administrator authorization when needed. An internet connection is required.

`apt-get update` checks all APT repositories already configured on the system. If its only error is the missing VirtualBox key (`NO_PUBKEY A2F683C52980AECF`), the installer warns and continues using the Ubuntu package indexes. It does not install or change VirtualBox. Other APT errors stop the installation.

By default, the toolchain is installed in `~/piko-workspace`. To use a different folder:

```bash
PIKO_HOME="$HOME/Documents/PikoPD" ./install-ubuntu.sh
```

## Installed components

- Ubuntu build packages, CMake, Ninja, Git, Python 3, and the `arm-none-eabi` compiler.
- The PikoSetup graphical interface, built with Python Tk.
- The PikoPD repository and example patches.
- Raspberry Pi Pico SDK and pico-extras, including their Git submodules.
- hvcc and Jinja2 in an isolated Python virtual environment.
- picotool, built and installed on the system.
- `PICO_SDK_PATH` in the detected shell's startup file (Bash, Zsh, or Fish), plus a `pikopd` launcher in the workspace.

## Build a patch from the terminal

After installation, open a new terminal or run the `source` command printed by the installer. Then:

```bash
cd ~/piko-workspace/pikoPD
../pikopd patches/heavy.pd my_project
```

The generated UF2 file is in the new project's `build` folder. To flash from the terminal, connect the Pico in BOOTSEL mode and add `-f`:

```bash
../pikopd patches/heavy.pd my_project -f
```

## Scope

This installer prepares the Ubuntu build environment. It does not install Pure Data or PlugData, configure hardware or `board.json`, or install the web configuration tool. The upstream `-s` serial monitor currently uses macOS-specific Terminal integration, so it is not configured for Ubuntu.

You can rerun the installer to update repositories and complete setup. If a checkout has local changes, the installer preserves them and skips updating that checkout. If a destination folder exists but is not a Git checkout, the installer stops without deleting it.
