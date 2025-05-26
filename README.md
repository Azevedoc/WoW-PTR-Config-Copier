# WoW-Config-Copier

**WoW-Config-Copier** is a modular PowerShell application designed to help World of Warcraft players easily copy configuration files from their **Live** installation to a **PTR** (Public Test Realm) installation. This interactive terminal wizard makes it simple for users—without manual editing—to select installation folders, account details, and overwrite options, then copies add-ons, settings, keybindings, macros, and game settings accordingly.

This application is written in PowerShell so there is no need for any extra dependencies installation user-side.

PS: This application automates the instructions in this [thread](https://www.reddit.com/r/classicwowtbc/comments/rybv50/comment/hrr728n/), which worked for us, but let me know if this could be improved further. This was designed and tested for Classic WoW, but should work for Retail as well.

PS2: ActionBar spell bindings are most likely server-side, so I recommend the [MySlot](https://www.curseforge.com/wow/addons/myslot) addon if you need it. (If you have any suggestions on how to solve that client-side, I'm all ears.)

## Features

- **Interactive Folder Selection:**  
  - Prompts for the main WoW installation folder using a registry lookup (or a default value) with an option for manual entry.
  - Displays only subdirectories whose names start with an underscore (e.g., `_retail_`, `_classic_`) for selecting the **Live** and **PTR** installations.
  - Provides an interactive wizard to select account, realm, and character folders from within the `WTF\Account` directory.

- **Custom Overwrite Options:**  
  Before copying, the script prompts whether to always overwrite, never overwrite, or ask for each directory copy (via Robocopy) and file copy (via Copy-Item).

- **Configuration Management:**
  - Save your current configuration to a JSON file for future use
  - Import previously saved configurations

## Prerequisites

- **Windows PowerShell** (v5.1 or higher) - A normal Windows 10/11 install should have this by default.
- The script must be run in an **elevated PowerShell session** (i.e., "Run as Administrator") if WoW is installed in protected directories like Program Files.

## Usage

0. **Log in with your PTR character:**
   - Before doing anything, log in to the PTR, copy your character(s) if not done already, enter the world, then exit the game.
   - This will create the necessary local folder structure needed for the script to work.
   - Note: Game must be closed during the copy process or it may conflict with files being modified.

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
   - Choose whether to use the interactive wizard or import a previously saved configuration
   - If using the wizard:
     - Select the main WoW folder, then choose your Live and PTR installation subfolders.
     - Select your Account, Realm, and Character folders.
   - Choose your overwrite option:
     - Yes – Always mirror Live to PTR. **Warning:** This will delete files in the PTR target folder if they don't exist in the Live source folder, making the PTR configuration an exact replica of Live for the selected components.
     - No – Never overwrite (only copy new files, leaving existing PTR files untouched).
     - Ask – Prompt for each major configuration step (e.g., Addons, Account Settings) whether to mirror or only copy new files for that step.

## Project Structure

- **CopyWoWConfigs.ps1** - Main script file and entry point
- **saved_exports/** - Directory for saved configuration files

## How It Works

- **Elevation Check:**
  Ensures the script runs with administrator privileges by checking the current Windows identity. If not elevated, it prompts to restart the script in elevated mode.

- **Folder Selection:**
  Provides a consistent, interactive interface to list and select subdirectories with support for filtering, manual entry, and navigation options.

- **Interactive Prompts:**
  Guides the user step-by-step through selecting installation folders, account folders, realms, and characters.

- **Overwrite Handling:**
  Allows you to specify your preferred copy behavior:
  - **Yes (Mirror):** Makes the selected PTR configuration components an exact replica of the Live components. Files in the PTR destination that are not present in the Live source will be deleted.
  - **No (Copy New):** Copies only files from Live that do not already exist in PTR, leaving existing PTR files untouched.
  - **Ask (Per Operation):** For each major configuration step (like AddOns, SavedVariables, specific game settings files), you'll be prompted to choose whether to mirror or only copy new files for that particular step.

- **Copy Operations:**
  Uses Robocopy for robust directory copying and Copy-Item for individual file copying, ensuring that your PTR folder mirrors your Live configuration as desired.

## Contributing

Contributions are welcome! Feel free to fork this repository and submit pull requests. If you find bugs or have suggestions for improvements, please open an issue.

## License

This project is licensed under the MIT License. See the LICENSE file for details.
