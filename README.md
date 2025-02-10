# WoW-PTR-Config-Copier

**WoW-PTR-Config-Copier** is a PowerShell script designed to help World of Warcraft players easily copy configuration files from their **Live** installation to a **PTR** (Public Test Realm) installation. This interactive terminal wizard makes it simple for users—without manual editing—to select installation folders, account details, and overwrite options, then copies add-ons, settings, keybindings, macros, and game settings accordingly. I chose to write it in PowerShell so there is no need for any extra dependencies installation user-side.

PS: This mainly automates the instructions in this [thread](https://www.reddit.com/r/classicwowtbc/comments/rybv50/comment/hrr728n/), which worked for us, but let me know if this could be improved further. This was designed and tested for classic, but could likely work for retail. Could try to check for it if there is any interest on it.

PS2: ActionBar spell bindings is most likely server-side, so I recommend the [MySlot](https://www.curseforge.com/wow/addons/myslot) addon if you need it. (If you have any suggestions on tip on how to solve that client-side, I'm all ears.)

## Features

- **Interactive Folder Selection:**  
  - Prompts for the main WoW installation folder using a registry lookup (or a default value) with an option for manual entry.
  - Displays only subdirectories whose names start with an underscore (e.g., `_retail_`, `_classic_`) for selecting the **Live** and **PTR** installations.
  - Provides an interactive wizard to select account, realm, and character folders from within the `WTF\Account` directory.

- **Custom Overwrite Options:**  
  Before copying, the script prompts whether to always overwrite, never overwrite, or ask for each directory copy (via Robocopy) and file copy (via Copy-Item).

## Prerequisites

- **Windows PowerShell** (v5 or higher is recommended) - A normal windows 11 install should have this by default. Win 10 also very likely.
- The script must be run in an **elevated PowerShell session** (i.e., "Run as Administrator") to access protected directories e.g if WoW is installed in Program Files on your main drive. You can run without it depending where it is.

## Usage

0. **Log in with your PTR character:**
   - Before doing anything, log in the PTR, copy your character(s) if not done so, enter the world, then exit the game. (Game must be closed or it will try to overwrite things)
   - This will create the necessary local folder structure needed for the script to work.

1. **Clone or Download** the repository:
   ```bash
   git clone https://github.com/Azevedoc/WoW-PTR-Config-Copier.git
   ```

2. **Open PowerShell as Administrator:**
   Right-click the PowerShell icon and choose Run as Administrator.

3. **Navigate to the Script Folder:**
   ```powershell
   cd path\to\WoW-PTR-Config-Copier
   ```

4. **Run the Script:**
   ```powershell
   .\CopyWoWConfigs.ps1
   ```

5. **Follow the Interactive Prompts:**
   - Select the main WoW folder, then choose your Live and PTR installation subfolders.
   - Select your Account, Realm, and Character folders.
   - Finally, choose your overwrite option:
     - Yes – Always overwrite existing files.
     - No – Never overwrite (only copy new files).
     - Ask – Prompt for each directory copy whether to overwrite existing files.

## How It Works

The script is organized into several key sections:

- **Elevation Check:**
  Ensures the script runs with administrator privileges by checking the current Windows identity. If not elevated, it prompts to restart the script in elevated mode.

- **Folder Selection Functions:**
  - `Select-Folder` provides a consistent, interactive interface to list and select subdirectories. It supports filtering (to show only folders beginning with `_`), manual entry, and options to go back or exit.
  - `Get-WoWMainFolder` attempts to detect the main WoW installation folder via the registry.

- **Interactive Prompts:**
  Guides the user step-by-step through selecting the installation folders, account folders, realms, and characters.

- **Overwrite Handling:**
  Allows you to specify whether to always overwrite existing files, never overwrite, or prompt for each directory copy individually. For Robocopy operations, the script builds the appropriate set of switches based on your choice.

- **Copy Operations:**
  Uses Robocopy for robust directory copying (with dynamically built switch arrays) and Copy-Item for individual file copying, ensuring that your PTR folder mirrors your Live configuration as desired.

## Contributing

Contributions are welcome! Feel free to fork this repository and submit pull requests. If you find bugs or have suggestions for improvements, please open an issue.

## License

This project is licensed under the MIT License. See the LICENSE file for details.
