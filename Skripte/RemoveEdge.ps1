<#
.SYNOPSIS
    Debloat Control Panel - Windows Optimization Tool
.DESCRIPTION
    Full system cleanup, telemetry blocking, and service optimization.
.NOTES
    Author: Seven777-a57
    License: MIT
    GitHub: https://github.com
#>


#Requires -RunAsAdministrator

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ---------------------------------------------------------
# Admin Check
# ---------------------------------------------------------
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    [System.Windows.Forms.MessageBox]::Show(
        "This tool must be run as an Administrator.",
        "Administrator Required",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    ) | Out-Null
    exit 1
}

# ---------------------------------------------------------
# Logging
# ---------------------------------------------------------
$Global:RemoveEdgeLog = "C:\Windows\Temp\RemoveEdge.log"
if (-not (Test-Path (Split-Path $Global:RemoveEdgeLog))) {
    New-Item -Path (Split-Path $Global:RemoveEdgeLog) -ItemType Directory -Force | Out-Null
}
function Write-Log {
    param([string]$Message)
    $ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $line = "$ts  $Message"

    # File Log
    Add-Content -Path $Global:RemoveEdgeLog -Value $line

    # Live Log in GUI
    if ($Global:txtStatus -ne $null) {
        $Global:txtStatus.AppendText($line + "`r`n")
        $Global:txtStatus.SelectionStart = $Global:txtStatus.Text.Length
        $Global:txtStatus.ScrollToCaret()
        [System.Windows.Forms.Application]::DoEvents()
    }
}

"$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  === TOOL START ===" | Out-File $Global:RemoveEdgeLog -Encoding UTF8

# ---------------------------------------------------------
# Dialog Helpers
# ---------------------------------------------------------
function Show-MessageDialog {
    param(
        [string]$Title,
        [string]$Message,
        [ValidateSet("Information","Warning","Error")]$BoxIcon = "Information"
    )
    $icon = [System.Windows.Forms.MessageBoxIcon]::$BoxIcon
    [System.Windows.Forms.MessageBox]::Show($Message,$Title,[System.Windows.Forms.MessageBoxButtons]::OK,$icon) | Out-Null
}

function Show-Question {
    param(
        [string]$Title,
        [string]$Message,
        [ValidateSet("Information","Warning","Question")]$BoxIcon = "Question"
    )
    $icon = [System.Windows.Forms.MessageBoxIcon]::$BoxIcon
    $res = [System.Windows.Forms.MessageBox]::Show($Message,$Title,[System.Windows.Forms.MessageBoxButtons]::YesNo,$icon)
    return $res
}

# ---------------------------------------------------------
# Status Function
# ---------------------------------------------------------
function Get-EdgeStatusText {
    $sb = New-Object System.Text.StringBuilder

    [void]$sb.AppendLine("Edge / WebView2 Status")
    [void]$sb.AppendLine("──────────────────────────────")
    [void]$sb.AppendLine("")

    [void]$sb.AppendLine("Legacy Edge Versions")
    $classic = @{
        "Edge"       = "$env:ProgramFiles(x86)\Microsoft\Edge"
        "EdgeCore"   = "$env:ProgramFiles(x86)\Microsoft\EdgeCore"
        "EdgeUpdate" = "$env:ProgramFiles(x86)\Microsoft\EdgeUpdate"
        "WebView2"   = "$env:ProgramFiles(x86)\Microsoft\EdgeWebView"
    }

    foreach ($item in $classic.GetEnumerator()) {
        $exists = Test-Path $item.Value
        $statusText = if ($exists) { "Present" } else { "Not Found" }
        [void]$sb.AppendLine("$($item.Key) → $statusText")
    }

    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("New Edge Version")
    $systemWV2 = "C:\Windows\SystemApps\Microsoft.MicrosoftEdgeDevToolsClient_8wekyb3d8bbwe"
    if (Test-Path $systemWV2) {
        [void]$sb.AppendLine("System WebView2 → Active (Windows Component - Non-removable)")
    } else {
        [void]$sb.AppendLine("System WebView2 → Not Found")
    }
  
    $wa = Get-ChildItem "C:\Program Files\WindowsApps" -ErrorAction SilentlyContinue |
          Where-Object { $_.Name -like "Microsoft.MicrosoftEdge.Stable*" }

    if ($wa) {
        [void]$sb.AppendLine("WindowsApps Edge → Present")
        foreach ($entry in $wa) {
            [void]$sb.AppendLine("  $($entry.Name)")
        }
    } else {
        [void]$sb.AppendLine("WindowsApps Edge → Not Found")
    }

    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("Running Processes:")

    $procs = Get-Process -Name msedge,msedgewebview2 -ErrorAction SilentlyContinue

    if (-not $procs) {
        [void]$sb.AppendLine("  None")
    } else {
        foreach ($p in $procs) {
            if ($p.ProcessName -eq "msedge") {
                [void]$sb.AppendLine("  Edge Browser → PID $($p.Id)")
            }
            elseif ($p.ProcessName -eq "msedgewebview2") {
                if (Test-Path $systemWV2) {
                    [void]$sb.AppendLine("  System WebView2 → PID $($p.Id)")
                } else {
                    [void]$sb.AppendLine("  WebView2 Runtime → PID $($p.Id)")
                }
            }
        }
    }

    return $sb.ToString()
}

# ---------------------------------------------------------
# Core Logic: Combined Edge Removal + Registry Cleanup
# ---------------------------------------------------------
function Invoke-EdgeFullRemoval {

    Write-Log "=== Edge Full Removal START ==="

    # -----------------------------------------
    # Phase 1 – Kill Processes
    # -----------------------------------------
    Write-Log "Phase 1: Terminating Edge processes..."
    Update-Status "Terminating processes..." $true

    $edgeProcesses = @("msedge", "MicrosoftEdgeUpdate", "msedgewebview2", "msedgeview2")
    foreach ($proc in $edgeProcesses) {
        try {
            Stop-Process -Name $proc -Force -ErrorAction SilentlyContinue
            Write-Log "Process terminated (if present): $proc"
        } catch {
            Write-Log "Error terminating process $proc – $($_.Exception.Message)"
        }
    }

    # -----------------------------------------
    # Phase 2 – Search for Version
    # -----------------------------------------
    Write-Log "Phase 2: Searching for installed Edge version..."
    Update-Status "Searching for Edge version..." $true

    $edgeKeyPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge"
    )

    $edgeKey = $null
    foreach ($key in $edgeKeyPaths) {
        $edgeKey = Get-ItemProperty $key -ErrorAction SilentlyContinue
        if ($edgeKey) {
            Write-Log "Edge uninstall key found: $key"
            break
        }
    }

    # -----------------------------------------
    # Phase 3 – Setup Uninstall
    # -----------------------------------------
    Write-Log "Phase 3: Starting Edge uninstallation..."
    Update-Status "Starting uninstallation..." $true

    if ($edgeKey) {
        $version = $edgeKey.DisplayVersion
        $setupBase = "C:\Program Files (x86)\Microsoft\Edge\Application"
        $setupPath = Join-Path $setupBase "$version\Installer\setup.exe"

        if (Test-Path $setupPath) {
            Write-Log "Starting uninstallation via: $setupPath"
            Start-Process $setupPath -ArgumentList "--uninstall", "--system-level", "--force-uninstall" -Wait
            Write-Log "Edge setup uninstallation completed."
        }
        else {
            Write-Log "Setup.exe not found at: $setupPath"
        }
    }
    else {
        Write-Log "No Edge uninstall key found."
    }

    # -----------------------------------------
    # Phase 4 – Remove Services
    # -----------------------------------------
    Write-Log "Phase 4: Removing services..."
    Update-Status "Removing services..." $true

    $services = @("edgeupdate", "edgeupdatem", "MicrosoftEdgeElevationService")
    foreach ($service in $services) {
        $svc = Get-Service $service -ErrorAction SilentlyContinue
        if ($svc) {
            try {
                Stop-Service $service -Force -ErrorAction SilentlyContinue
                sc.exe delete $service | Out-Null
                Write-Log "Service removed: $service"
            }
            catch {
                Write-Log "Error removing service $service – $($_.Exception.Message)"
            }
        }
        else {
            Write-Log "Service not found: $service"
        }
    }

    # -----------------------------------------
    # Phase 5 – Remove Tasks
    # -----------------------------------------
    Write-Log "Phase 5: Removing scheduled tasks..."
    Update-Status "Removing scheduled tasks..." $true

    try {
        $tasks = Get-ScheduledTask | Where-Object { $_.TaskName -like "*MicrosoftEdge*" }
        foreach ($task in $tasks) {
            Unregister-ScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath -Confirm:$false -ErrorAction SilentlyContinue
            Write-Log "Scheduled task removed: $($task.TaskName)"
        }
        if (-not $tasks) {
            Write-Log "No Microsoft Edge related scheduled tasks found."
        }
    }
    catch {
        Write-Log "Error removing scheduled tasks – $($_.Exception.Message)"
    }

    # -----------------------------------------
    # Phase 6 – Set Registry Block
    # -----------------------------------------
    Write-Log "Phase 6: Setting Registry blocks..."
    Update-Status "Setting Registry blocks..." $true

    $regPath = "HKLM:\SOFTWARE\Microsoft\EdgeUpdate"
    if (!(Test-Path $regPath)) {
        try {
            New-Item -Path $regPath -Force | Out-Null
            Write-Log "Registry path created: $regPath"
        }
        catch {
            Write-Log "Error creating $regPath – $($_.Exception.Message)"
        }
    }
    try {
        Set-ItemProperty -Path $regPath -Name "DoNotUpdateToEdgeWithChromium" -Value 1 -Force
        Write-Log "Registry blockade set."
    }
    catch {
        Write-Log "Error setting Registry blockade – $($_.Exception.Message)"
    }

     # -----------------------------------------
    # Phase 7 – Registry Cleanup (Wildcard)
    # -----------------------------------------
    Write-Log "Phase 7: Registry cleanup (Wildcard)..."
    Update-Status "Cleaning Registry (Wildcard)..." $true

    function Remove-RegistryKeyRecursive {
        param([string]$Path)

        if ([string]::IsNullOrWhiteSpace($Path)) {
            Write-Log "Skipped: Empty path"
            return
        }

        if (Test-Path $Path) {
            try {
                Remove-Item -Path $Path -Recurse -Force -ErrorAction Stop
                Write-Log "Registry deleted: $Path"
            }
            catch {
                Write-Log "Error deleting $Path – $($_.Exception.Message)"
            }
        }
        else {
            Write-Log "Registry path not found: $Path"
        }
    }

    function Remove-SubkeysWithPrefix {
        param(
            [string]$Path,
            [string]$Pattern
        )

        if ([string]::IsNullOrWhiteSpace($Path)) {
            Write-Log "Skipped (empty): $Path"
            return
        }

        if (Test-Path $Path) {
            try {
                $items = Get-ChildItem -Path $Path -ErrorAction SilentlyContinue | Where-Object {
                    $_.PSChildName -match $Pattern
                }

                foreach ($item in $items) {
                    Remove-RegistryKeyRecursive -Path $item.PSPath
                }

                if ($items.Count -eq 0) {
                    Write-Log "No matching subkeys under: $Path"
                }
            }
            catch {
                Write-Log "Error searching $Path – $($_.Exception.Message)"
            }
        }
        else {
            Write-Log "Path does not exist: $Path"
        }
    }

    $hives = @(
        "HKCU:",
        "HKLM:",
        "HKLM:\Software\Classes",
        "HKCU:\Software\Classes"
    )

    $wildcardPaths = @(
        "ActivatableClasses\Package",
        "Extensions\ContractId\windows.appExecutionAlias\PackageId",
        "Local Settings\Software\Microsoft\Windows\CurrentVersion\AppContainer\Storage",
        "Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\PackageRepository\Packages",
        "Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\PolicyCache",
        "Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\SystemAppData",
        "SOFTWARE\Classes\Extensions\ContractId\Windows.AppService\PackageId",
        "SOFTWARE\Classes\Extensions\ContractId\Windows.BackgroundTasks\PackageId",
        "SOFTWARE\Classes\Extensions\ContractId\Windows.CommandLineLaunch\PackageId",
        "SOFTWARE\Classes\Extensions\ContractId\Windows.ComponentUI\PackageId",
        "SOFTWARE\Classes\Extensions\ContractId\Windows.File\PackageId",
        "SOFTWARE\Classes\Extensions\ContractId\Windows.Launch\PackageId",
        "SOFTWARE\Classes\Extensions\ContractId\Windows.PreInstalledConfigTask\PackageId",
        "SOFTWARE\Classes\Extensions\ContractId\Windows.Protocol\PackageId",
        "SOFTWARE\Microsoft\SecurityManager\CapAuthz\ApplicationsEx",
        "SOFTWARE\Microsoft\Windows\CurrentVersion\AppHost\IndexedDB",
        "SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\Applications",
        "SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\Config",
        "SOFTWARE\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications",
        "SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\Capabilities\microphone\Apps",
        "SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\Capabilities\userAccountInformation\Apps",
        "SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\Capabilities\webcam\Apps",
        "SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\cellularData",
        "SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location",
        "SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone",
        "SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\picturesLibrary",
        "SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\userAccountInformation",
        "SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\webcam",
        "SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\wifiData",
        "SOFTWARE\Microsoft\Windows\CurrentVersion\PushNotifications\Backup",
        "SOFTWARE\Microsoft\Windows NT\CurrentVersion\BackgroundModel\PreInstallTasks\RequireReschedule",
        "SYSTEM\Setup\Upgrade\Appx\DownlevelGather\AppxAllUserStore\Config",
        "SYSTEM\Setup\Upgrade\Appx\DownlevelGather\AppxAllUserStore\InboxApplications",
        "SYSTEM\Setup\Upgrade\Appx\DownlevelGather\PackageInstallState"
    )

    foreach ($path in $wildcardPaths) {
        foreach ($hive in $hives) {
            $fullPath = Join-Path $hive $path
            Remove-SubkeysWithPrefix -Path $fullPath -Pattern "^(?i)microsoft\.microsoftedge.*"
        }
    }

    # -----------------------------------------
    # Phase 8 – Registry Cleanup (Full Paths)
    # -----------------------------------------
    Write-Log "Phase 8: Registry cleanup (Full Paths)..."
    Update-Status "Cleaning Registry (Full Paths)..." $true

    $fullDeletePaths = @(
        "AppID\MicrosoftEdgeUpdate.exe",
        "SOFTWARE\Classes\microsoft-edge",
        "SOFTWARE\Classes\microsoft-edge-holographic",
        "SOFTWARE\Microsoft\Active Setup\Installed Components\{9459C573-B17A-45AE-9F64-1857B5D58CEE}",
        "SOFTWARE\Microsoft\Edge",
        "SOFTWARE\Microsoft\EdgeUpdate",
        "SOFTWARE\Microsoft\Internet Explorer\EdgeDebugActivation",
        "SOFTWARE\Microsoft\Internet Explorer\EdgeIntegration",
        "SOFTWARE\Microsoft\MicrosoftEdge",
        "SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\MicrosoftEdgeUpdate.exe",
        "SOFTWARE\Microsoft\Windows\Shell\Associations\UrlAssociations\microsoft-edge",
        "SOFTWARE\Microsoft\Windows\Shell\Associations\UrlAssociations\microsoft-edge-holographic",
        "SOFTWARE\WOW6432Node\Microsoft\Edge",
        "SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate",
        "SYSTEM\CurrentControlSet\Services\edgeupdate",
        "SYSTEM\CurrentControlSet\Services\edgeupdatem",
        "SYSTEM\CurrentControlSet\Services\MicrosoftEdgeElevationService"
    )

    foreach ($path in $fullDeletePaths) {
        foreach ($hive in $hives) {
            $fullPath = Join-Path $hive $path
            Remove-RegistryKeyRecursive -Path $fullPath
        }
    }

    # -----------------------------------------
    # Phase 9 – Registry Cleanup (Extra Keys)
    # -----------------------------------------
    Write-Log "Phase 9: Registry cleanup (Extra Keys)..."
    Update-Status "Cleaning Registry (Extra Keys)..." $true

    $extraEntries = @(
        "http\shell\open",
        "https\shell\open",
        "MSEdgeHTM",
        "MSEdgeMHT",
        "MSEdgePDF",
        "CLSID\{08D832B9-D2FD-481F-98CF-904D00DF63CC}",
        "CLSID\{1FD49718-1D00-4B19-AF5F-070AF6D5D54C}",
        "CLSID\{264380B6-FFBE-4EA7-8708-1C092B45EEC7}",
        "CLSID\{2E1DD7EF-C12D-4F8E-8AD8-CF8CC265BAD0}",
        "CLSID\{3A84F9C2-6164-485C-A7D9-4B27F8AC009E}",
        "CLSID\{4655473C-FED3-438C-86A8-91255F7DDAB4}",
        "CLSID\{492E1C30-A1A2-4695-87C8-7A8CAD6F936F}",
        "CLSID\{5F6A18BB-6231-424B-8242-19E5BB94F8ED}",
        "CLSID\{77857D02-7A25-4B67-9266-3E122A8F39E4}",
        "CLSID\{9E8F1B36-249F-4FC3-9994-974AFAA07B26}",
        "CLSID\{A2F5CB38-265F-4A02-9D1E-F25B664968AB}",
        "CLSID\{B5977F34-9264-4AC3-9B31-1224827FF6E8}",
        "CLSID\{D1E8B1A6-32CE-443C-8E2E-EBA90C481353}",
        "CLSID\{E421557C-0628-43FB-BF2B-7C9F8A4D067C}",
        "CLSID\{FF419FF9-90BE-4D9F-B410-A789F90E5A7C}",
        "CLSID\{4A749F25-A9E2-4CBE-9859-CF7B15255E14}",
        "CLSID\{628ACE20-B77A-456F-A88D-547DB6CEEDD5}",
        "CLSID\{7D6FA3E8-2A3B-4C7D-9F4A-8B2E5C9A7F12}",
        "CLSID\{B54934CD-71A6-4698-BDC2-AFEA5B86504C}",
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\App Paths\msedge.exe",
        "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Compatibility Assistant\Store",
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge",
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft EdgeWebView",
        "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache"
    )

    foreach ($entry in $extraEntries) {
        if ($entry -like "HK*:\*") {
            Remove-RegistryKeyRecursive -Path $entry
        }
        else {
            foreach ($hive in $hives) {
                $fullPath = Join-Path $hive $entry
                Remove-RegistryKeyRecursive -Path $fullPath
            }
        }
    }

# Remove Autostart
Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "MicrosoftEdgeAutoLaunch_5EFC0ECB77A7585FE9DCDD0B2E946A2B" -ErrorAction SilentlyContinue
Write-Log "----------Autostart entry deleted----------."

   
    # -----------------------------------------
    # Phase 10 – Delete Folders
    # -----------------------------------------
    Write-Log "Phase 10: Deleting Edge folders..."
    Update-Status "Deleting Edge folders..." $true

    $localEdge = Join-Path $env:LOCALAPPDATA "Microsoft\Edge"

    $folders = @(
        "C:\Windows\System32\Microsoft-Edge-WebView",
        $localEdge,
        "C:\Program Files (x86)\Microsoft\Edge",
        "C:\Program Files (x86)\Microsoft\EdgeCore",
        "C:\Program Files (x86)\Microsoft\EdgeUpdate",
        "C:\Program Files (x86)\Microsoft\EdgeWebView"
    )

    foreach ($folder in $folders) {
        if (Test-Path -LiteralPath $folder) {
            Write-Log "Processing folder: $folder"

            try {
                # Take ownership and grant permissions
                takeown /F "$folder" /R /A /D Y | Out-Null
                icacls "$folder" /grant *S-1-5-32-544:F /T /C /Q | Out-Null
            }
            catch {
                Write-Log "Error taking ownership/permissions for $folder – $($_.Exception.Message)"
            }

            try {
                Remove-Item -LiteralPath $folder -Recurse -Force -ErrorAction SilentlyContinue
            }
            catch {
                Write-Log "Error deleting $folder – $($_.Exception.Message)"
            }

            if (!(Test-Path -LiteralPath $folder)) {
                Write-Log "Folder removed: $folder"
            }
            else {
                Write-Log "Folder could not be fully deleted: $folder"
            }
        }
        else {
            Write-Log "Folder not found: $folder"
        }
    }

    # -----------------------------------------
    # Remove Edge Icons
    # -----------------------------------------
    # 1. Registry Block (Prevents new icons after updates)
    $regPath = "HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate"
    try {
        if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }
        Set-ItemProperty -Path $regPath -Name "CreateDesktopShortcutDefault" -Value 0 -Type DWord -ErrorAction Stop
        Write-Log "REGISTRY: Desktop shortcut block set."
    } catch {
        Write-Log "REGISTRY ERROR: Could not set shortcut block: $($_.Exception.Message)"
    }

    # 2. Define Paths (Links & Taskbar folders)
    $lnkFiles = @(
        "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Microsoft Edge.lnk",
        "C:\Users\Public\Desktop\Microsoft Edge.lnk",
        "AppData\Roaming\Microsoft\Internet Explorer\Quick Launch\Microsoft Edge.lnk",
        "Desktop\Microsoft Edge.lnk",
        # Path for pinned taskbar items
        "AppData\Roaming\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\Microsoft Edge.lnk"
    )

    $userFolders = Get-ChildItem -Path "C:\Users" -Directory

    foreach ($userFolder in $userFolders) {
        $userName = $userFolder.Name
        
        # 3. Remove existing shortcuts (.lnk)
        foreach ($lnk in $lnkFiles) {
            $fullPath = if ($lnk -match "^[A-Z]:\\") { $lnk } else { Join-Path $userFolder.FullName $lnk }

            if (Test-Path -LiteralPath $fullPath) {
                try {
                    Remove-Item -LiteralPath $fullPath -Force -ErrorAction Stop
                    Write-Log "REMOVED ($userName): $fullPath"
                } catch {
                    Write-Log "ERROR ($userName): Could not delete $fullPath."
                }
            }
        }

        # 4. Cleanup Taskbar Registry entries (per user)
        # Note: Since Edge is uninstalled, these pins often become "dead" icons.
        # Note: In a live environment, NTUSER.DAT would need to be loaded if the user is not logged in.
        $taskbandRegistry = "Registry::HKEY_USERS\$userName\Software\Microsoft\Windows\CurrentVersion\Explorer\Taskband"
    }

    Write-Log "CLEANUP: All known Edge paths have been processed."

    #________________________________________________________________________________________

    Write-Log "=== Edge Full Removal END ==="
    Update-Status "Edge removal completed." $true

} # End of function


# ---------------------------------------------------------
# UI
# ---------------------------------------------------------
$form = New-Object System.Windows.Forms.Form
$form.Text = "Remove Edge (Extended)"
$form.Size = New-Object System.Drawing.Size(700, 450)
$form.StartPosition = "CenterScreen"
$form.BackColor = [System.Drawing.Color]::FromArgb(223,228,176)
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false

$labelStatus = New-Object System.Windows.Forms.Label
$labelStatus.Text = "Ready"
$labelStatus.Location = New-Object System.Drawing.Point(20, 380)
$labelStatus.Size = New-Object System.Drawing.Size(650, 30)
$labelStatus.Font = New-Object System.Drawing.Font("Segoe UI",10,[System.Drawing.FontStyle]::Bold)
$labelStatus.TextAlign = "MiddleCenter"
$form.Controls.Add($labelStatus)

function Update-Status {
    param(
        [string]$text,
        [bool]$ok = $true
    )
    $labelStatus.Text = $text
    $labelStatus.ForeColor = if($ok){[System.Drawing.Color]::Green}else{[System.Drawing.Color]::Red}
}

function New-ActionButton {
    param(
        [string]$Text,
        [int]$X,
        [int]$Y,
        [int]$Width,
        [int]$Height,
        [System.Drawing.Color]$Color
    )

    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = $Text
    $btn.Location = New-Object System.Drawing.Point($X,$Y)
    $btn.Size = New-Object System.Drawing.Size($Width,$Height)
    $btn.BackColor = $Color
    $btn.Font = New-Object System.Drawing.Font("Segoe UI",9,[System.Drawing.FontStyle]::Regular)
    return $btn
}

$txtStatus = New-Object System.Windows.Forms.TextBox
$txtStatus.Location = New-Object System.Drawing.Point(20, 20)
$txtStatus.Size = New-Object System.Drawing.Size(650, 200)
$txtStatus.Multiline = $true
$txtStatus.ScrollBars = "Vertical"
$txtStatus.ReadOnly = $true
$txtStatus.Font = New-Object System.Drawing.Font("Consolas",9)
$form.Controls.Add($txtStatus)
$Global:txtStatus = $txtStatus


$btnStatus = New-ActionButton -Text "Check Status" -X 20 -Y 270 -Width 200 -Height 35 -Color ([System.Drawing.Color]::Aquamarine)
$form.Controls.Add($btnStatus)

$btnRemove = New-ActionButton -Text "Remove Edge (Full)" -X 240 -Y 270 -Width 200 -Height 35 -Color ([System.Drawing.Color]::LightCoral)
$form.Controls.Add($btnRemove)

$btnLog = New-ActionButton -Text "Show Log" -X 460 -Y 270 -Width 210 -Height 35 -Color ([System.Drawing.Color]::Plum)
$form.Controls.Add($btnLog)

$btnClose = New-ActionButton -Text "Close" -X 240 -Y 320 -Width 200 -Height 35 -Color ([System.Drawing.Color]::MintCream)
$form.Controls.Add($btnClose)

# Events
$btnStatus.Add_Click({
    try {
        $txtStatus.Text = Get-EdgeStatusText
        Update-Status "Status updated.", $true
    } catch {
        Update-Status "Error retrieving status.", $false
        Write-Log "Error in Get-EdgeStatusText: $_"
    }
})

$btnRemove.Add_Click({
    $Ask = "Are you sure you want to completely remove Edge?" + [Environment]::NewLine +
           "WebView2, Registry entries, and installation directories will also be cleaned." + [Environment]::NewLine +
           "You can reinstall Edge at any time."
    $answer = Show-Question -Title "Warning" -Message $Ask -BoxIcon "Warning"
    if ($answer -ne 'Yes') { return }


    Update-Status "Starting full removal..." $true
    [System.Windows.Forms.Application]::DoEvents()

    try {
        Invoke-EdgeFullRemoval

        Update-Status "Edge removal completed. Reboot recommended." $true
        Show-MessageDialog -Title "Done" -Message "Edge has been removed. A system restart is recommended." -BoxIcon "Information"
        $txtStatus.Text = Get-EdgeStatusText
    } catch {
        Update-Status "Error during removal. Check log for details." $false
        Show-MessageDialog -Title "Error" -Message "An error occurred during removal.`nSee the log file for details." -BoxIcon "Error"
    }
})

$btnLog.Add_Click({
    if (Test-Path $Global:RemoveEdgeLog) {
        try {
            Start-Process notepad.exe $Global:RemoveEdgeLog
            Update-Status "Log opened.", $true
        } catch {
            Update-Status "Error opening log.", $false
        }
    } else {
        Update-Status "Log file not found.", $false
    }
})

$btnClose.Add_Click({
    $form.Close()
})

$txtStatus.Text = Get-EdgeStatusText

# Remove focus from textbox to prevent auto-selection
$form.Add_Shown({
    $btnStatus.Focus()
})

[void]$form.ShowDialog()
