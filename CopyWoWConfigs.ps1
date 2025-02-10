<#
.SYNOPSIS
    WoW-PTR-Config-Copier – Copies Live configuration files to PTR installation.

.DESCRIPTION
    This PowerShell script creates an interactive terminal wizard that:
      - Checks for elevation and, if needed, offers to relaunch itself as Administrator.
      - Prompts the user for the MAIN WoW installation folder using a registry lookup (or a default value),
        then lets the user select the LIVE and PTR installation subfolders.
          • When selecting these, only subfolders whose names begin with "_" (e.g. "_retail_", "_classic_")
            are shown.
          • An extra manual entry option is provided in case the folder isn’t under the main folder.
      - Lists available folders (subdirectories) under the WTF\Account directory so users can
        select their Account, Realm, and Character folders (returning only the folder names).
      - Provides an option to go “back” (to the previous selection) or exit when an invalid
        input is encountered or no subdirectories exist.
      - Prompts the user whether to overwrite existing files in the PTR folder:
            • Yes – always overwrite  
            • No – never overwrite (only copy new files)  
            • Ask – prompt for each robocopy operation individually  
      - Copies configuration files (using robocopy for directories and Copy-Item for files)
        from the LIVE installation to the PTR installation.
        
.NOTES
    Run in an elevated PowerShell session.
#>

# ============================================================
# Elevation Check & Relaunch as Administrator if Needed
# ============================================================
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    Write-Host "This script is not running as Administrator."
    Write-Host "Some/All operations may fail due to insufficient permissions if WoW is installed in a protected directory."
    $response = Read-Host "Would you like to restart it with administrative privileges? (Y/N)"
    if ($response -match '^(Y|y)$') {
        $scriptPath = $PSCommandPath
        if (-not $scriptPath) { $scriptPath = $MyInvocation.MyCommand.Path }
        $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
        Start-Process powershell.exe -Verb RunAs -ArgumentList $arguments
        Exit
    }
    else {
        Write-Host "Continuing without administrative privileges. Note that some operations may fail."
    }
}

# ============================================================
# Function: Select-Folder with Back/Exit and Manual Entry Options
# ============================================================
<#
.SYNOPSIS
    Lists subdirectories in a given path and prompts the user to select one.

.DESCRIPTION
    This function retrieves immediate subdirectories of the specified path and displays them
    as an indexed list. If a filter regex is provided via -FilterRegex, only folders whose
    names match the regex are shown. If the -IncludeManual switch is used, a "[M] Manual Entry"
    option is added. In all cases, "[B] Back" and "[X] Exit" options are always displayed.
    
    - When -ReturnNameOnly is specified, the function returns only the folder name (not the full path).
    - If no subdirectories are found (after filtering), the user is given the option to go back,
      exit, or manually type in a folder.
#>
function Select-Folder {
    param(
         [Parameter(Mandatory = $true)]
         [string]$Path,
         [string]$Prompt = "Select a folder:",
         [string]$FilterRegex,
         [switch]$IncludeManual,
         [switch]$ReturnNameOnly
    )
    # Clear the terminal and display a header
    Clear-Host
    Write-Host "----------------------------------------"
    Write-Host $Prompt
    Write-Host "Base path: $Path"
    Write-Host "----------------------------------------"

    if (-not (Test-Path $Path)) {
         Write-Host "Path '$Path' does not exist."
         return "BACK"
    }
    $dirs = Get-ChildItem -Path $Path -Directory | Sort-Object Name
    if ($FilterRegex) {
        $dirs = $dirs | Where-Object { $_.Name -match $FilterRegex }
    }
    if ($dirs.Count -eq 0) {
         Write-Host "No subdirectories matching the filter were found in $Path."
         $choice = Read-Host "Press [B] to go back, [X] to exit, or [M] for manual entry"
         if ($choice -match "^[Bb]$") {
             return "BACK"
         } elseif ($choice -match "^[Mm]$") {
             $manualEntry = Read-Host "Enter the folder" 
             if ($ReturnNameOnly) {
                 return $manualEntry.Trim()
             } else {
                 return $manualEntry
             }
         } else {
             Exit
         }
    }
    # Display available options
    for ($i = 0; $i -lt $dirs.Count; $i++) {
       Write-Host "[$i] $($dirs[$i].Name)"
    }
    Write-Host "[B] Back"
    Write-Host "[X] Exit"
    if ($IncludeManual) {
       Write-Host "[M] Manual Entry (type a custom folder path)"
    }
    do {
       $extraOption = if ($IncludeManual) { ", M" } else { "" }
       $selection = Read-Host "Enter your selection (number, B, X$extraOption)"
       if ($selection -match '^\d+$' -and [int]$selection -ge 0 -and [int]$selection -lt $dirs.Count) {
           if ($ReturnNameOnly) {
               return $dirs[[int]$selection].Name
           } else {
               return $dirs[[int]$selection].FullName
           }
       } elseif ($selection -match '^[Bb]$') {
           return "BACK"
       } elseif ($selection -match '^[Xx]$') {
           Exit
       } elseif ($IncludeManual -and $selection -match '^[Mm]$') {
           $manualEntry = Read-Host "Enter the folder path manually"
           if ($ReturnNameOnly) {
               return $manualEntry.Trim()
           } else {
               return $manualEntry
           }
       } else {
           Write-Host "Invalid selection. Please try again."
       }
    } until ($false)
}

# ============================================================
# Function: Get-WoWMainFolder
# ============================================================
<#
.SYNOPSIS
    Retrieves the main World of Warcraft installation folder from the registry.

.DESCRIPTION
    This function looks up the registry key used by Blizzard to store WoW’s installation path.
    If the returned folder’s leaf starts with an underscore (e.g. "_retail_" or "_classic_"),
    the function returns its parent folder. If the lookup fails, it returns $null.
#>
function Get-WoWMainFolder {
    $wowMain = $null
    try {
        $wowKey = "HKLM:\SOFTWARE\WOW6432Node\Blizzard Entertainment\World of Warcraft"
        $wowProps = Get-ItemProperty -Path $wowKey -ErrorAction SilentlyContinue
        if ($wowProps -and $wowProps.InstallPath) {
            $wowMain = $wowProps.InstallPath
            $leaf = Split-Path $wowMain -Leaf
            if ($leaf -like "_*") {
                $wowMain = Split-Path $wowMain -Parent
            }
        }
    }
    catch {
        # On error, return $null.
    }
    return $wowMain
}

# ============================================================
# Prompt for Main WoW Installation Folder
# ============================================================
$detectedMainWowFolder = Get-WoWMainFolder
if (-not $detectedMainWowFolder) {
    $detectedMainWowFolder = "C:\Program Files (x86)\World of Warcraft"
}
$defaultMainWowFolder = $detectedMainWowFolder
$mainWowFolderPrompt = "Enter your MAIN WoW installation folder. Leave Blank and press enter if shown value is correct: [`"$defaultMainWowFolder`"]"
$mainWowFolder = Read-Host $mainWowFolderPrompt
if ([string]::IsNullOrWhiteSpace($mainWowFolder)) { 
    $mainWowFolder = $defaultMainWowFolder 
}
Write-Host "`nMain WoW folder set to: $mainWowFolder"
Pause

# ============================================================
# Interactive Selection for LIVE and PTR Installations
# ============================================================
Clear-Host
Write-Host "----------------------------------------"
Write-Host "Select your LIVE installation folder from:"
Write-Host "$mainWowFolder"
Write-Host "----------------------------------------"
$liveDir = Select-Folder -Path $mainWowFolder -Prompt "Select LIVE installation folder:" -FilterRegex "^_" -IncludeManual
Write-Host "LIVE installation folder set to: $liveDir"
Pause

Clear-Host
Write-Host "----------------------------------------"
Write-Host "Select your PTR installation folder from:"
Write-Host "$mainWowFolder"
Write-Host "----------------------------------------"
$ptrDir = Select-Folder -Path $mainWowFolder -Prompt "Select PTR installation folder, or choose Manual if it's on a different disk:" -FilterRegex "^_" -IncludeManual
Write-Host "PTR installation folder set to: $ptrDir"
Pause

# ============================================================
# Interactive Selection of LIVE Folders (Account, Realm, Character)
# ============================================================
Clear-Host
Write-Host "==== LIVE Account Information ===="
$liveAccountPath = Join-Path $liveDir "WTF\Account"

do {
    $liveAccount = Select-Folder -Path $liveAccountPath -Prompt "Select your LIVE Account folder:" -ReturnNameOnly
    if ($liveAccount -eq "BACK") {
        Write-Host "Cannot go back from the first selection. Please select an account folder."
    }
} until ($liveAccount -ne "BACK")

while ($true) {
    $currentAccountPath = Join-Path $liveAccountPath $liveAccount
    $liveRealm = Select-Folder -Path $currentAccountPath -Prompt "Select your LIVE Realm folder:" -ReturnNameOnly
    if ($liveRealm -eq "BACK") {
        do {
            $liveAccount = Select-Folder -Path $liveAccountPath -Prompt "Select your LIVE Account folder:" -ReturnNameOnly
            if ($liveAccount -eq "BACK") {
                Write-Host "Cannot go back from the first selection. Please select an account folder."
            }
        } until ($liveAccount -ne "BACK")
        continue
    } else {
        break
    }
}

while ($true) {
    $currentRealmPath = Join-Path $currentAccountPath $liveRealm
    $liveCharacter = Select-Folder -Path $currentRealmPath -Prompt "Select your LIVE Character folder:" -ReturnNameOnly
    if ($liveCharacter -eq "BACK") {
        while ($true) {
            $liveRealm = Select-Folder -Path $currentAccountPath -Prompt "Select your LIVE Realm folder:" -ReturnNameOnly
            if ($liveRealm -ne "BACK") { break }
        }
        continue
    } else {
        break
    }
}

# ============================================================
# Interactive Selection of PTR Folders (Account, Realm, Character)
# ============================================================
Clear-Host
Write-Host "==== PTR Account Information ===="
$ptrAccountPath = Join-Path $ptrDir "WTF\Account"

do {
    $ptrAccount = Select-Folder -Path $ptrAccountPath -Prompt "Select your PTR Account folder:" -ReturnNameOnly
    if ($ptrAccount -eq "BACK") {
        Write-Host "Cannot go back from the first selection. Please select an account folder."
    }
} until ($ptrAccount -ne "BACK")

while ($true) {
    $currentPTRAccountPath = Join-Path $ptrAccountPath $ptrAccount
    $ptrRealm = Select-Folder -Path $currentPTRAccountPath -Prompt "Select your PTR Realm folder:" -ReturnNameOnly
    if ($ptrRealm -eq "BACK") {
        do {
            $ptrAccount = Select-Folder -Path $ptrAccountPath -Prompt "Select your PTR Account folder:" -ReturnNameOnly
            if ($ptrAccount -eq "BACK") {
                Write-Host "Cannot go back from the first selection. Please select an account folder."
            }
        } until ($ptrAccount -ne "BACK")
        continue
    } else {
        break
    }
}

while ($true) {
    $currentPTRRealmPath = Join-Path $currentPTRAccountPath $ptrRealm
    $ptrCharacter = Select-Folder -Path $currentPTRRealmPath -Prompt "Select your PTR Character folder:" -ReturnNameOnly
    if ($ptrCharacter -eq "BACK") {
        while ($true) {
            $ptrRealm = Select-Folder -Path $currentPTRAccountPath -Prompt "Select your PTR Realm folder:" -ReturnNameOnly
            if ($ptrRealm -ne "BACK") { break }
        }
        continue
    } else {
        break
    }
}

# ============================================================
# Summary of Selections and Confirmation
# ============================================================
Clear-Host
Write-Host "================ Summary ================"
Write-Host "LIVE Installation: $liveDir"
Write-Host "   Account:    $liveAccount"
Write-Host "   Realm:      $liveRealm"
Write-Host "   Character:  $liveCharacter"
Write-Host ""
Write-Host "PTR Installation:  $ptrDir"
Write-Host "   Account:    $ptrAccount"
Write-Host "   Realm:      $ptrRealm"
Write-Host "   Character:  $ptrCharacter"
Write-Host "==========================================="
Write-Host ""
$confirm = Read-Host "`nProceed with copying configuration files? (Y/N)"
if ($confirm -notmatch '^(Y|y)$') {
    Write-Host "Operation cancelled. Exiting..."
    Exit
}

# ============================================================
# Prompt for Overwrite Option
# ============================================================
Clear-Host
Write-Host "Choose overwrite option for existing files in the PTR folder:"
Write-Host ""
Write-Host ""
Write-Host "[1] Yes, always mirror existing files (make PTR identical to LIVE, all live files copied, ptr files either overwritten or, if not present in live, deleted)"
Write-Host ""
Write-Host "[2] No, never overwrite existing files (only copy new files, leave existing PTR ones alone. Useful for testing new addons but already have settings you don't want to lose on PTR)"
Write-Host ""
Write-Host "[3] Ask individually for each config step (when you have specific needs for each folder/config)"
Write-Host ""
Write-Host ""
$overwriteInput = Read-Host "Enter your selection (1, 2, or 3)"
switch ($overwriteInput) {
    "1" { $globalOverwriteOption = "Yes" }
    "2" { $globalOverwriteOption = "No" }
    "3" { $globalOverwriteOption = "Ask" }
    default { $globalOverwriteOption = "Yes" }
}
Write-Host ""
Write-Host "Global overwrite option set to: $globalOverwriteOption"
Pause

# ============================================================
# Function: Get-RobocopySwitches
# ============================================================
function Get-RobocopySwitches {
    param (
         [string]$OperationName
    )
    if ($globalOverwriteOption -eq "Yes") {
         return @("/MIR", "/NDL", "/NFL", "/NP", "/IS")
    } elseif ($globalOverwriteOption -eq "No") {
         return @("/S", "/NDL", "/NFL", "/NP", "/XO", "/XN", "/XC")
    } elseif ($globalOverwriteOption -eq "Ask") {
         $ans = Read-Host "For operation '$OperationName', do you want to overwrite existing files? (Y/N)"
         if ($ans -match '^(Y|y)$') {
             return @("/MIR", "/NDL", "/NFL", "/NP", "/IS")
         } else {
             return @("/S", "/NDL", "/NFL", "/NP", "/XO", "/XN", "/XC")
         }
    }
}

# ============================================================
# Function: Copy-FileWithOption
# ============================================================
function Copy-FileWithOption {
    param(
        [Parameter(Mandatory=$true)] [string]$Source,
        [Parameter(Mandatory=$true)] [string]$Destination
    )
    if ($globalOverwriteOption -eq "Yes") {
        Copy-Item -Path $Source -Destination $Destination -Force
    }
    elseif ($globalOverwriteOption -eq "No") {
        if (-not (Test-Path $Destination)) {
            Copy-Item -Path $Source -Destination $Destination
        } else {
            Write-Host "Skipping $Source because destination already exists."
        }
    }
    elseif ($globalOverwriteOption -eq "Ask") {
        if (Test-Path $Destination) {
            $ans = Read-Host "File $Destination exists. Overwrite? (Y/N)"
            if ($ans -match '^(Y|y)$') {
                Copy-Item -Path $Source -Destination $Destination -Force
            } else {
                Write-Host "Skipping $Source."
            }
        } else {
            Copy-Item -Path $Source -Destination $Destination
        }
    }
}

Clear-Host
Write-Host "Copying World of Warcraft settings from LIVE to PTR..."
Write-Host "---------------------------------------------`n"

# ============================================================
# Copy Operations (Directories and Files)
# ============================================================
# For directories, we use robocopy with switches from Get-RobocopySwitches.
# For individual files, we use Copy-FileWithOption.

# -- Copy AddOns --
Write-Host "Copying AddOns..."
$sourceAddOns = Join-Path $liveDir "Interface\AddOns"
$destAddOns   = Join-Path $ptrDir "Interface\AddOns"
$rcSwitches = Get-RobocopySwitches "AddOns"
& robocopy $sourceAddOns $destAddOns @rcSwitches
Write-Host "Note: 'Skipped' indicates folders/files were already present in some form in PTR.`n"
Write-Host ""
Write-Host "Addons copied successfully."
Write-Host "============================================"
Write-Host ""

# -- Copy Addon Settings (SavedVariables) --
Write-Host "Copying Account-wide Addon Settings (SavedVariables)..."
$sourceSavedVarsAcc = Join-Path $liveAccountPath "$liveAccount\SavedVariables"
$destSavedVarsAcc   = Join-Path $ptrAccountPath "$ptrAccount\SavedVariables"
$rcSwitches = Get-RobocopySwitches "Account-wide Addon Settings (SavedVariables)"
& robocopy $sourceSavedVarsAcc $destSavedVarsAcc @rcSwitches
Write-Host "Note: 'Skipped' indicates folders/files were already present in some form in PTR.`n"
Write-Host ""
Write-Host "Account-wide Addon Settings copied successfully."
Write-Host "============================================"
Write-Host ""

Write-Host "Copying Character-specific Addon Settings (SavedVariables)..."
$sourceSavedVarsChar = Join-Path (Join-Path $liveAccountPath $liveAccount) "$liveRealm\$liveCharacter\SavedVariables"
$destSavedVarsChar   = Join-Path (Join-Path $ptrAccountPath $ptrAccount) "$ptrRealm\$ptrCharacter\SavedVariables"
$rcSwitches = Get-RobocopySwitches "Character-specific Addon Settings (SavedVariables)"
& robocopy $sourceSavedVarsChar $destSavedVarsChar @rcSwitches
Write-Host "Note: 'Skipped' indicates folders/files were already present in some form in PTR.`n"
Write-Host ""
Write-Host "Character-specific Addon Settings copied successfully."
Write-Host "============================================"
Write-Host ""

# -- Copy Game Settings --
Write-Host "Copying Client-based Game Settings (Config.wtf)..."
$sourceConfig = Join-Path $liveDir "WTF\Config.wtf"
$destConfig   = Join-Path $ptrDir "WTF\Config.wtf"
if (Test-Path $sourceConfig) {
    Copy-FileWithOption -Source $sourceConfig -Destination $destConfig
} else {
    Write-Host "[Warning] Live Config.wtf not found."
}
Write-Host ""
Write-Host "Client-based Game Settings copied successfully."
Write-Host "============================================"
Write-Host ""

Write-Host "Copying Character-based Game Settings (config-cache.wtf)..."
$sourceCache = Join-Path (Join-Path $liveAccountPath $liveAccount) "$liveRealm\$liveCharacter\config-cache.wtf"
$destCache   = Join-Path (Join-Path $ptrAccountPath $ptrAccount) "$ptrRealm\$ptrCharacter\config-cache.wtf"
if (Test-Path $sourceCache) {
    Copy-FileWithOption -Source $sourceCache -Destination $destCache
} else {
    Write-Host "[Warning] Live config-cache.wtf not found."
}
Write-Host ""
Write-Host "Character-based Game Settings copied successfully."
Write-Host "============================================"
Write-Host ""

# -- Copy Keybindings --
Write-Host "Copying Account-wide Keybindings (bindings-cache.wtf)..."
$sourceBindingsAcc = Join-Path (Join-Path $liveAccountPath $liveAccount) "bindings-cache.wtf"
$destBindingsAcc   = Join-Path (Join-Path $ptrAccountPath $ptrAccount) "bindings-cache.wtf"
if (Test-Path $sourceBindingsAcc) {
    Copy-FileWithOption -Source $sourceBindingsAcc -Destination $destBindingsAcc
} else {
    Write-Host "[Warning] Live account bindings-cache.wtf not found."
    Write-Host "[Warning] Likely due to no account-wide keybindings set (? - honestly double check your folder) and the character using the Character-specific keybindings."
}
Write-Host ""
Write-Host "Account-wide Keybindings copied successfully."
Write-Host "============================================"
Write-Host ""

Write-Host "Copying Character-specific Keybindings (bindings-cache.wtf)..."
$sourceBindingsChar = Join-Path (Join-Path $liveAccountPath $liveAccount) "$liveRealm\$liveCharacter\bindings-cache.wtf"
$destBindingsChar   = Join-Path (Join-Path $ptrAccountPath $ptrAccount) "$ptrRealm\$ptrCharacter\bindings-cache.wtf"
if (Test-Path $sourceBindingsChar) {
    Copy-FileWithOption -Source $sourceBindingsChar -Destination $destBindingsChar
} else {
    Write-Host "[Warning] Live character bindings-cache.wtf not found."
    Write-Host "[Warning] Likely due to no character-specific keybindings set and the character using the account-wide keybindings."
}
Write-Host ""
Write-Host "Character-specific Keybindings copied successfully."
Write-Host "============================================"
Write-Host ""

# -- Copy Macros --
Write-Host "Copying Account-wide Macros..."
$sourceMacrosAccWTF = Join-Path (Join-Path $liveAccountPath $liveAccount) "macros-cache.wtf"
$sourceMacrosAccTXT = Join-Path (Join-Path $liveAccountPath $liveAccount) "macros-cache.txt"
if (Test-Path $sourceMacrosAccWTF) {
    Copy-FileWithOption -Source $sourceMacrosAccWTF -Destination (Join-Path (Join-Path $ptrAccountPath $ptrAccount) "macros-cache.wtf")
} elseif (Test-Path $sourceMacrosAccTXT) {
    Copy-FileWithOption -Source $sourceMacrosAccTXT -Destination (Join-Path (Join-Path $ptrAccountPath $ptrAccount) "macros-cache.txt")
} else {
    Write-Host "[Warning] Live account macros-cache file not found."
    Write-Host "[Warning] Likely due to no Account-wide macros set and the character using the character-specific macros."
}
Write-Host ""
Write-Host "Account-wide Macros copied successfully."
Write-Host "============================================"
Write-Host ""

Write-Host "Copying Character-specific Macros..."
$sourceMacrosCharWTF = Join-Path (Join-Path $liveAccountPath $liveAccount) "$liveRealm\$liveCharacter\macros-cache.wtf"
$sourceMacrosCharTXT = Join-Path (Join-Path $liveAccountPath $liveAccount) "$liveRealm\$liveCharacter\macros-cache.txt"
if (Test-Path $sourceMacrosCharWTF) {
    Copy-FileWithOption -Source $sourceMacrosCharWTF -Destination (Join-Path (Join-Path $ptrAccountPath $ptrAccount) "$ptrRealm\$ptrCharacter\macros-cache.wtf")
} elseif (Test-Path $sourceMacrosCharTXT) {
    Copy-FileWithOption -Source $sourceMacrosCharTXT -Destination (Join-Path (Join-Path $ptrAccountPath $ptrAccount) "$ptrRealm\$ptrCharacter\macros-cache.txt")
} else {
    Write-Host "[Warning] Live character macros-cache file not found."
    Write-Host "[Warning] Likely due to no character-specific macros set and the character using the account-wide macros."
}
Write-Host ""
Write-Host "Character-specific Macros copied successfully."
Write-Host "============================================"
Write-Host ""

# ============================================================
# Final Message and Exit
# ============================================================
Write-Host ""
Write-Host "All files have been processed."
Write-Host "Please verify that your PTR installation now contains the updated configurations."
Pause
