# OneDrive Removal Script – with visible steps
# Run as Administrator!

# --- Check Admin rights and restart script if necessary ---
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {

    # Restart script with admin privileges
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell.exe"
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`""
    $psi.Verb = "runas"
    [System.Diagnostics.Process]::Start($psi) | Out-Null
    exit
}
# --- End Admin Block ---

Write-Host "`n[1] Terminating OneDrive process..." -ForegroundColor Cyan
taskkill.exe /F /IM "OneDrive.exe" -ErrorAction SilentlyContinue

Write-Host "`n[2] Uninstalling OneDrive..." -ForegroundColor Cyan
$setupPaths = @(
    "$env:systemroot\System32\OneDriveSetup.exe",
    "$env:systemroot\SysWOW64\OneDriveSetup.exe"
)

$uninstallStarted = $false
foreach ($path in $setupPaths) {
    if (Test-Path $path) {
        Write-Host "→ Starting uninstallation via: $path"
        Start-Process -FilePath $path -ArgumentList "/uninstall" -Wait
        $uninstallStarted = $true
    }
}

if (-not $uninstallStarted) {
    Write-Host "⚠️ OneDriveSetup.exe not found – uninstallation could not be started." -ForegroundColor Yellow
}

Start-Sleep -Seconds 5
if (Get-Process "OneDrive" -ErrorAction SilentlyContinue) {
    Write-Host "⚠️ OneDrive process is still running – uninstallation might have failed." -ForegroundColor Red
}

Write-Host "`n[3] Removing OneDrive leftovers..." -ForegroundColor Cyan
$leftovers = @(
    "$env:localappdata\Microsoft\OneDrive",
    "$env:programdata\Microsoft OneDrive",
    "$env:systemdrive\OneDriveTemp"
)

foreach ($item in $leftovers) {
    if (Test-Path $item) {
        Write-Host "→ Removing: $item"
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $item
    }
}

$oneDriveUserFolder = "$env:userprofile\OneDrive"
if (Test-Path $oneDriveUserFolder) {
    $itemCount = (Get-ChildItem $oneDriveUserFolder -Recurse -ErrorAction SilentlyContinue | Measure-Object).Count
    if ($itemCount -eq 0) {
        Write-Host "→ Deleting empty user folder: $oneDriveUserFolder"
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $oneDriveUserFolder
    } else {
        Write-Host "→ User folder is not empty, skipping deletion: $oneDriveUserFolder" -ForegroundColor Yellow
    }
}

Write-Host "`n[4] Removing OneDrive from Startup..." -ForegroundColor Cyan

# Startup entry for current user
$regPathCU = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$regName = "OneDrive"

if (Test-Path $regPathCU) {
    if (Get-ItemProperty -Path $regPathCU -Name $regName -ErrorAction SilentlyContinue) {
        Remove-ItemProperty -Path $regPathCU -Name $regName
        Write-Host "→ Startup entry in HKCU (User) removed."
    } else {
        Write-Host "→ No startup entry found in HKCU."
    }
}

# Startup entry for all users
$regPathLM = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run"
if (Test-Path $regPathLM) {
    if (Get-ItemProperty -Path $regPathLM -Name $regName -ErrorAction SilentlyContinue) {
        Remove-ItemProperty -Path $regPathLM -Name $regName
        Write-Host "→ Startup entry in HKLM (System) removed."
    } else {
        Write-Host "→ No startup entry found in HKLM."
    }
}

Write-Host "`n[DONE] OneDrive has been processed successfully." -ForegroundColor Green

Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.MessageBox]::Show(
    "OneDrive has been removed. Please restart your computer or Windows Explorer to apply all changes.",
    "Task Completed",
    [System.Windows.Forms.MessageBoxButtons]::OK,
    [System.Windows.Forms.MessageBoxIcon]::Information
)
