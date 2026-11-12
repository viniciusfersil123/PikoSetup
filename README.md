# PikoSetup 🎛️

PikoSetup prepares your computer to turn a [Pure Data](https://puredata.info/) patch into firmware for a Raspberry Pi Pico using [PikoPD](https://github.com/ledlaux/pikoPD).

It supports **Ubuntu Linux** and **macOS**. The graphical app guides you through setup, building, and flashing.

## What you need

- A computer running Ubuntu or macOS, plus an internet connection.
- A Raspberry Pi Pico and a USB cable that supports data.
- A Pure Data patch (`.pd`) and a board configuration (`.json`). PikoPD includes example patches and a `board.json` to get started.
- On Ubuntu, your password may be requested to install system packages.
- On macOS, install [Homebrew](https://brew.sh) and Xcode Command Line Tools. To install the command line tools, open Terminal and run `xcode-select --install`.

PikoSetup installs the tools that build firmware. It does **not** install the Pure Data or PlugData desktop app; install one separately if you want to create or edit patches.

## 1. Download and open the project 📦

To download it from GitHub:

1. Open the [PikoSetup GitHub page](https://github.com/viniciusfersil123/PikoSetup).
2. Click the green **Code** button, then choose **Download ZIP**.
3. When the download finishes, open your **Downloads** folder and extract the ZIP. On macOS, double-click the ZIP; on Ubuntu, right-click it and choose **Extract Here**.
4. Open the extracted `PikoSetup` folder. Keep its files together; do not run the installer from inside the ZIP preview.

## 2. Open PikoSetup 🚀

Run these commands from the PikoSetup project folder.

**Ubuntu:**

```bash
./piko-setup
```

**macOS:** double-click `piko-setup-mac.command` in Finder, or run:

```bash
./piko-setup-mac.command
```

The Mac launcher prepares the Python and Tk support used by the window on its first launch. Keep it in the same folder as `piko-setup`.

## 3. Install the toolchain 🧰

Choose **Linux (Ubuntu)** or **macOS** in the app, then click **Install**. This step downloads the Pico SDK and build tools, so it can take a while. Leave the computer connected to the internet.

When installation finishes, the button changes to **Run / Flash**. PikoSetup remembers your operating system, patch, and board configuration for next time.

## 4. Build and flash a patch 🎵

1. PikoSetup starts with `test.pd` and `board.json` from the downloaded PikoSetup folder. Use **Browse…** to choose different files if needed.
2. Connect the Pico in BOOTSEL mode: hold the **BOOTSEL** button while plugging the Pico into USB, then release the button.
3. Click **Run / Flash** and confirm. PikoSetup builds the patch and sends the firmware to the Pico.

The app shows build progress and reports whether flashing succeeded. If it fails, check the messages in the output area and make sure the Pico is connected in BOOTSEL mode.

## Optional: use the terminal 💻

You can install the toolchain without opening the graphical app.

**Ubuntu:**

```bash
./install-ubuntu.sh
```

**macOS:** first install Homebrew and Xcode Command Line Tools as described above, then run:

```bash
./install-mac.sh
```

Run the installer as your regular user, without `sudo`. Ubuntu asks for administrator authorization when required. On macOS, the installer uses Homebrew for CMake, Ninja, picotool, and Python. It installs the Arm compiler and Pico build dependencies in your workspace.

By default, files are installed in `~/piko-workspace`. To choose a different location:

```bash
PIKO_HOME="$HOME/Documents/PikoPD" ./install-ubuntu.sh
# On macOS, run this command instead:
PIKO_HOME="$HOME/Documents/PikoPD" ./install-mac.sh
```

After installation, open a new terminal (or run the `source` command printed by the installer), then build a patch:

```bash
cd ~/piko-workspace/pikoPD
../piko-run patches/heavy.pd my_project
```

To flash from the terminal, connect the Pico in BOOTSEL mode and add `-f`:

```bash
../piko-run patches/heavy.pd my_project -f
```

The generated firmware is in the new project's `build` folder.

## What gets installed

- The PikoPD project and example patches.
- Raspberry Pi Pico SDK and pico-extras.
- CMake, Ninja, picotool, the Arm compiler, and Python build dependencies.
- A private Python environment and a `piko-run` command in the workspace.

The installers preserve local changes in existing Git checkouts. If a destination folder exists but is not a Git checkout, setup stops and asks you to move it; it will not delete that folder.
