# =====================================================================
# WMF Cleanup Module – KOMPLETT & FINAL
# Alle Clear-Wmf* Funktionen + neue System-Cleanup-Engine
# =====================================================================

# ------------------------------------------------------------
# Ordnergröße berechnen
# ------------------------------------------------------------
function Get-WmfFolderSize {
    param([string]$Path)

    if (Test-Path $Path) {
        return (Get-ChildItem -Path $Path -Recurse -ErrorAction SilentlyContinue |
                Measure-Object -Property Length -Sum).Sum
    }
    return 0
}

# ------------------------------------------------------------
# Freien Speicherplatz von C: ermitteln
# ------------------------------------------------------------
function Get-WmfDriveFreeSpace {
    (Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'").FreeSpace
}

# ------------------------------------------------------------
# Ordnerinhalt löschen (mit RtBackup-Schutz, falls LogFiles)
# ------------------------------------------------------------
function Clear-WmfFolder {
    param(
        [string]$Path,
        [System.Windows.Forms.TextBox]$LogBox
    )

    Write-WmfLog -Text "Bereinige Ordner: $Path" -LogBox $LogBox

    if (-not (Test-Path $Path)) {
        Write-WmfLog -Text "→ Ordner nicht vorhanden." -LogBox $LogBox
        return
    }

    try {
        if ($Path -like "C:\Windows\System32\LogFiles*") {
            # RtBackup ausschließen
            Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue |
                Where-Object { $_.FullName -notlike "*\RtBackup*" } |
                Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
        }
        else {
            Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue |
                Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
        }

        Write-WmfLog -Text "→ Ordnerinhalt gelöscht." -LogBox $LogBox
    }
    catch {
        Write-WmfLog -Text "Fehler: $_" -LogBox $LogBox
    }
}

# ------------------------------------------------------------
# Quick Access leeren
# ------------------------------------------------------------
function Clear-WmfQuickAccess {
    param([System.Windows.Forms.TextBox]$LogBox)

    Write-WmfLog -Text "Leere Quick Access..." -LogBox $LogBox

    Remove-Item "$env:APPDATA\Microsoft\Windows\Recent\AutomaticDestinations\*" -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:APPDATA\Microsoft\Windows\Recent\CustomDestinations\*"    -Force -ErrorAction SilentlyContinue

    Write-WmfLog -Text "→ Quick Access geleert." -LogBox $LogBox
}

# ------------------------------------------------------------
# Papierkorb leeren
# ------------------------------------------------------------
function Clear-WmfRecycleBin {
    param([System.Windows.Forms.TextBox]$LogBox)

    try {
        Clear-RecycleBin -Force -ErrorAction SilentlyContinue
        Write-WmfLog -Text "→ Papierkorb geleert." -LogBox $LogBox
    }
    catch {
        Write-WmfLog -Text "Fehler beim Leeren des Papierkorbs: $_" -LogBox $LogBox
    }
}

# ------------------------------------------------------------
# Browser-Caches löschen
# ------------------------------------------------------------
function Clear-WmfBrowserCaches {
    param([System.Windows.Forms.TextBox]$LogBox)

    Write-WmfLog -Text "Bereinige Browser-Caches..." -LogBox $LogBox

    Clear-WmfFolder "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache" -LogBox $LogBox
    Clear-WmfFolder "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache"  -LogBox $LogBox
    Clear-WmfFolder "$env:APPDATA\Mozilla\Firefox\Profiles"                    -LogBox $LogBox
}

# ------------------------------------------------------------
# Temp-Ordner löschen
# ------------------------------------------------------------
function Clear-WmfTemp {
    param([System.Windows.Forms.TextBox]$LogBox)
    Clear-WmfFolder $env:TEMP -LogBox $LogBox
}

# ------------------------------------------------------------
# Prefetch löschen
# ------------------------------------------------------------
function Clear-WmfPrefetch {
    param([System.Windows.Forms.TextBox]$LogBox)
    Clear-WmfFolder "C:\Windows\Prefetch" -LogBox $LogBox
}

# ------------------------------------------------------------
# Windows Update Cache löschen
# ------------------------------------------------------------
function Clear-WmfWindowsUpdateCache {
    param([System.Windows.Forms.TextBox]$LogBox)
    Clear-WmfFolder "C:\Windows\SoftwareDistribution\Download" -LogBox $LogBox
}

# ------------------------------------------------------------
# Windows LogFiles löschen (nutzt Clear-WmfFolder mit RtBackup-Schutz)
# ------------------------------------------------------------
function Clear-WmfLogFiles {
    param([System.Windows.Forms.TextBox]$LogBox)
    Clear-WmfFolder "C:\Windows\System32\LogFiles" -LogBox $LogBox
}

# ------------------------------------------------------------
# Minidumps löschen
# ------------------------------------------------------------
function Clear-WmfMinidumps {
    param([System.Windows.Forms.TextBox]$LogBox)
    Clear-WmfFolder "C:\Windows\Minidump" -LogBox $LogBox
}

# ------------------------------------------------------------
# MEMORY.DMP löschen
# ------------------------------------------------------------
function Clear-WmfMemoryDump {
    param([System.Windows.Forms.TextBox]$LogBox)

    if (Test-Path "C:\Windows\MEMORY.DMP") {
        try {
            Remove-Item "C:\Windows\MEMORY.DMP" -Force -ErrorAction SilentlyContinue
            Write-WmfLog -Text "→ MEMORY.DMP gelöscht." -LogBox $LogBox
        }
        catch {
            Write-WmfLog -Text "Fehler beim Löschen von MEMORY.DMP: $_" -LogBox $LogBox
        }
    }
    else {
        Write-WmfLog -Text "→ MEMORY.DMP nicht gefunden." -LogBox $LogBox
    }
}

# ------------------------------------------------------------
# WinSxS / DISM Component Cleanup (Konsole; GUI-Version hast du im Hauptskript)
# ------------------------------------------------------------
function Start-WmfDismComponentCleanup {
    param([System.Windows.Forms.TextBox]$LogBox)

    Write-WmfLog -Text "Starte DISM Component Cleanup..." -LogBox $LogBox

    try {
        Start-Process -FilePath "dism.exe" -ArgumentList "/Online /Cleanup-Image /StartComponentCleanup" -Wait -NoNewWindow
        Write-WmfLog -Text "→ DISM Component Cleanup abgeschlossen." -LogBox $LogBox
    }
    catch {
        Write-WmfLog -Text "Fehler bei DISM: $_" -LogBox $LogBox
    }
}

# ------------------------------------------------------------
# Thumbnail-Cache löschen
# ------------------------------------------------------------
function Clear-WmfThumbnails {
    param([System.Windows.Forms.TextBox]$LogBox)

    Write-WmfLog -Text "Lösche Thumbnail-Cache..." -LogBox $LogBox

    $paths = @(
        "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*",
        "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\iconcache_*"
    )

    foreach ($p in $paths) {
        Remove-Item $p -Force -ErrorAction SilentlyContinue
    }

    Write-WmfLog -Text "→ Thumbnail-Cache gelöscht." -LogBox $LogBox
}

# ------------------------------------------------------------
# D3D Shader Cache löschen
# ------------------------------------------------------------
function Clear-WmfD3DShaderCache {
    param([System.Windows.Forms.TextBox]$LogBox)

    Write-WmfLog -Text "Lösche D3D Shader Cache..." -LogBox $LogBox

    Clear-WmfFolder "C:\Users\$env:USERNAME\AppData\Local\D3DSCache" -LogBox $LogBox
}

# ------------------------------------------------------------
# Delivery Optimization Cache löschen
# ------------------------------------------------------------
function Clear-WmfDeliveryOptimization {
    param([System.Windows.Forms.TextBox]$LogBox)

    Write-WmfLog -Text "Lösche Delivery Optimization Cache..." -LogBox $LogBox

    Clear-WmfFolder "C:\ProgramData\Microsoft\Windows\DeliveryOptimization" -LogBox $LogBox
}

# ------------------------------------------------------------
# BranchCache löschen
# ------------------------------------------------------------
function Clear-WmfBranchCache {
    param([System.Windows.Forms.TextBox]$LogBox)

    Write-WmfLog -Text "Lösche BranchCache..." -LogBox $LogBox

    Clear-WmfFolder "C:\Windows\ServiceProfiles\NetworkService\AppData\Local\PeerDistRepub" -LogBox $LogBox
}

# ------------------------------------------------------------
# Windows Error Reporting Dateien löschen
# ------------------------------------------------------------
function Clear-WmfWERFiles {
    param([System.Windows.Forms.TextBox]$LogBox)

    Write-WmfLog -Text "Lösche Windows Error Reporting Dateien..." -LogBox $LogBox

    Clear-WmfFolder "C:\ProgramData\Microsoft\Windows\WER\ReportQueue"   -LogBox $LogBox
    Clear-WmfFolder "C:\ProgramData\Microsoft\Windows\WER\ReportArchive" -LogBox $LogBox
}

# ------------------------------------------------------------
# Windows Error Reporting Memory Dumps löschen
# ------------------------------------------------------------
function Clear-WmfWERMemoryDumps {
    param([System.Windows.Forms.TextBox]$LogBox)

    Write-WmfLog -Text "Lösche WER Memory Dumps..." -LogBox $LogBox

    Clear-WmfFolder "C:\ProgramData\Microsoft\Windows\WER\Temp" -LogBox $LogBox
}

# ------------------------------------------------------------
# Windows Error Reporting Minidumps löschen
# ------------------------------------------------------------
function Clear-WmfWERMinidumps {
    param([System.Windows.Forms.TextBox]$LogBox)

    Write-WmfLog -Text "Lösche WER Minidumps..." -LogBox $LogBox

    Clear-WmfFolder "C:\ProgramData\Microsoft\Windows\WER\ReportQueue" -LogBox $LogBox
}

# ------------------------------------------------------------
# Setup-Dateien löschen
# ------------------------------------------------------------
function Clear-WmfSetupFiles {
    param([System.Windows.Forms.TextBox]$LogBox)

    Write-WmfLog -Text "Lösche Setup-Dateien..." -LogBox $LogBox

    Clear-WmfFolder "C:\Windows\Panther"  -LogBox $LogBox
    Clear-WmfFolder "C:\$WINDOWS.~BT"     -LogBox $LogBox
    Clear-WmfFolder "C:\$WINDOWS.~LS"     -LogBox $LogBox
    Clear-WmfFolder "C:\$WINDOWS.~WS"     -LogBox $LogBox
}

# ------------------------------------------------------------
# Hardlink-Backup löschen
# ------------------------------------------------------------
function Clear-WmfHardLinkBackup {
    param([System.Windows.Forms.TextBox]$LogBox)

    Write-WmfLog -Text "Lösche Hardlink-Backup Dateien..." -LogBox $LogBox

    Clear-WmfFolder "C:\Windows\WinSxS\Backup" -LogBox $LogBox
}

# ------------------------------------------------------------
# Sichere Dienstverwaltung für System-Cleanup
# ------------------------------------------------------------
$global:WmfServiceStates = @{}

function Stop-WmfServices {
    param([string[]]$Services)

    foreach ($svc in $Services) {
        $s = Get-Service $svc -ErrorAction SilentlyContinue
        if ($s) {
            $global:WmfServiceStates[$svc] = $s.Status
            if ($s.Status -eq 'Running') {
                Stop-Service $svc -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

function Restore-WmfServices {
    foreach ($svc in $global:WmfServiceStates.Keys) {
        if ($global:WmfServiceStates[$svc] -eq 'Running') {
            Start-Service $svc -ErrorAction SilentlyContinue
        }
    }
}

# ------------------------------------------------------------
# Sicheres Löschen von Systemordnern (mit RtBackup-Ausschluss)
# ------------------------------------------------------------
function Remove-WmfSystemFolder {
    param(
        [string]$Path,
        [System.Windows.Forms.TextBox]$LogBox
    )

    try {
        if (Test-Path $Path) {

            # Inhalte löschen, RtBackup ausschließen
            Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue |
                Where-Object { $_.FullName -notlike "*\RtBackup*" } |
                Remove-Item -Force -Recurse -ErrorAction SilentlyContinue

            # Ordner selbst löschen (falls möglich)
            Remove-Item -Path $Path -Force -Recurse -ErrorAction SilentlyContinue

            Write-WmfLog ("Gelöscht: {0}" -f $Path) $LogBox
        }
        else {
            Write-WmfLog ("Nicht gefunden: {0}" -f $Path) $LogBox
        }
    }
    catch {
        Write-WmfLog ("Fehler beim Löschen von {0}: {1}" -f $Path, $_) $LogBox
    }
}

# ------------------------------------------------------------
# Zentrale System-Cleanup Engine (ersetzt alten Block in TAB 1)
# ------------------------------------------------------------
function Invoke-WmfSystemCleanup {
    param([System.Windows.Forms.TextBox]$LogBox)

    Write-WmfLog -Text "Starte System-Cleanup (Systemordner)..." -LogBox $LogBox

    $services = @("wuauserv", "bits", "dosvc")

    $paths = @(
        "C:\WinPEpge.sys",
        "C:\$WINDOWS.~BT",
        "C:\$WINDOWS.~LS",
        "C:\$WINDOWS.~WS",
        "C:\Windows\Panther"
    )

    Stop-WmfServices -Services $services

    foreach ($p in $paths) {
        Remove-WmfSystemFolder -Path $p -LogBox $LogBox
    }

    Restore-WmfServices

    Write-WmfLog -Text "System-Cleanup abgeschlossen." -LogBox $LogBox
}

# ------------------------------------------------------------
# Reservierten Speicher löschen (aus TAB 1 ausgelagert)
# ------------------------------------------------------------
function Clear-WmfReservedStorage {
    param([System.Windows.Forms.TextBox]$LogBox)

    Write-WmfLog "Reservierter Speicher wird deaktiviert…" $LogBox

    $basePath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\ReserveManager"

    New-Item -Path "$basePath\PendingAdjustments" -Force | Out-Null
    New-Item -Path "$basePath\OneSettings"         -Force | Out-Null

    $values = @{
        "BaseHardReserveSize"       = ([byte[]](0,0,0,0,0,0,0,0))
        "BaseSoftReserveSize"       = ([byte[]](0,0,0,0,0,0,0,0))
        "MinDiskSize"               = ([byte[]](0,0,0,0,0,0,0,0))
        "HardReserveAdjustment"     = ([byte[]](0x00,0x70,0x03,0x00,0x00,0x00,0x00,0x00))
        "ShippedWithReserves"       = 0
        "PassedPolicy"              = 0
        "SoftParentingValidated"    = 1
        "TiAttemptedInitialization" = 0
        "ActiveScenario"            = 0
        "DisableDeletes"            = 1
        "MiscPolicyInfo"            = 2
    }

    foreach ($key in $values.Keys) {
        Set-ItemProperty -Path $basePath -Name $key -Value $values[$key] -Force
    }

    Set-ItemProperty -Path "$basePath\OneSettings" -Name "DisableDeletes" -Value 1 -Force

    New-Item -Path "$basePath\PendingAdjustments" -Force | Out-Null

    Write-WmfLog "Registry für Reservierten Speicher wurde angepasst." $LogBox

    # Ordner bereinigen
    $paths = @(
        "C:\Windows\Temp",
        "C:\Windows\SoftwareDistribution\Download",
        "C:\Windows\SoftwareDistribution\DataStore",
        "C:\ProgramData\Microsoft\Windows\DeliveryOptimization",
        "C:\Windows\Logs",
        "C:\Windows\WinSxS\Temp"
    )

    foreach ($p in $paths) {
        Remove-WmfSystemFolder -Path $p -LogBox $LogBox
    }

    Write-WmfLog "Reservierter Speicher wurde deaktiviert und bereinigt. Neustart erforderlich." $LogBox
}

# ------------------------------------------------------------
# Export
# ------------------------------------------------------------
Export-ModuleMember -Function *-Wmf*
# =====================================================================
# ENDE Cleanup.psm1
# =====================================================================
