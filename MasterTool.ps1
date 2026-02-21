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

# ------------------------------------------------------------
# MasterTool.ps1 – Zentrales Windows Maintenance Tool
# Debloat Control Panel Look & Feel
# ------------------------------------------------------------

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Module laden
Import-Module ".\WMF\Gui.psm1"
Import-Module ".\WMF\Logging.psm1"
Import-Module ".\WMF\Registry.psm1"
Import-Module ".\WMF\Cleanup.psm1"
Import-Module ".\WMF\DiagTrack.psm1"

# ------------------------------------------------------------
# GLOBALER STYLE – Debloat Control Panel Look
# ------------------------------------------------------------

# Hintergrundfarbe wie Debloat Panel
$global:WmfBackColor = [System.Drawing.Color]::FromArgb(223, 228, 176)

# Standard-Font
$global:WmfFont = New-Object System.Drawing.Font("Segoe UI", 10)

# Button-Style Funktion (flach, farbig)
function Set-WmfFlatButton {
    param(
        [Parameter(Mandatory=$true)] [System.Windows.Forms.Button] $Button,
        [Parameter(Mandatory=$true)] [System.Drawing.Color] $BackColor
    )

    $Button.BackColor  = $BackColor
    $Button.ForeColor  = [System.Drawing.Color]::Black
    $Button.FlatStyle  = 'Flat'
    $Button.Font       = $global:WmfFont
}

# Status-Label Style
function Set-WmfStatusStyle {
    param(
        [Parameter(Mandatory=$true)] [System.Windows.Forms.Label] $Label
    )

    $Label.Font      = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $Label.TextAlign = "MiddleCenter"
    $Label.ForeColor = [System.Drawing.Color]::Black
    $Label.BackColor = $global:WmfBackColor
}

# ------------------------------------------------------------
# Hilfsfunktionen für Speicherermittlung
# ------------------------------------------------------------
function Get-WmfFreeSpace {
    param([string]$Drive = "C")
    return (Get-PSDrive $Drive).Free
}

function Format-WmfBytes {
    param([long]$Bytes)

    if ($Bytes -gt 1GB) { return "{0:N2} GB" -f ($Bytes / 1GB) }
    if ($Bytes -gt 1MB) { return "{0:N2} MB" -f ($Bytes / 1MB) }
    if ($Bytes -gt 1KB) { return "{0:N2} KB" -f ($Bytes / 1KB) }
    return "$Bytes Bytes"
 }
    $freeBefore = Get-WmfFreeSpace
	
# ------------------------------------------------------------
# PREMIUM-FUNKTIONEN (Status, Log, Boxen, DISM, Animation)
# ------------------------------------------------------------

# Premium-Status mit Farben
function Update-WmfStatusFlat {
    param(
        [System.Windows.Forms.Label]$StatusLabel,
        [string]$Text,
        [string]$State = "info"   # info, success, warning, error
    )

    switch ($State) {
        "success" { $StatusLabel.ForeColor = [System.Drawing.Color]::ForestGreen }
        "warning" { $StatusLabel.ForeColor = [System.Drawing.Color]::DarkOrange }
        "error"   { $StatusLabel.ForeColor = [System.Drawing.Color]::Firebrick }
        default   { $StatusLabel.ForeColor = [System.Drawing.Color]::DodgerBlue }
    }

    $StatusLabel.Text = $Text
    $StatusLabel.Refresh()
}

# ------------------------------------------------------------
# CompactOS – Activation with Progress + Log
# ------------------------------------------------------------
function Invoke-WmfCompactOS {
    param(
        [Parameter(Mandatory)]
        [object]$LogBox,

        [Parameter(Mandatory)]
        [System.Windows.Forms.ProgressBar]$ProgressBar
    )

    Write-WmfLogColor -Text "Checking CompactOS status..." -LogBox $LogBox -Color ([System.Drawing.Color]::DodgerBlue)

    # Check status
    $status = (compact.exe /CompactOS:query) 2>&1

    if ($status -match "in CompactOS mode") {
        Write-WmfLogColor -Text "CompactOS is already enabled. No action required." -LogBox $LogBox -Color ([System.Drawing.Color]::Blue)
        $ProgressBar.Value = 100
        return
    }

    Write-WmfLogColor -Text "Starting CompactOS..." -LogBox $LogBox -Color ([System.Drawing.Color]::DodgerBlue)
    $ProgressBar.Value = 0

    # Start CompactOS
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "compact.exe"
    $psi.Arguments = "/CompactOS:always"
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true

    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $psi
    $proc.Start() | Out-Null

    # Simulate progress if Windows provides no direct feedback
    $percent = 0

    while (-not $proc.HasExited) {
        [System.Windows.Forms.Application]::DoEvents()
        Start-Sleep -Milliseconds 1500
        # ProgressBar from 95 to 65 
        if ($percent -lt 65) {
            $percent += 1
            $ProgressBar.Value = $percent
        }
    }

    # Log remaining output
    while (-not $proc.StandardOutput.EndOfStream) {
        Write-WmfLog -Text ($proc.StandardOutput.ReadLine()) -LogBox $LogBox
    }

    $ProgressBar.Value = 100
    Write-WmfLogColor -Text "CompactOS completed." -LogBox $LogBox -Color ([System.Drawing.Color]::Green)
}


# Box with border in the log
function Write-WmfLogBox {
    param(
        [string[]]$Lines,
        [System.Windows.Forms.TextBox]$LogBox,
        [System.Drawing.Color]$Color = [System.Drawing.Color]::DodgerBlue
    )

    $max = ($Lines | Measure-Object -Property Length -Maximum).Maximum
    $borderTop =  "╔" + ("═" * ($max + 2)) + "╗"
    $borderBottom = "╚" + ("═" * ($max + 2)) + "╝"

    Write-WmfLogColor -Text $borderTop -LogBox $LogBox -Color $Color

    foreach ($line in $Lines) {
        $pad = $line.PadRight($max)
        Write-WmfLogColor -Text ("║ " + $pad + " ║") -LogBox $LogBox -Color $Color
    }

    Write-WmfLogColor -Text $borderBottom -LogBox $LogBox -Color $Color
}
# DISM Cleanup with ProgressBar + Log
function Start-WmfDismComponentCleanup {
    param(
        [System.Windows.Forms.TextBox]$LogBox,
        [System.Windows.Forms.ProgressBar]$ProgressBar,
        [System.Windows.Forms.Label]$StatusLabel
    )

    Write-WmfLogColor -Text "Starting DISM Component Cleanup..." -LogBox $LogBox -Color ([System.Drawing.Color]::DodgerBlue)
    Update-WmfStatusFlat -StatusLabel $StatusLabel -Text "DISM Component Cleanup started..." -State "error"

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "dism.exe"
    $psi.Arguments = "/Online /Cleanup-Image /StartComponentCleanup"
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $psi
    $process.Start() | Out-Null

    while (-not $process.HasExited) {
		[System.Windows.Forms.Application]::DoEvents()
	       $line = $process.StandardOutput.ReadLine()

        if ($line -match "(\d{1,3}\.\d)%") {
            $percent = [int][double]$matches[1]

            if ($percent -ge $ProgressBar.Minimum -and $percent -le $ProgressBar.Maximum) {
                $ProgressBar.Value = $percent
            }

            $StatusLabel.Text  = "DISM Component Cleanup – $percent%"

            $barLength = 40
            $filled = [int]($percent / 100 * $barLength)
            $bar = "[" + ("=" * $filled) + (" " * ($barLength - $filled)) + "]"

            Write-WmfLogColor -Text "$bar $percent%" -LogBox $LogBox -Color ([System.Drawing.Color]::MediumPurple)
			[System.Windows.Forms.Application]::DoEvents()
        }
    }

    while (-not $process.StandardOutput.EndOfStream) {
        Write-WmfLogColor -Text ($process.StandardOutput.ReadLine()) -LogBox $LogBox -Color ([System.Drawing.Color]::Gray)
    }

    $ProgressBar.Value = 100
    Update-WmfStatusFlat -StatusLabel $StatusLabel -Text "DISM Cleanup completed" -State "success"
    Write-WmfLogColor -Text "DISM Cleanup completed." -LogBox $LogBox -Color ([System.Drawing.Color]::Green)
}

# Hardlink Grouping (ResetBase)

function Invoke-WmfHardlinkCleanup {
    param(
        [System.Windows.Forms.TextBox]$LogBox,
        [System.Windows.Forms.ProgressBar]$ProgressBar,
        [System.Windows.Forms.Label]$StatusLabel
    )

    Write-WmfLogColor -Text "Starting WinSxS Hardlink Grouping (ResetBase)..." -LogBox $LogBox -Color ([System.Drawing.Color]::DodgerBlue)
    
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "dism.exe"
    $psi.Arguments = "/Online /Cleanup-Image /StartComponentCleanup /ResetBase"
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $psi
    $process.Start() | Out-Null

    while (-not $process.HasExited) {
        [System.Windows.Forms.Application]::DoEvents()
        $line = $process.StandardOutput.ReadLine()

        # Detects 5%, 5.0%, 65% etc.
        if ($line -match "(\d+(\.\d+)?)%") {
            $percent = [int][double]$matches[1]

            if ($ProgressBar -and $percent -ge 0 -and $percent -le 100) {
                # Animation trick
                if ($percent -lt 100) {
                    $ProgressBar.Value = $percent + 1
                    $ProgressBar.Value = $percent
                } else {
                    $ProgressBar.Value = 100
                }
                $ProgressBar.Refresh()
            }

            if ($StatusLabel) { 
                $StatusLabel.Text = "Hardlink Cleanup: $percent%" 
                $StatusLabel.Refresh()
            }

            $barLength = 40
            $filled = [int]($percent / 100 * $barLength)
            $bar = "[" + ("=" * $filled) + (" " * ($barLength - $filled)) + "]"
            Write-WmfLogColor -Text "$bar $percent%" -LogBox $LogBox -Color ([System.Drawing.Color]::MediumPurple)
        }
    }

    $ProgressBar.Value = 100
    Write-WmfLogColor -Text "✓ Hardlink Grouping (ResetBase) completed." -LogBox $LogBox -Color ([System.Drawing.Color]::Green)
}

# Live Animation Timer
$cleanupAnimTimer = New-Object System.Windows.Forms.Timer
$cleanupAnimTimer.Interval = 150

$global:cleanupAnimFrames = @("|","/","—","\")
$global:cleanupAnimIndex = 0

$cleanupAnimTimer.Add_Tick({
    $status.ForeColor = [System.Drawing.Color]::DarkOrange
    $status.Text = "Cleanup running… " + $global:cleanupAnimFrames[$global:cleanupAnimIndex]
    $global:cleanupAnimIndex = ($global:cleanupAnimIndex + 1) % $global:cleanupAnimFrames.Count
})

# ------------------------------------------------------------
# Main Window
# ------------------------------------------------------------
$form = New-WmfForm -Title "Windows Maintenance Center" -Width 650 -Height 900 -CenterScreen
$form.BackColor = $global:WmfBackColor

$logBox = New-WmfLogBox -Form $form -X 20 -Y 20 -Width 600 -Height 250
$status = New-WmfStatusLabel -Form $form -X 20 -Y 820 -Width 600

# Status Label in Debloat Style
Set-WmfStatusStyle -Label $status
$status.Text = "Ready"

# ------------------------------------------------------------
# TabControl
# ------------------------------------------------------------
$tabControl = New-Object System.Windows.Forms.TabControl
$tabControl.Location = New-Object System.Drawing.Point(20, 290)
$tabControl.Size     = New-Object System.Drawing.Size(600, 520)
$tabControl.Font     = $global:WmfFont
$form.Controls.Add($tabControl)

# Tabs

$tabPrivacy = New-Object System.Windows.Forms.TabPage
$tabPrivacy.Text      = "Privacy"
$tabPrivacy.BackColor = $global:WmfBackColor

$tabTools = New-Object System.Windows.Forms.TabPage
$tabTools.Text      = "Services"
$tabTools.BackColor = $global:WmfBackColor

$tabDiag = New-Object System.Windows.Forms.TabPage
$tabDiag.Text      = "System Control" 
$tabDiag.BackColor = $global:WmfBackColor

$tabCleanup = New-Object System.Windows.Forms.TabPage
$tabCleanup.Text      = "Cleanup"
$tabCleanup.BackColor = $global:WmfBackColor

$tabControl.TabPages.Add($tabPrivacy)
$tabControl.TabPages.Add($tabTools)
$tabControl.TabPages.Add($tabDiag)
$tabControl.TabPages.Add($tabCleanup)


#####################################################################################

# ------------------------------------------------------------
# TAB 1 – Tweaks
# ------------------------------------------------------------
$tabPrivacy.Text = "Tweaks"

$panelTweaks = New-WmfScrollPanel -Parent $tabPrivacy -X 10 -Y 10 -Width 560 -Height 300
$panelTweaks.BackColor = $global:WmfBackColor
Reset-WmfPanelCheckboxY

# ------------------------------------------------------------
# Checkboxes
# ------------------------------------------------------------
$cbNoAnimations = $null
Add-WmfPanelCheckbox -Panel $panelTweaks -Text "Disable Window Animations" -OutVariable ([ref]$cbNoAnimations)

$cbExplorerTweaks = $null
Add-WmfPanelCheckbox -Panel $panelTweaks -Text "Optimize Explorer & Taskbar" -OutVariable ([ref]$cbExplorerTweaks)

$cbStart_TrackDocs = $null
Add-WmfPanelCheckbox -Panel $panelTweaks -Text "Disable Recent Files in Start Menu" -OutVariable ([ref]$cbStart_TrackDocs)

$cbThisPCFolders = $null
Add-WmfPanelCheckbox -Panel $panelTweaks -Text "Show 'This PC' Folders" -OutVariable ([ref]$cbThisPCFolders)

$cbSpotlight = $null
Add-WmfPanelCheckbox -Panel $panelTweaks -Text "Disable Desktop Spotlight" -OutVariable ([ref]$cbSpotlight)

$cbClearLogin = $null
Add-WmfPanelCheckbox -Panel $panelTweaks -Text "Clear Login Screen (No Acrylic)" -OutVariable ([ref]$cbClearLogin)

$cbOldContext = $null
Add-WmfPanelCheckbox -Panel $panelTweaks -Text "Classic Context Menu + Shell Extensions" -OutVariable ([ref]$cbOldContext)

$cbSingleClick = $null
Add-WmfPanelCheckbox -Panel $panelTweaks -Text "Single-click to open" -OutVariable ([ref]$cbSingleClick)


# ------------------------------------------------------------
# Functions – APPLY
# ------------------------------------------------------------

function Set-WmfNoAnimations {
    param($LogBox)
    Write-WmfLog -Text "→ Executing Tweaks" -LogBox $LogBox
    Write-WmfLog -Text "→ Disabling Window and UI Animations" -LogBox $LogBox
    $DesktopPath = "HKCU:\Control Panel\Desktop"
    $MetricsPath = "HKCU:\Control Panel\Desktop\WindowMetrics"
    if (-not (Test-Path $MetricsPath)) { New-Item -Path $MetricsPath -Force }
    Set-ItemProperty -Path $DesktopPath -Name "MinAnimate" -Value "0"
    Set-ItemProperty -Path $MetricsPath -Name "MinAnimate" -Value "0"

    $MaskValue = ([byte[]](0x80,0x12,0x07,0x80,0x10,0x00,0x00,0x00))
    Set-ItemProperty -Path $DesktopPath -Name "UserPreferencesMask" -Value $MaskValue -Type Binary
}

function Set-WmfExplorerTweaks {
    param($LogBox)
    Write-WmfLog -Text "→ Optimizing Explorer & Taskbar" -LogBox $LogBox

    $adv = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    Set-ItemProperty $adv "Start_SearchFiles" 2
    Set-ItemProperty $adv "Hidden" 2
    Set-ItemProperty $adv "ShowCompColor" 1
    Set-ItemProperty $adv "HideFileExt" 1
    Set-ItemProperty $adv "ShowInfoTip" 0
    Set-ItemProperty $adv "ShowStatusBar" 1
    Set-ItemProperty $adv "ShowSyncProviderNotifications" 0
    Set-ItemProperty $adv "TaskbarAnimations" 0
    Set-ItemProperty $adv "ShowTaskViewButton" 0
    Set-ItemProperty $adv "DisablePreviewDesktop" 1
    Set-ItemProperty $adv "ShowSecondsInSystemClock" 1
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers" -Name "DisableAutoplay" -Value 1
}

function Set-WmfStart_TrackDocs {
    param($LogBox)
    Write-WmfLog -Text "→ Disabling Recent Files in Start Menu" -LogBox $LogBox
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Start_TrackDocs" -Value 0
}

function Set-WmfThisPCFolders {
    param($LogBox)
    Write-WmfLog -Text "→ Making 'This PC' folders visible" -LogBox $LogBox

    $ns = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace"
    foreach ($guid in @(
        "{d3162b92-9365-467a-956b-92703aca08af}",
        "{088e3905-0323-4b02-9826-5d99428e115f}",
        "{24ad3ad4-a569-4530-98e1-ab02f9417aa8}"
    )) {
        New-Item -Path "$ns\$guid" -Force | Out-Null
        Remove-ItemProperty -Path "$ns\$guid" -Name "HideIfEnabled" -ErrorAction SilentlyContinue
        Set-ItemProperty -Path "$ns\$guid" -Name "HiddenByDefault" -Value 0
    }
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "LaunchTo" -Value 1
}

function Set-WmfSpotlight {
    param($LogBox)
    Write-WmfLog -Text "→ Disabling Desktop Spotlight" -LogBox $LogBox
    New-Item -Path "HKCU:\Software\Policies\Microsoft\Windows\CloudContent" -Force | Out-Null
    Set-ItemProperty -Path "HKCU:\Software\Policies\Microsoft\Windows\CloudContent" -Name "DisableSpotlightCollectionOnDesktop" -Value 1
}

function Set-WmfClearLogin {
    param($LogBox)
    Write-WmfLog -Text "→ Setting Login Screen to Clear (No Blur)" -LogBox $LogBox
    New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Force | Out-Null
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "DisableAcrylicBackgroundOnLogon" -Value 1
}

function Set-WmfOldContextMenu {
    param($LogBox)
    Write-WmfLog -Text "→ Enabling Classic Context Menu + Shell Extensions" -LogBox $LogBox

    # --- Activate Classic Context Menu ---
    New-Item -Path "HKCU:\Software\Classes\CLSID\{031E4825-7B94-4dc3-B131-E946B44C8DD5}" -Force | Out-Null
    New-Item -Path "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" -Force | Out-Null
    Set-ItemProperty -Path "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" -Name "(default)" -Value ""

    # Paths
    $bg = "HKCU:\Software\Classes\Directory\Background\shell"
    $desk = "HKCU:\Software\Classes\DesktopBackground\Shell"

    # --- Computer Management ---
    New-Item "$bg\ComputerManagement" -Force | Out-Null
    Set-ItemProperty "$bg\ComputerManagement" -Name "MUIVerb" -Value "Computer Management"
    Set-ItemProperty "$bg\ComputerManagement" -Name "Icon" -Value "imageres.dll,-5374"
    New-Item "$bg\ComputerManagement\command" -Force | Out-Null
    Set-ItemProperty "$bg\ComputerManagement\command" -Name "(default)" -Value "CompMgmtLauncher.exe"

    # --- Disk Cleanup ---
    New-Item "$desk\DiskCleanup" -Force | Out-Null
    Set-ItemProperty "$desk\DiskCleanup" -Name "MUIVerb" -Value "Disk Cleanup"
    Set-ItemProperty "$desk\DiskCleanup" -Name "Icon" -Value "C:\Windows\System32\cleanmgr.exe"
    New-Item "$desk\DiskCleanup\command" -Force | Out-Null
    Set-ItemProperty "$desk\DiskCleanup\command" -Name "(default)" -Value "C:\Windows\System32\cleanmgr.exe"

    # --- Device Manager ---
    New-Item "$bg\DeviceManager" -Force | Out-Null
    Set-ItemProperty "$bg\DeviceManager" -Name "MUIVerb" -Value "Device Manager"
    Set-ItemProperty "$bg\DeviceManager" -Name "Icon" -Value "%SystemRoot%\system32\devmgr.dll,-201"
    New-Item "$bg\DeviceManager\command" -Force | Out-Null
    Set-ItemProperty "$bg\DeviceManager\command" -Name "(default)" -Value "devmgmt.msc"

    # --- Control Panel ---
    New-Item "$bg\ControlPanel" -Force | Out-Null
    Set-ItemProperty "$bg\ControlPanel" -Name "MUIVerb" -Value "Control Panel"
    Set-ItemProperty "$bg\ControlPanel" -Name "Icon" -Value "%systemroot%\System32\imageres.dll,-27"
    New-Item "$bg\ControlPanel\command" -Force | Out-Null
    Set-ItemProperty "$bg\ControlPanel\command" -Name "(default)" -Value "control.exe"

    # --- Task Manager ---
    New-Item "$bg\TaskManager" -Force | Out-Null
    Set-ItemProperty "$bg\TaskManager" -Name "MUIVerb" -Value "Task Manager"
    Set-ItemProperty "$bg\TaskManager" -Name "Icon" -Value "Taskmgr.exe"
    New-Item "$bg\TaskManager\command" -Force | Out-Null
    Set-ItemProperty "$bg\TaskManager\command" -Name "(default)" -Value "taskmgr.exe"

    # --- Windows Tools ---
    New-Item "$bg\WindowsTools" -Force | Out-Null
    Set-ItemProperty "$bg\WindowsTools" -Name "MUIVerb" -Value "Windows Tools"
    Set-ItemProperty "$bg\WindowsTools" -Name "Icon" -Value "%systemroot%\system32\imageres.dll,-114"
    New-Item "$bg\WindowsTools\command" -Force | Out-Null
    Set-ItemProperty "$bg\WindowsTools\command" -Name "(default)" -Value "explorer.exe shell:::{D20EA4E1-3957-11d2-A40B-0C5020524153}"

    # --- Windows Version (winver) ---
    New-Item "$desk\WindowsVersion" -Force | Out-Null
    Set-ItemProperty "$desk\WindowsVersion" -Name "MUIVerb" -Value "Windows Version"
    Set-ItemProperty "$desk\WindowsVersion" -Name "Icon" -Value "imageres.dll,-81"
    New-Item "$desk\WindowsVersion\command" -Force | Out-Null
    Set-ItemProperty "$desk\WindowsVersion\command" -Name "(default)" -Value "winver.exe"
	
    # --- Windows Security ---
    $mainKey = "Registry::HKEY_CLASSES_ROOT\DesktopBackground\Shell\WindowsSecurity"
    New-Item -Path $mainKey -Force | Out-Null
    Set-ItemProperty -Path $mainKey -Name "Icon" -Value "%ProgramFiles%\Windows Defender\EppManifest.dll,-101"
    Set-ItemProperty -Path $mainKey -Name "MUIVerb" -Value "Windows &Security"
    Set-ItemProperty -Path $mainKey -Name "Position" -Value "Bottom"
    Set-ItemProperty -Path $mainKey -Name "SubCommands" -Value ""

       # Submenu items (Optimierte englische Tastenkürzel)
    $submenus = @(
        @{Name="001flyout"; Label="&Home"; Command="explorer windowsdefender:"}
        @{Name="002flyout"; Label="&Virus & threat protection"; Command="explorer windowsdefender://threat"}
        @{Name="003flyout"; Label="&Account protection"; Command="explorer windowsdefender://account"}
        @{Name="004flyout"; Label="&Firewall & network protection"; Command="explorer windowsdefender://network"}
        @{Name="005flyout"; Label="&App & browser control"; Command="explorer windowsdefender://appbrowser"}
        @{Name="006flyout"; Label="&Device security"; Command="explorer windowsdefender://devicesecurity"}
        @{Name="007flyout"; Label="Device &performance & health"; Command="explorer windowsdefender://perfhealth"}
        @{Name="008flyout"; Label="&Family options"; Command="explorer windowsdefender://family"}
        @{Name="009flyout"; Label="Protection &history"; Command="explorer windowsdefender://history"}
        @{Name="010flyout"; Label="Security &providers"; Command="explorer windowsdefender://providers"}
        @{Name="011flyout"; Label="&Notifications"; Command="explorer windowsdefender://settings"}
    )


    foreach ($submenu in $submenus) {
        $shellKey = "$mainKey\shell\$($submenu.Name)"
        $commandKey = "$shellKey\command"
        
        New-Item -Path $shellKey -Force | Out-Null
        Set-ItemProperty -Path $shellKey -Name "MUIVerb" -Value $submenu.Label
        
        New-Item -Path $commandKey -Force | Out-Null
        Set-ItemProperty -Path $commandKey -Name "(Default)" -Value $submenu.Command
    }
}

function Set-WmfSingleClick {
    param($LogBox)

    Write-WmfLog -Text "→ Enabling single-click to open" -LogBox $LogBox
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" `
    -Name "LogonCount" `
    -Value 24 `
    -Type QWord
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" `
    -Name "ShellState" `
    -Value ([byte[]](0x24,0x00,0x00,0x00,0x1C,0x20,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x01,0x00,0x00,0x00,0x13,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x62,0x00,0x00,0x00)) `
    -Type Binary

    $path1 = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FeatureUsage\AppLaunch"
    if (-not (Test-Path $path1)) {
        New-Item -Path $path1 -Force | Out-Null
    }
    Set-ItemProperty -Path $path1 `
        -Name "Microsoft.Windows.Explorer" `
        -Value 0x00000024 `
        -Type DWord

    $path2 = "HKCU:\Software\Microsoft\Windows\CurrentVersion\WSX\WSXPacks\Windows.Shell.StartMenu\4.0.1071.0"
    if (-not (Test-Path $path2)) {
        New-Item -Path $path2 -Force | Out-Null
    }
    Set-ItemProperty -Path $path2 `
        -Name "packLoadedSuccessfullyCount" `
        -Value 0x00000018 `
        -Type DWord
    Set-ItemProperty -Path $path2 `
        -Name "packOpenedCount" `
        -Value 0x00000018 `
        -Type DWord
}

function Set-WmfVFUProvider {
    param($LogBox)

    Write-WmfLog -Text "→ Setting VFUProvider StartTime" -LogBox $LogBox

    New-Item -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\VFUProvider" -Force | Out-Null
    Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\VFUProvider" `
        -Name "StartTime" `
        -Value ([byte[]](0x50,0xA7,0xF5,0x17,0xC9,0xCC,0xDB,0x01)) `
        -Type Binary
}


# ------------------------------------------------------------
# Functions – UNDO
# ------------------------------------------------------------

function Undo-WmfNoAnimations {
    Write-WmfLog -Text "→ Undo: Re-enabling animations" -LogBox $logBox
    $DesktopPath = "HKCU:\Control Panel\Desktop"
    $MetricsPath = "HKCU:\Control Panel\Desktop\WindowMetrics"
    Set-ItemProperty -Path $DesktopPath -Name "MinAnimate" -Value "1"
    Set-ItemProperty -Path $MetricsPath -Name "MinAnimate" -Value "1"
    $DefaultMask = ([byte[]](0x9E,0x3E,0x07,0x80,0x12,0x00,0x00,0x00))
    Set-ItemProperty -Path $DesktopPath -Name "UserPreferencesMask" -Value $DefaultMask -Type Binary
}

function Undo-WmfExplorerTweaks {
    Write-WmfLog -Text "→ Undo: Explorer & Taskbar" -LogBox $logBox
    $adv = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    Set-ItemProperty $adv "TaskbarAnimations" 1
    Set-ItemProperty $adv "ShowSecondsInSystemClock" 0
}

function Undo-WmfStart_TrackDocs {
    Write-WmfLog -Text "→ Undo: Start Menu recent files" -LogBox $logBox
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Start_TrackDocs" -Value 1
}

function Undo-WmfThisPCFolders {
    Write-WmfLog -Text "→ Undo: This PC folders" -LogBox $logBox
    $ns = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace"
    foreach ($guid in @(
        "{d3162b92-9365-467a-956b-92703aca08af}",
        "{088e3905-0323-4b02-9826-5d99428e115f}",
        "{24ad3ad4-a569-4530-98e1-ab02f9417aa8}"
    )) {
        Remove-Item -Path "$ns\$guid" -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Undo-WmfSpotlight {
    Write-WmfLog -Text "→ Undo: Spotlight" -LogBox $logBox
    Remove-ItemProperty -Path "HKCU:\Software\Policies\Microsoft\Windows\CloudContent" `
        -Name "DisableSpotlightCollectionOnDesktop" -ErrorAction SilentlyContinue
}

function Undo-WmfClearLogin {
    Write-WmfLog -Text "→ Undo: Login Screen" -LogBox $logBox
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" `
        -Name "DisableAcrylicBackgroundOnLogon" -ErrorAction SilentlyContinue
}

function Undo-WmfOldContextMenu {
    Write-WmfLog -Text "→ Undo: Classic Context Menu + Shell Extensions" -LogBox $logBox

    # Remove Classic Context Menu
    Remove-Item -Path "HKCU:\Software\Classes\CLSID\{031E4825-7B94-4dc3-B131-E946B44C8DD5}" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}" -Recurse -Force -ErrorAction SilentlyContinue

    # Remove Shell Extensions (Updated to English paths)
    foreach ($path in @(
        "HKCU:\Software\Classes\Directory\Background\shell\ComputerManagement",
        "HKCU:\Software\Classes\DesktopBackground\Shell\DiskCleanup",
        "HKCU:\Software\Classes\Directory\Background\shell\DeviceManager",
        "HKCU:\Software\Classes\Directory\Background\shell\ControlPanel",
        "HKCU:\Software\Classes\Directory\Background\shell\TaskManager",
        "HKCU:\Software\Classes\Directory\Background\shell\WindowsTools",
        "HKCU:\Software\Classes\DesktopBackground\Shell\WindowsVersion",
        "Registry::HKEY_CLASSES_ROOT\DesktopBackground\Shell\WindowsSecurity"
    )) {
        Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Undo-WmfExplorerOpenThisPC {
    Write-WmfLog -Text "→ Undo: Explorer opening 'This PC'" -LogBox $logBox
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" `
        -Name "LaunchTo" -Value 0
}

function Undo-WmfSingleClick {
    Write-WmfLog -Text "→ Undo: Single-click" -LogBox $logBox
    # Default value for double-click
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" `
        -Name "ShellState" -Value ([byte[]](0x24,0x00,0x00,0x00,0x32,0xa8,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x01,0x00,0x00,0x00,0x13,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x62,0x00,0x00,0x00))
}

# ------------------------------------------------------------
# APPLY Button
# ------------------------------------------------------------
$btnTweaks = New-Object System.Windows.Forms.Button
$btnTweaks.Text     = "Apply Tweaks"
$btnTweaks.Size     = New-Object System.Drawing.Size(200, 40)
$btnTweaks.Location = New-Object System.Drawing.Point(200, 340)
Set-WmfFlatButton -Button $btnTweaks -BackColor ([System.Drawing.Color]::LightSkyBlue)
$tabPrivacy.Controls.Add($btnTweaks)

$btnTweaks.Add_Click({
    Write-WmfLog -Text "Starting Tweaks..." -LogBox $logBox
	
    if ($cbNoAnimations.Checked)      { Set-WmfNoAnimations      -LogBox $logBox }
    if ($cbExplorerTweaks.Checked)    { Set-WmfExplorerTweaks    -LogBox $logBox }
    if ($cbStart_TrackDocs.Checked)   { Set-WmfStart_TrackDocs    -LogBox $logBox }
    if ($cbThisPCFolders.Checked)     { Set-WmfThisPCFolders     -LogBox $logBox }
    if ($cbSpotlight.Checked)         { Set-WmfSpotlight         -LogBox $logBox }
    if ($cbClearLogin.Checked)        { Set-WmfClearLogin        -LogBox $logBox }
    if ($cbOldContext.Checked)        { Set-WmfOldContextMenu    -LogBox $logBox }
    if ($cbOpenThisPC.Checked)        { Set-WmfExplorerOpenThisPC -LogBox $logBox }
    if ($cbSingleClick.Checked)       { Set-WmfSingleClick        -LogBox $logBox }

    Update-WmfStatusFlat -StatusLabel $status -Text "Tweaks applied" -Success $true
    Write-WmfLog -Text "→ All tweaks executed" -LogBox $logBox
})


# ------------------------------------------------------------
# UNDO Button
# ------------------------------------------------------------
$btnUndo = New-Object System.Windows.Forms.Button
$btnUndo.Text     = "Undo Tweaks"
$btnUndo.Size     = New-Object System.Drawing.Size(200, 40)
$btnUndo.Location = New-Object System.Drawing.Point(200, 390)
Set-WmfFlatButton -Button $btnUndo -BackColor ([System.Drawing.Color]::LightCoral)
$tabPrivacy.Controls.Add($btnUndo)

$btnUndo.Add_Click({
    Write-WmfLog -Text "Starting Undo..." -LogBox $logBox

    if ($cbNoAnimations.Checked)      { Undo-WmfNoAnimations }
    if ($cbExplorerTweaks.Checked)    { Undo-WmfExplorerTweaks }
    if ($cbStart_TrackDocs.Checked)   { Undo-WmfStart_TrackDocs }
    if ($cbThisPCFolders.Checked)     { Undo-WmfThisPCFolders }
    if ($cbSpotlight.Checked)         { Undo-WmfSpotlight }
    if ($cbClearLogin.Checked)        { Undo-WmfClearLogin }
    if ($cbOldContext.Checked)        { Undo-WmfOldContextMenu }
    if ($cbOpenThisPC.Checked)        { Undo-WmfExplorerOpenThisPC }
    if ($cbSingleClick.Checked)       { Undo-WmfSingleClick }

    Update-WmfStatusFlat -StatusLabel $status -Text "Tweaks reverted" -Success $true
    Write-WmfLog -Text "→ Selected features have been reset" -LogBox $logBox
})


#######################################################################################

# ------------------------------------------------------------
# TAB 2 – Services (with dynamic scroll + sticky buttons)
# ------------------------------------------------------------

# Main panel for Tab 2
$panelTools = New-Object System.Windows.Forms.Panel
$panelTools.Width      = 560
$panelTools.Height     = 450
$panelTools.AutoScroll = $false
$panelTools.Location   = New-Object System.Drawing.Point(10, 10)
$panelTools.BackColor  = $global:WmfBackColor
$tabTools.Controls.Add($panelTools)

# ------------------------------------------------------------
# UPPER SCROLL AREA (Categories + Services)
# ------------------------------------------------------------
$servicesScrollPanel = New-Object System.Windows.Forms.Panel
$servicesScrollPanel.Width      = 530
$servicesScrollPanel.Height     = 330
$servicesScrollPanel.AutoScroll = $true
$servicesScrollPanel.Location   = New-Object System.Drawing.Point(10, 10)
$servicesScrollPanel.BackColor  = $global:WmfBackColor
$panelTools.Controls.Add($servicesScrollPanel)

# ------------------------------------------------------------
# LOWER FIXED BUTTON AREA
# ------------------------------------------------------------
$servicesButtonPanel = New-Object System.Windows.Forms.Panel
$servicesButtonPanel.Width      = 530
$servicesButtonPanel.Height     = 60
$servicesButtonPanel.Location   = New-Object System.Drawing.Point(10, 350)
$servicesButtonPanel.BackColor  = $global:WmfBackColor
$panelTools.Controls.Add($servicesButtonPanel)

# ------------------------------------------------------------
# SERVICE DATABASE – RE-CATEGORIZED (English)
# ------------------------------------------------------------
$global:WmfServiceCatalog = @(

   # 1) User, App, Store & Cloud Services
    @{ Name="ClipSVC";          Category="User"; Desc="Store License Service"; Critical=$false; Recommended=$true }
    @{ Name="DsSvc";            Category="User"; Desc="Data Sharing Service"; Critical=$false; Recommended=$true }
    @{ Name="DoSvc";            Category="User"; Desc="Delivery Optimization"; Critical=$false; Recommended=$true }
    @{ Name="OneSyncSvc_3e080"; Category="User"; Desc="Sync Host"; Critical=$false; Recommended=$false }
    @{ Name="CDPUserSvc_3e080"; Category="User"; Desc="Connected Devices Platform User"; Critical=$false; Recommended=$false }
    @{ Name="shpamsvc";         Category="User"; Desc="Shared PC Account Manager"; Critical=$false; Recommended=$true }
    @{ Name="WalletService";    Category="User"; Desc="Wallet Service"; Critical=$false; Recommended=$True }
    @{ Name="RetailDemo";       Category="User"; Desc="Retail Demo Mode"; Critical=$false; Recommended=$true }
     
    # 2) Multimedia
    @{ Name="BthAvctpSvc";      Category="Multimedia"; Desc="Bluetooth AVCTP"; Critical=$false; Recommended=$false }
    @{ Name="BcastDVRUserService_3e080"; Category="Multimedia"; Desc="Broadcast DVR"; Critical=$false; Recommended=$false }
 
    # 3) Network & Connectivity
    @{ Name="SharedAccess";     Category="Network"; Desc="Internet Connection Sharing (ICS)"; Critical=$false; Recommended=$false }
    @{ Name="WSAIFabricSvc";    Category="Network"; Desc="WSAI Fabric Service"; Critical=$true; Recommended=$true }
    @{ Name="IKEEXT";           Category="Network"; Desc="IKE and AuthIP IPsec Keying Modules"; Critical=$true; Recommended=$true }
    @{ Name="lmhosts";          Category="Network"; Desc="TCP/IP NetBIOS Helper"; Critical=$false; Recommended=$false }
    @{ Name="SSDPSRV";          Category="Network"; Desc="SSDP Discovery"; Critical=$false; Recommended=$false }
    @{ Name="RasMan";           Category="Network"; Desc="Remote Access Connection Manager"; Critical=$false; Recommended=$true }
    @{ Name="WebClient";        Category="Network"; Desc="WebDAV Client"; Critical=$false; Recommended=$false }
    @{ Name="NetTcpPortSharing";Category="Network"; Desc="Net.Tcp Port Sharing Service"; Critical=$false; Recommended=$false }
    @{ Name="Wcmsvc";           Category="Network"; Desc="Windows Connection Manager"; Critical=$true; Recommended=$false }
    
    # 4) Remote Desktop & Remote Access
    @{ Name="UmRdpService";     Category="Remote"; Desc="RDP Port Redirector"; Critical=$false; Recommended=$true }
    @{ Name="TermService";      Category="Remote"; Desc="Remote Desktop Services"; Critical=$true; Recommended=$true }
    @{ Name="SessionEnv";       Category="Remote"; Desc="RDP Configuration"; Critical=$true; Recommended=$true }
    @{ Name="RemoteRegistry";   Category="Remote"; Desc="Remote Registry"; Critical=$false; Recommended=$false }
    @{ Name="WinRM";            Category="Remote"; Desc="Windows Remote Management (WS-Man)"; Critical=$true; Recommended=$false }

    # 5) Sensors & Location
    @{ Name="lfsvc";            Category="Sensors"; Desc="Geolocation Service"; Critical=$false; Recommended=$false }
    @{ Name="SensorDataService";Category="Sensors"; Desc="Sensor Data Service"; Critical=$false; Recommended=$false }
    @{ Name="SensorService";    Category="Sensors"; Desc="Sensor Service"; Critical=$false; Recommended=$false }
    @{ Name="WPDBusEnum";       Category="Sensors"; Desc="Portable Device Enumerator Service"; Critical=$false; Recommended=$true }
    @{ Name="MapsBroker";       Category="Sensors"; Desc="Downloaded Maps Manager"; Critical=$false; Recommended=$true }

    # 6) Security, Encryption & Authentication
    @{ Name="BDESVC";           Category="Security"; Desc="BitLocker Drive Encryption Service"; Critical=$true; Recommended=$true }
    @{ Name="EFS";              Category="Security"; Desc="Encrypting File System"; Critical=$true; Recommended=$false }
    @{ Name="ssh-agent";        Category="Security"; Desc="OpenSSH Authentication Agent"; Critical=$false; Recommended=$true }
    @{ Name="WbioSrvc";         Category="Security"; Desc="Windows Biometric Service"; Critical=$false; Recommended=$true }
    @{ Name="WpcMonSvc";        Category="Security"; Desc="Parental Controls"; Critical=$true; Recommended=$true }
	
    # 7) System & Windows Core
    @{ Name="FontCache";        Category="System"; Desc="Windows Font Cache Service"; Critical=$false; Recommended=$true }
    @{ Name="autotimesvc";      Category="System"; Desc="Cellular Time Service"; Critical=$false; Recommended=$true }
    @{ Name="fdPHost";          Category="System"; Desc="Function Discovery Provider Host"; Critical=$false; Recommended=$false }
    @{ Name="FDResPub";         Category="System"; Desc="Function Discovery Resource Publication"; Critical=$false; Recommended=$false }
    @{ Name="TrkWks";           Category="System"; Desc="Distributed Link Tracking Client"; Critical=$false; Recommended=$false }
    @{ Name="PcaSvc";           Category="System"; Desc="Program Compatibility Assistant"; Critical=$false; Recommended=$true }	
    
    # 8) Telephony & Cellular
    @{ Name="PhoneSvc";         Category="Telephony"; Desc="Phone Service"; Critical=$false; Recommended=$true }
    @{ Name="TapiSrv";          Category="Telephony"; Desc="Telephony"; Critical=$false; Recommended=$true }
    @{ Name="dmwappushservice"; Category="Telephony"; Desc="WAP Push Routing Service"; Critical=$false; Recommended=$true }
	
    # 9) Telemetry & Diagnostics
    @{ Name="DiagTrack";        Category="Telemetry"; Desc="Connected User Experiences and Telemetry"; Critical=$true; Recommended=$true }
    @{ Name="diagsvc";          Category="Telemetry"; Desc="Diagnostic Execution Service"; Critical=$false; Recommended=$true }
    @{ Name="DusmSvc";          Category="Telemetry"; Desc="Data Usage"; Critical=$false; Recommended=$true }
    @{ Name="Sens";             Category="Telemetry"; Desc="System Event Notification Service"; Critical=$true; Recommended=$true }
    @{ Name="WerSvc";           Category="Telemetry"; Desc="Windows Error Reporting Service"; Critical=$false; Recommended=$true }
    @{ Name="Wecsvc";           Category="Telemetry"; Desc="Windows Event Collector"; Critical=$false; Recommended=$true }

 
    # 10) Xbox
    #@{ Name="XboxGipSvc";       Category="Xbox"; Desc="Xbox Accessory Management"; Critical=$false; Recommended=$true }
    @{ Name="XblAuthManager";   Category="Xbox"; Desc="Xbox Live Auth"; Critical=$false; Recommended=$true }
    @{ Name="XblGameSave";      Category="Xbox"; Desc="Xbox Live Game Save"; Critical=$false; Recommended=$true }
    @{ Name="XboxNetApiSvc";    Category="Xbox"; Desc="Xbox Live Netzwerk"; Critical=$false; Recommended=$true }
)

# Get display names from Windows
foreach ($svc in $global:WmfServiceCatalog) {
    try {
        $serviceObj = Get-Service -Name $svc.Name -ErrorAction Stop
        $svc.DisplayName = $serviceObj.DisplayName
    } catch {
        $svc.DisplayName = $svc.Name
    }
}

$global:WmfServiceCheckboxes = @()

# ------------------------------------------------------------
# FUNCTIONS 
# ------------------------------------------------------------

function Disable-WmfSelectedServices {
    $selected = $global:WmfServiceCheckboxes | Where-Object { $_.Checked }
    Write-WmfLog -Text "--- Disabling selected services ---" -LogBox $LogBox
    foreach ($cb in $selected) {
        try {
            Set-Service  -Name $cb.Tag -StartupType Disabled -ErrorAction SilentlyContinue
            Stop-Service -Name $cb.Tag -Force           -ErrorAction SilentlyContinue
			
            Write-WmfLog -Text "→ Service disabled - '$($cb.Tag)'." -LogBox $LogBox
             
        } catch {
            Write-WmfLog -Text "Error disabling '$($cb.Tag)'." -State "error"
		    Update-WmfStatusFlat -StatusLabel $statusLabel -Text "Error disabling '$($cb.Tag)'." -State "error"
        }
	}
	Write-WmfLog -Text "-----→ All selected services have been disabled" -LogBox $LogBox
	Update-WmfStatusFlat -StatusLabel $status -Text "Selected services disabled" -Success $true
}

function Select-WmfRecommendedServices {
    foreach ($cb in $global:WmfServiceCheckboxes) {
        $info = $global:WmfServiceCatalog | Where-Object { $_.Name -eq $cb.Tag }
        if ($info) { $cb.Checked = $info.Recommended }
    }
    Write-WmfLog -Text "→ Recommended services have been marked." -LogBox $LogBox
    Update-WmfStatusFlat -StatusLabel $status -Text "Recommended services marked." -State "info"		
}

function Enable-WmfSelectedServices {
    $selected = $global:WmfServiceCheckboxes | Where-Object { $_.Checked }
    foreach ($cb in $selected) {
        try {
            Set-Service -Name $cb.Tag -StartupType Automatic -ErrorAction Stop
            Start-Service -Name $cb.Tag -ErrorAction Stop
			
            Write-WmfLog -Text "→ Service enabled - '$($cb.Tag)'." -LogBox $LogBox
            
        }
        catch {
            Update-WmfStatusFlat -StatusLabel $statusLabel -Text "Error enabling '$($cb.Tag)'." -State "error"
        }
    }
	Write-WmfLog -Text "-----→ All selected services have been enabled" -LogBox $LogBox
	Update-WmfStatusFlat -StatusLabel $status -Text "Selected services enabled" -Success $true
}

# ------------------------------------------------------------
# RENDER CATEGORIES + CHECKBOXES INTO SCROLL AREA
# ------------------------------------------------------------
$y = 10
$categories = $global:WmfServiceCatalog.Category | Sort-Object -Unique

foreach ($cat in $categories) {

    # Category Label
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text      = "=== $cat ==="
    $lbl.Font      = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
    $lbl.AutoSize  = $true
    $lbl.BackColor = $global:WmfBackColor
    $lbl.Location  = New-Object System.Drawing.Point(10, $y)
    $servicesScrollPanel.Controls.Add($lbl)
    $y += 40

    # Button: Select All
    $btnAll = New-Object System.Windows.Forms.Button
    $btnAll.Text     = "Select All"
    $btnAll.Width    = 120
    $btnAll.Location = New-Object System.Drawing.Point(10, $y)
    $btnAll.Tag      = $cat
    $btnAll.Add_Click({
        $category = $this.Tag
        foreach ($cb in $global:WmfServiceCheckboxes) {
            $info = $global:WmfServiceCatalog | Where-Object { $_.Name -eq $cb.Tag }
            if ($info.Category -eq $category) { $cb.Checked = $true }
        }
    })
    Set-WmfFlatButton -Button $btnAll -BackColor ([System.Drawing.Color]::LightGreen)
    $servicesScrollPanel.Controls.Add($btnAll)

    # Button: Deselect All
    $btnNone = New-Object System.Windows.Forms.Button
    $btnNone.Text     = "Deselect All"
    $btnNone.Width    = 120
    $btnNone.Location = New-Object System.Drawing.Point(140, $y)
    $btnNone.Tag      = $cat
    $btnNone.Add_Click({
        $category = $this.Tag
        foreach ($cb in $global:WmfServiceCheckboxes) {
            $info = $global:WmfServiceCatalog | Where-Object { $_.Name -eq $cb.Tag }
            if ($info.Category -eq $category) { $cb.Checked = $false }
        }
    })
    Set-WmfFlatButton -Button $btnNone -BackColor ([System.Drawing.Color]::LightSalmon)
    $servicesScrollPanel.Controls.Add($btnNone)

    $y += 50

    # Category Checkboxes
    foreach ($svc in $global:WmfServiceCatalog | Where-Object { $_.Category -eq $cat }) {

        $cb = New-Object System.Windows.Forms.CheckBox
        $cb.Text      = "$($svc.DisplayName) ($($svc.Name))"
        $cb.AutoSize  = $true
        $cb.Location  = New-Object System.Drawing.Point(10, $y)
        $cb.Tag       = $svc.Name
        $cb.Font      = $global:WmfFont
        $cb.BackColor = $global:WmfBackColor

        $servicesScrollPanel.Controls.Add($cb)
        $global:WmfServiceCheckboxes += $cb

        $y += 25
    }

    $y += 20
}


# ------------------------------------------------------------
# FIXED BUTTONS AT THE BOTTOM
# ------------------------------------------------------------

# Select Recommended Services
$btnRecommended = New-Object System.Windows.Forms.Button
$btnRecommended.Text     = "Select Recommended Services"
$btnRecommended.Width    = 250
$btnRecommended.Location = New-Object System.Drawing.Point(10, 8)
$btnRecommended.Add_Click({ Select-WmfRecommendedServices })
Set-WmfFlatButton -Button $btnRecommended -BackColor ([System.Drawing.Color]::LightSteelBlue)
$servicesButtonPanel.Controls.Add($btnRecommended)

# Disable Services
$btnDisable = New-Object System.Windows.Forms.Button
$btnDisable.Text     = "Disable Selected Services"
$btnDisable.Width    = 250
$btnDisable.Location = New-Object System.Drawing.Point(270, 8)
$btnDisable.Add_Click({ Disable-WmfSelectedServices })
Set-WmfFlatButton -Button $btnDisable -BackColor ([System.Drawing.Color]::LightCoral)
$servicesButtonPanel.Controls.Add($btnDisable)

# Enable Services 
$btnEnable = New-Object System.Windows.Forms.Button
$btnEnable.Text     = "Enable Selected Services"
$btnEnable.Width    = 250
$btnEnable.Location = New-Object System.Drawing.Point(130, 30)
$btnEnable.Add_Click({ Enable-WmfSelectedServices })
Set-WmfFlatButton -Button $btnEnable -BackColor ([System.Drawing.Color]::PaleGreen)
$servicesButtonPanel.Controls.Add($btnEnable)


######################################################################################
# ------------------------------------------------------------
# ------------------------------------------------------------
# TAB 3 - System Protection (DiagTrack + Privacy + System Tweaks)
# ------------------------------------------------------------
$tabDiag.Text = "System Protection"

$panelDiag = New-WmfScrollPanel -Parent $tabDiag -X 10 -Y 10 -Width 560 -Height 350
$panelDiag.BackColor = $global:WmfBackColor
Reset-WmfPanelCheckboxY

# Checkboxes 

$cbAutoLogger = $null
Add-WmfPanelCheckbox -Panel $panelDiag -Text "Block DiagTrack AutoLogger" -OutVariable ([ref]$cbAutoLogger)

$cbDiag = $null
Add-WmfPanelCheckbox -Panel $panelDiag -Text "Block and clear Diagnostic Data (Telemetry)" -OutVariable ([ref]$cbDiag)

$cbPrivacyDocs = $null
Add-WmfPanelCheckbox -Panel $panelDiag -Text "Deny App access to Documents" -OutVariable ([ref]$cbPrivacyDocs)

$cbTyping = $null
Add-WmfPanelCheckbox -Panel $panelDiag -Text "Disable Inking & Typing collection" -OutVariable ([ref]$cbTyping)

$cbUAC = $null
Add-WmfPanelCheckbox -Panel $panelDiag -Text "Disable UAC (EnableLUA=0)" -OutVariable ([ref]$cbUAC)

$cbSvchost = $null
Add-WmfPanelCheckbox -Panel $panelDiag -Text "Optimize svchost.exe grouping (Block Telemetry)" -OutVariable ([ref]$cbSvchost)

$cbDefender = $null
Add-WmfPanelCheckbox -Panel $panelDiag -Text "Disable Defender Auto Sample Submission" -OutVariable ([ref]$cbDefender)

$cbDeliveryOpt = $null
Add-WmfPanelCheckbox -Panel $panelDiag -Text "Disable Delivery Optimization" -OutVariable ([ref]$cbDeliveryOpt)

$cbCDM = $null
Add-WmfPanelCheckbox -Panel $panelDiag -Text "Disable Content Delivery Manager" -OutVariable ([ref]$cbCDM)

$cbOfficeTel = $null
Add-WmfPanelCheckbox -Panel $panelDiag -Text "Disable Office Telemetry / Logging" -OutVariable ([ref]$cbOfficeTel)

#--------------------------------
# BUTTON – EXECUTE
#--------------------------------
$btnDiag = New-Object System.Windows.Forms.Button
$btnDiag.Text     = "Run System Protection"
$btnDiag.Size     = New-Object System.Drawing.Size(220, 40)
$btnDiag.Location = New-Object System.Drawing.Point(180, 370)
Set-WmfFlatButton -Button $btnDiag -BackColor ([System.Drawing.Color]::LightYellow)
$tabDiag.Controls.Add($btnDiag)

$btnDiag.Add_Click({
    Write-WmfLog -Text "Starting System Protection..." -LogBox $logBox
#  1**********************************************************************************************	
    if ($cbAutoLogger.Checked) {
        $autoLoggerDir = "$env:PROGRAMDATA\Microsoft\Diagnosis\ETLLogs\AutoLogger"
        if (Test-Path "$autoLoggerDir\AutoLogger-Diagtrack-Listener.etl") { Remove-Item "$autoLoggerDir\AutoLogger-Diagtrack-Listener.etl" -Force }
        icacls $autoLoggerDir /deny SYSTEM:`(OI`)`(CI`)F | Out-Null
        Write-WmfLog -Text "→ AutoLogger blocked" -LogBox $logBox
    }
#  2**********************************************************************************************
    if ($cbDiag.Checked) {
        Stop-WmfDiagTrackService -LogBox $logBox
        Remove-WmfDiagTrackETL -LogBox $logBox
        Restore-WmfDiagTrackService -LogBox $logBox
		Write-WmfLog -Text "→ Telemetry data transmission blocked and cleared" -LogBox $logBox
    }
#  3**********************************************************************************************	
    if ($cbPrivacyDocs.Checked) {
        Set-WmfRegistryValue -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\documentsLibrary" -Name "Value" -Value "Deny" -Type String 
	    Write-WmfLog -Text "→ Access to documents blocked" -LogBox $logBox
    }

#  4********************************************************************************************
    if ($cbTyping.Checked) {
        Write-WmfLog -Text " " -LogBox $logBox
        Write-WmfLog -Text " → Disabling text input collection and preventing" -LogBox $logBox
		Write-WmfLog -Text "     contacts from being added to the dictionary." -LogBox $logBox
		Write-WmfLog -Text " " -LogBox $logBox
		 
		$registryPath = "HKCU:\Software\Microsoft\InputPersonalization"
        if (!(Test-Path $registryPath)) { New-Item -Path $registryPath -Force | Out-Null }
        Set-ItemProperty -Path $registryPath -Name "RestrictImplicitInkCollection" -Value 1 -Type DWord
		Set-ItemProperty -Path $registryPath -Name "RestrictImplicitTextCollection" -Value 1 -Type DWord	
   		 
        $registryPath = "HKCU:\Software\Microsoft\InputPersonalization\TrainedDataStore"
        if (!(Test-Path $registryPath)) { New-Item -Path $registryPath -Force | Out-Null }
   	    Set-ItemProperty -Path $registryPath -Name "HarvestContacts" -Value 0 -Type DWord
        Set-ItemProperty -Path $registryPath -Name "HarvestingInitialized" -Value 0 -Type DWord
            
        $registryPath = "HKCU:\Software\Microsoft\Personalization\Settings"
        if (!(Test-Path $registryPath)) { New-Item -Path $registryPath -Force | Out-Null }
        Set-ItemProperty -Path $registryPath -Name "AcceptedPrivacyPolicy" -Value 0 -Type DWord
	}
#  5********************************************************************************************
    if ($cbUAC.Checked) {
        Set-WmfRegistryValue -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System" -Name "EnableLUA" -Value 0 -Type DWord
		Write-WmfLog -Text "→ UAC disabled" -LogBox $LogBox
    }
#  6********************************************************************************************
    if ($cbSvchost.Checked) {
        $ram = (Get-CimInstance -ClassName Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum).Sum / 1kb
        Set-WmfRegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control" -Name "SvcHostSplitThresholdInKB" -Value $ram -Type DWord
		Write-WmfLog -Text "→ Telemetry svchost grouping optimized" -LogBox $LogBox
    }
#  7********************************************************************************************
    if ($cbDefender.Checked) {
        Set-MpPreference -SubmitSamplesConsent 2 -ErrorAction SilentlyContinue
        Write-WmfLog -Text "→ Defender Sample Submission disabled" -LogBox $logBox
    }
#  8********************************************************************************************
    if ($cbDeliveryOpt.Checked) {
        $doPath = "Registry::HKEY_USERS\S-1-5-20\Software\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Settings"
        if (-not (Test-Path $doPath)) { New-Item -Path $doPath -Force | Out-Null }
        Set-WmfRegistryValue -Path $doPath -Name "DODownloadMode" -Value 0 -Type DWord
        Write-WmfLog -Text "→ Delivery Optimization disabled" -LogBox $logBox
    }
#  9********************************************************************************************
    if ($cbCDM.Checked) {
        $pathCDM = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
        $settingsCDM = @("ContentDeliveryAllowed", "FeatureManagementEnabled", "OemPreInstalledAppsEnabled", "PreInstalledAppsEnabled", "SilentInstalledAppsEnabled", "SoftLandingEnabled", "SystemPaneSuggestionsEnabled", "SubscribedContent-338387Enabled", "SubscribedContent-338388Enabled", "SubscribedContent-338389Enabled", "SubscribedContent-338393Enabled")
        foreach ($name in $settingsCDM) { if (Test-Path $pathCDM) { Set-ItemProperty -Path $pathCDM -Name $name -Value 0 -ErrorAction SilentlyContinue } }
        Write-WmfLog -Text "→ Content Delivery Manager disabled" -LogBox $logBox
    }
#  10********************************************************************************************
    if ($cbOfficeTel.Checked) {
        $versions = @("15.0", "16.0")
        foreach ($v in $versions) {
            Set-WmfRegistryValue -Path "HKCU:\SOFTWARE\Microsoft\Office\$v\Common\ClientTelemetry" -Name "DisableTelemetry" -Value 1 -Type DWord
            Set-WmfRegistryValue -Path "HKCU:\SOFTWARE\Microsoft\Office\$v\Common\Feedback" -Name "Enabled" -Value 0 -Type DWord
        }
        # Hier würde die Task-Deaktivierung folgen (analog zu oben)
        Write-WmfLog -Text "→ Office Telemetry disabled" -LogBox $logBox
    }
	Write-WmfLog -Text "→ System protection completed" -LogBox $logBox
})


# ------------------------------------------------------------
# BUTTON – UNDO
# ------------------------------------------------------------
$btnDiagUndo = New-Object System.Windows.Forms.Button
$btnDiagUndo.Text     = "Undo System Protection"
$btnDiagUndo.Size     = New-Object System.Drawing.Size(220, 40)
$btnDiagUndo.Location = New-Object System.Drawing.Point(180, 420)
Set-WmfFlatButton -Button $btnDiagUndo -BackColor ([System.Drawing.Color]::LightCoral)
$tabDiag.Controls.Add($btnDiagUndo)

$btnDiagUndo.Add_Click({

    Write-WmfLog -Text "Starting Undo function..." -LogBox $logBox
	
# 1 DiagTrack Autologger
    # Reset AutoLogger ACL
    $autoLoggerDir = "$env:PROGRAMDATA\Microsoft\Diagnosis\ETLLogs\AutoLogger"
    icacls $autoLoggerDir /remove:d SYSTEM | Out-Null
    Write-WmfLog -Text "→ AutoLogger permissions restored" -LogBox $logBox
	
# 2 Restore Diagnostic Data
    Restore-WmfDiagTrackService
	Write-WmfLog -Text "→ Diagnostic data restored" -LogBox $logBox

# 3 Access to Documents
    Set-WmfRegistryValue -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\documentsLibrary" `
             -Name "Value" -Value "Allow" -Type String
    Write-WmfLog -Text "→ Access to documents allowed" -LogBox $logBox


# 4 Typing & Inking Collection  
	$registryPath = "HKCU:\Software\Microsoft\InputPersonalization"
    if (!(Test-Path $registryPath)) {
        New-Item -Path $registryPath -Force | Out-Null
    }
    Set-ItemProperty -Path $registryPath -Name "RestrictImplicitInkCollection" -Value 0 -Type DWord
    Set-ItemProperty -Path $registryPath -Name "RestrictImplicitTextCollection" -Value 0 -Type DWord	
   		 
    $registryPath = "HKCU:\Software\Microsoft\InputPersonalization\TrainedDataStore"
    if (!(Test-Path $registryPath)) {
        New-Item -Path $registryPath -Force | Out-Null
    }
   	Set-ItemProperty -Path $registryPath -Name "HarvestContacts" -Value 1 -Type DWord
    Set-ItemProperty -Path $registryPath -Name "HarvestingInitialized" -Value 1 -Type DWord
            
    $registryPath = "HKCU:\Software\Microsoft\Personalization\Settings"
    if (!(Test-Path $registryPath)) {
        New-Item -Path $registryPath -Force | Out-Null
    }
    Set-ItemProperty -Path $registryPath -Name "AcceptedPrivacyPolicy" -Value 1 -Type DWord
	Write-WmfLog -Text "→ Text input collection allowed" -LogBox $logBox
	

# 5 Re-enable UAC
    Set-WmfRegistryValue -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System" `
                         -Name "EnableLUA" -Value 1 -Type DWord
    Write-WmfLog -Text "→ UAC has been re-enabled" -LogBox $logBox						 

# 6 Reset svchost Grouping
    Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control" `
                        -Name "SvcHostSplitThresholdInKB" -ErrorAction SilentlyContinue
    Write-WmfLog -Text "→ Svchost grouping reset" -LogBox $logBox
  
# 7 Reset Defender Sample Submission
    Set-MpPreference -SubmitSamplesConsent 1 -ErrorAction SilentlyContinue
    Write-WmfLog -Text "→ Defender Sample Submission reset" -LogBox $logBox


# 8 Reset Delivery Optimization
    $doPath = "Registry::HKEY_USERS\S-1-5-20\Software\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Settings"
    if (Test-Path $doPath) {
        Remove-ItemProperty -Path $doPath -Name "DODownloadMode" -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $doPath -Name "DownloadMode" -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $doPath -Name "DownloadModeProvider" -ErrorAction SilentlyContinue
        Write-WmfLog -Text "→ Delivery Optimization reset" -LogBox $logBox
    }

  
# 9 Re-enable ContentDeliveryManager
    $pathCDM = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
    $settingsCDM = @(
        "ContentDeliveryAllowed", "FeatureManagementEnabled", "OemPreInstalledAppsEnabled",
        "PreInstalledAppsEnabled", "SilentInstalledAppsEnabled", "SoftLandingEnabled",
        "SystemPaneSuggestionsEnabled", "SubscribedContent-338387Enabled",
        "SubscribedContent-338388Enabled", "SubscribedContent-338389Enabled",
        "SubscribedContent-338393Enabled"
    )
    foreach ($name in $settingsCDM) {
        if (Test-Path $pathCDM) {
            Set-ItemProperty -Path $pathCDM -Name $name -Value 1 -ErrorAction SilentlyContinue
        }
    }
    $subPath = Join-Path $pathCDM "Subscriptions"
    if (-not (Test-Path $subPath)) {
        New-Item -Path $subPath -Force | Out-Null
    }
    Write-WmfLog -Text "→ ContentDeliveryManager re-enabled." -LogBox $logBox

# 10 Office Telemetry UNDO
    $versions = @("15.0", "16.0")
    foreach ($v in $versions) {
        Remove-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Office\$v\Common\ClientTelemetry" -Name "DisableTelemetry" -ErrorAction SilentlyContinue
        Set-WmfRegistryValue -Path "HKCU:\SOFTWARE\Microsoft\Office\$v\Common\Feedback" -Name "Enabled" -Value 1 -Type DWord
        Set-WmfRegistryValue -Path "HKCU:\SOFTWARE\Policies\Microsoft\Office\$v\OSM" -Name "EnableLogging" -Value 1 -Type DWord
    }

    # Re-enable Office Tasks
    $oTasks = "OfficeTelemetryAgentFallBack","OfficeTelemetryAgentFallBack2016","OfficeTelemetryAgentLogOn","OfficeTelemetryAgentLogOn2016"
    foreach ($t in $oTasks) {
        $task = Get-ScheduledTask -TaskPath "\Microsoft\Office\" -TaskName $t -ErrorAction SilentlyContinue
        if ($task) { 
            $task | Enable-ScheduledTask -ErrorAction SilentlyContinue
            Write-WmfLog -Text "→ Office Task enabled." -LogBox $logBox
        }
    }

    # Reset Checkboxes
    foreach ($cb in @(
        $cbAutoLogger, $cbDiag, $cbPrivacyDocs, $cbUAC, $cbSvchost,
        $cbDefender, $cbNoPagefile, $cbHibernate, $cbDeliveryOpt, $cbCDM, $cbOfficeTel
    )) {
        if ($null -ne $cb) { $cb.Checked = $false }
    }

    Write-WmfLog -Text "-----→ Undo function completed" -LogBox $logBox
})


##########################################################################################
# ------------------------------------------------------------
# TAB 4 – Cleanup 
# ------------------------------------------------------------

$panelCleanup = New-WmfScrollPanel -Parent $tabCleanup -X 10 -Y 10 -Width 580 -Height 500
$panelCleanup.BackColor = $global:WmfBackColor
Reset-WmfPanelCheckboxY

# RAM Check for Safety (Pagefile logic)
$sysInfo = Get-CimInstance Win32_ComputerSystem
$totalRamGB = [Math]::Round($sysInfo.TotalPhysicalMemory / 1GB)

# ------------------------------------------------------------
# Checkbox Variables
# ------------------------------------------------------------
$cbSystem        = $null
$cbCache         = $null
$cbResStorage    = $null
$cbWER           = $null
$cbWinSxS        = $null
$cbCompactOS     = $null
$cbHibernate     = $null
$cbNoPagefile    = $null
$cbHardLink      = $null

# ------------------------------------------------------------
# Create Checkboxes
# ------------------------------------------------------------
Add-WmfPanelCheckbox -Panel $panelCleanup -Text "System Cleanup"                  -OutVariable ([ref]$cbSystem)
Add-WmfPanelCheckbox -Panel $panelCleanup -Text "Clear Cache"                     -OutVariable ([ref]$cbCache)
Add-WmfPanelCheckbox -Panel $panelCleanup -Text "Delete Reserved Storage"          -OutVariable ([ref]$cbResStorage)
Add-WmfPanelCheckbox -Panel $panelCleanup -Text "Clear Windows Error Reports"     -OutVariable ([ref]$cbWER)
Add-WmfPanelCheckbox -Panel $panelCleanup -Text "WinSxS Cleanup (Duration: ~5 min)" -OutVariable ([ref]$cbWinSxS)
Add-WmfPanelCheckbox -Panel $panelCleanup -Text "Enable CompactOS (Duration: ~20 min)" -OutVariable ([ref]$cbCompactOS)
Add-WmfPanelCheckbox -Panel $panelCleanup -Text "Disable Hibernation (hiberfil.sys)" -OutVariable ([ref]$cbHibernate)
Add-WmfPanelCheckbox -Panel $panelCleanup -Text "Delete -HardLinkBackup- folder"  -OutVariable ([ref]$cbHardLink)
Add-WmfPanelCheckbox -Panel $panelCleanup -Text "Disable Pagefile"                -OutVariable ([ref]$cbNoPagefile)

    # Special logic for Pagefile (4GB Limit)
    if ($totalRamGB -le 4) {
        $cbNoPagefile.Enabled = $false
        $cbNoPagefile.Text = "Pagefile (Locked: Only $totalRamGB GB RAM!)"
        $cbNoPagefile.ForeColor = [System.Drawing.Color]::Gray
    } else {
        $cbNoPagefile.Text = "(RAM: $totalRamGB GB) Pagefile can be disabled"
    }


# ------------------------------------------------------------
# UI Elements (Status & Progress)
# ------------------------------------------------------------
$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Text = ""
$statusLabel.Location = New-Object System.Drawing.Point(10, 330)
$statusLabel.Size = New-Object System.Drawing.Size(560, 20)
$panelCleanup.Controls.Add($statusLabel)

function Show-Status {
    param([string]$Text)
	$statusLabel.ForeColor = [System.Drawing.Color]::Blue
    $statusLabel.Text = $Text
    $statusLabel.Refresh()
}

$pbCleanup = New-Object System.Windows.Forms.ProgressBar
$pbCleanup.Location = New-Object System.Drawing.Point(10, 360)
$pbCleanup.Size = New-Object System.Drawing.Size(560, 25)
$panelCleanup.Controls.Add($pbCleanup)

$btnCleanup = New-Object System.Windows.Forms.Button
$btnCleanup.Text = "Start Cleanup"
$btnCleanup.Size = New-Object System.Drawing.Size(200, 40)
$btnCleanup.Location = New-Object System.Drawing.Point(200, 400)
Set-WmfFlatButton -Button $btnCleanup -BackColor ([System.Drawing.Color]::LightGreen)
$panelCleanup.Controls.Add($btnCleanup)

# ------------------------------------------------------------
# BUTTON CLICK LOGIC
# ------------------------------------------------------------
$btnCleanup.Add_Click({

    $executed = @()
    $skipped  = @()

    # 1. System Cleanup
   if ($cbSystem.Checked) {
    Show-Status "System cleanup in progress..."
    $totalFreed = 0 

    Clear-WmfTemp -LogBox $logBox
    Clear-WmfPrefetch -LogBox $logBox
    Clear-WmfLogFiles -LogBox $logBox

    $localAppData = $env:LOCALAPPDATA
    $cleanupPaths = @(
            "C:\Windows\Temp",
            "C:\Windows\WinSxS\Backup",
            "C:\Windows\assembly",
            "C:\Windows\System32\Microsoft-Edge-WebView",
            "C:\Windows\ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Cache\",
            "C:\ProgramData\LGHUB\cache",
            "C:\`$HardLinkBackup",
            "C:\Recovery\WindowsRE",
            "C:\Windows\ServiceProfiles\LocalService\AppData\Local\FontCache",
            "C:\Windows\System32\sru",
            "C:\Users\Admin\AppData\Local\Microsoft\Windows\WebCache",
            "C:\Users\Admin\AppData\Local\Packages\MicrosoftWindows.Client.CBS_cw5n1h2txyewy"
        )

    foreach ($path in $cleanupPaths) {
        if (Test-Path $path) {
            # Measure size BEFORE
            $sizeBefore = (Get-ChildItem $path -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
            
            # Execute Cleanup
            Clear-WmfFolder $path -Force -Recurse -LogBox $logBox
            
            # Measure size AFTER
            $sizeAfter = (Get-ChildItem $path -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
            
            # Add difference
            $totalFreed += ($sizeBefore - $sizeAfter)
        }
    }
#---------------------
 # Delete folders "C:\`$WINDOWS.~BT","C:\`$WINDOWS.~LS"
 
$FolderPaths = @(
    'C:\$WINDOWS.~BT',
    'C:\$WINDOWS.~LS'
)

foreach ($Path in $FolderPaths) {
    Write-WmfLog -Text "`n--- Checking: $Path ---" -LogBox $logBox

    # 1. Safety check (Root directory)
    if ($Path -match '^[A-Z]:\\?$' ) {
        Write-WmfLog -Text "ABORT: '$Path' is a root directory! Skipping..." -LogBox $logBox
        continue
    }

    # 2. Existence check
    if (Test-Path -LiteralPath $Path) {
        Write-WmfLog -Text "Deletion process started..." -LogBox $logBox
        
        # Execute CMD command
        cmd.exe /c "rmdir /s /q `"$Path`""

        # 3. Success check via Exit-Code
        if ($LASTEXITCODE -eq 0) {
            Write-WmfLog -Text "SUCCESS: Folder successfully deleted." -LogBox $logBox
        } else {
            Write-WmfLog -Text "ERROR: Folder could not be deleted (Code: $LASTEXITCODE)." -LogBox $logBox
            Write-WmfLog -Text "Note: System folders may require Admin rights or 'takeown'." -LogBox $logBox
        }
    } else {
        Write-WmfLog -Text "INFO: Folder already does not exist." -LogBox $logBox
    }
}

#---------------------
    # Include special file deletion
    if (Test-Path "C:\WinPEpge.sys") {
        $fileSize = (Get-Item "C:\WinPEpge.sys").Length
        Remove-Item "C:\WinPEpge.sys" -Force
        $totalFreed += $fileSize
    }
    if (Test-Path "C:\DumpStack.log.tmp") {
       Remove-Item "C:\DumpStack.log.tmp" -Force
    }

    # Format result and add to log
    $mbFreed = $totalFreed / 1MB
    $executed += "System Cleanup – {0:N2} MB freed" -f $mbFreed
}


    # 2. Cache
    if ($cbCache.Checked) {
        Show-Status "Clearing cache..."
        Clear-WmfBrowserCaches -LogBox $logBox
        Clear-WmfThumbnails -LogBox $logBox
        $executed += "Cache"
    }

    # 3. Reserved Storage
    if ($cbResStorage.Checked) {
        Show-Status "Deleting reserved storage... Please wait..."
        Clear-WmfReservedStorage -LogBox $logBox
        $executed += "Reserved Storage"
    } else { $skipped += "Reserved Storage" }

    # 4. Windows Error Reports
    if ($cbWER.Checked) {
        Show-Status "Deleting Windows Error Reports..."
        Clear-WmfWERFiles -LogBox $logBox
        Clear-WmfWERMemoryDumps -LogBox $logBox
        Clear-WmfWERMinidumps -LogBox $logBox
        $executed += "Windows Error Reports"
    } else { $skipped += "Windows Error Reports" }

    # 5. WinSxS
    if ($cbWinSxS.Checked) {
        Show-Status "WinSxS cleanup in progress..."
        Start-WmfDismComponentCleanup -LogBox $logBox -ProgressBar $pbCleanup -StatusLabel $statusLabel
        $executed += "WinSxS"
    }
  
    # 6. CompactOS
    if ($cbCompactOS.Checked) {
       Show-Status "Enabling CompactOS... this may take up to 20 min. Please be patient!!!" 
	    Invoke-WmfCompactOS -LogBox $logBox -ProgressBar $pbCleanup
        $executed += "CompactOS"
    }

    # 7. Hibernation
    if ($cbHibernate.Checked) {
        Show-Status "Disabling Hibernation..."
        powercfg -h off
        Write-WmfLog -Text "Hibernation disabled" -LogBox $logBox
        $executed += "Hibernation"
    }

    # 8. Pagefile
    if ($cbNoPagefile.Checked -and $totalRamGB -gt 4) {
        $confirm = [System.Windows.Forms.MessageBox]::Show("Disabling the pagefile can lead to system crashes with less than 8GB RAM. Do you want to proceed?", "Security Warning", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
        if ($confirm -eq 'Yes') {
            Set-WmfRegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "PagingFiles" -Value " " -Type MultiString -LogBox $logBox
            Write-WmfLog -Text "Pagefile disabled (Requires Reboot)" -LogBox $logBox
            $executed += "Pagefile"
        }
    }

    # 9. HardLinkBackup Folder Deletion
    if ($cbHardLink.Checked) {
        $backupPath = 'C:\$HardLinkBackup'
        Write-WmfLog -Text "Removing HardLinkBackup folder..." -LogBox $logBox

        # Safety check: Never delete root!
        if ($backupPath -eq 'C:\' -or $backupPath -eq 'C:') {
            Write-WmfLog -Text "ABORT: Path points to root directory! Process stopped." -LogBox $logBox
            return
        }

        # Check if folder exists
        if (Test-Path -LiteralPath $backupPath) {
            # Use CMD as PowerShell sometimes struggles with hardlink deletion
            cmd.exe /c "rmdir /s /q `"$backupPath`""

            if (-not (Test-Path -LiteralPath $backupPath)) {
                Write-WmfLog -Text "HardLinkBackup folder successfully removed." -LogBox $logBox
            }
            else {
                Write-WmfLog -Text "HardLinkBackup folder could not be removed." -LogBox $logBox
            }
        }
        else {
            Write-WmfLog -Text "HardLinkBackup folder does not exist." -LogBox $logBox
        }
    }

#_____________________________________________________________________________________________________________________________
##############################################################################################################################
	
##################################################################################
#     # Auslagerungsdatei wieder aktivieren
#    Set-WmfRegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" `
#                         -Name "PagingFiles" -Value "C:\pagefile.sys 0 0" -Type MultiString -LogBox $logBox
#
    # Ruhezustand wieder aktivieren
#    powercfg -h on
#    Write-WmfLog -Text "Ruhezustand aktiviert" -LogBox $logBox
##################################################################################	
# Final Evaluation
    $freeAfter = Get-WmfFreeSpace
    $freedBytes = $freeAfter - $freeBefore
    $freedFormatted = Format-WmfBytes $freedBytes
	
    Write-WmfLog -Text "--------------Free space before cleanup: $(Format-WmfBytes $freeBefore)" -LogBox $logBox
    Write-WmfLog -Text "-------------Free space after cleanup: $(Format-WmfBytes $freeAfter)" -LogBox $logBox
    Write-WmfLog -Text "Cleanup completed. -------Freed space: $freedFormatted" -LogBox $logBox
    Show-Status "Done!"

    # --- AUTOMATIC LOG EXPORT ---
    try {
        $exportPath = Join-Path ([Environment]::GetFolderPath("Desktop")) "SystemOptimization_Log.txt"
        $timestamp = Get-Date -Format "MM/dd/yyyy HH:mm:ss"
        $header = "`r`n================================================`r`n" +
                  "SYSTEM OPTIMIZATION FROM $timestamp`r`n" +
                  "================================================`r`n"
        
        $logContent = $logBox.Text
        $finalOutput = $header + $logContent + "`r`nTotal freed: $freedFormatted`r`n"
        
        Add-Content -Path $exportPath -Value $finalOutput -Encoding UTF8 -ErrorAction Stop
        Write-WmfLog -Text "-> Log file updated on Desktop." -LogBox $logBox
    }
    catch {
        Write-Warning "Log export failed: $($_.Exception.Message)"
    }

    [System.Windows.Forms.MessageBox]::Show("Cleanup finished.`nSpace freed: $freedFormatted`nLog saved to Desktop.", "Summary")
})

##########################################################################################

# ------------------------------------------------------------
# GUI starten
# ------------------------------------------------------------
$form.TopMost = $false
[void]$form.ShowDialog()

