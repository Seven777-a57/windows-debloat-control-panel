# Registry.psm1
# Gemeinsames Registry-Modul für alle Windows-Maintenance-Tools

# ------------------------------------------------------------
# Registry-Wert setzen (mit automatischer Pfaderstellung)
# ------------------------------------------------------------
function Set-WmfRegistryValue {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        $Value,

        [Parameter(Mandatory)]
        [ValidateSet("String","ExpandString","DWord","QWord","Binary","MultiString")]
        [string]$Type,

        [System.Windows.Forms.TextBox]$LogBox
    )

    try {
        if (-not (Test-Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
        }

        if ($Type -eq "MultiString" -and $Value -is [array]) {
            Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type MultiString
        }
        else {
            Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type
        }

        if ($LogBox) {
            Write-WmfLog -Text "Registry gesetzt: $Path → $Name = $Value" -LogBox $LogBox
        }
    }
    catch {
        if ($LogBox) {
            Write-WmfLog -Text "Fehler beim Setzen von ${Path}\${Name}: $($_.Exception.Message)" -LogBox $LogBox
        }
    }
}

# ------------------------------------------------------------
# Registry-Werte eines Schlüssels löschen (rekursiv)
# ------------------------------------------------------------
function Clear-WmfRegistryKeyValues {
    param(
        [Parameter(Mandatory)]
        [string]$RegistryPath,

        [System.Windows.Forms.TextBox]$LogBox
    )

    try {
        if ($LogBox) { Write-WmfLog -Text "Bereinige Registry: $RegistryPath" -LogBox $LogBox }

        # HKCU\Software\... → HKCU:\Software\...
        $formatted = $RegistryPath -replace '^([^\\]+)', '$1:'

        if (-not (Test-Path $formatted)) {
            if ($LogBox) { Write-WmfLog -Text "→ Schlüssel nicht gefunden." -LogBox $LogBox }
            return
        }

        # Werte löschen
        $values = (Get-Item $formatted).Property
        foreach ($v in $values) {
            Remove-ItemProperty -Path $formatted -Name $v -ErrorAction SilentlyContinue
            if ($LogBox) { Write-WmfLog -Text "→ Wert gelöscht: $v" -LogBox $LogBox }
        }

        # Unterordner rekursiv
        $subKeys = Get-ChildItem $formatted -ErrorAction SilentlyContinue
        foreach ($sub in $subKeys) {
            Clear-WmfRegistryKeyValues -RegistryPath "$RegistryPath\$($sub.PSChildName)" -LogBox $LogBox
        }
    }
    catch {
        if ($LogBox) { Write-WmfLog -Text "Fehler: $_" -LogBox $LogBox }
    }
}

# ------------------------------------------------------------
# Registry-Baum komplett löschen
# ------------------------------------------------------------
function Remove-WmfRegistryTree {
    param(
        [Parameter(Mandatory)]
        [string]$RegistryPath,

        [System.Windows.Forms.TextBox]$LogBox
    )

    try {
        $formatted = $RegistryPath -replace '^([^\\]+)', '$1:'

        if (-not (Test-Path $formatted)) {
            if ($LogBox) { Write-WmfLog -Text "→ Schlüssel nicht vorhanden: $RegistryPath" -LogBox $LogBox }
            return
        }

        Remove-Item -Path $formatted -Recurse -Force -ErrorAction Stop

        if ($LogBox) { Write-WmfLog -Text "Registry-Baum gelöscht: $RegistryPath" -LogBox $LogBox }
    }
    catch {
        if ($LogBox) { Write-WmfLog -Text "Fehler beim Löschen von ${RegistryPath}: $_" -LogBox $LogBox }
    }
}

Export-ModuleMember -Function *-Wmf*
