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


Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ------------------------------------------------------------
# REGISTRY-EINTRÄGE ANLEGEN
# ------------------------------------------------------------

# Zielpfad
$regBase = "HKLM:\SOFTWARE\Microsoft\PowerShell\1\ShellIds"
$regPath = Join-Path $regBase "Microsoft.PowerShell"

# Falls der Pfad nicht existiert → neu erstellen
if (-not (Test-Path $regPath)) {
    New-Item -Path $regBase -Name "Microsoft.PowerShell" -Force | Out-Null
}

# Werte setzen
New-ItemProperty -Path $regPath -Name "Path" -Value "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -PropertyType String -Force
New-ItemProperty -Path $regPath -Name "ExecutionPolicy" -Value "RemoteSigned" -PropertyType String -Force

# ------------------------------------------------------------
# FORM
# ------------------------------------------------------------
Add-Type -AssemblyName System.Windows.Forms
$form = New-Object System.Windows.Forms.Form
$form.Text = "Debloat Control Panel"
$form.Size = New-Object System.Drawing.Size(410, 500)
$form.BackColor = [System.Drawing.Color]::FromArgb(223,228,176)

# PLATZIERUNG: LINKE BILDSCHIRMHÄLFTE
$screen = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$form.StartPosition = "Manual"

# X = (Bildschirmbreite / 4) - (Fensterbreite / 2) -> Zentriert in der linken Hälfte
# Y = (Bildschirmhöhe / 2) - (Fensterhöhe / 2)    -> Vertikal zentriert
$x = ($screen.Width / 4) - ($form.Width / 2) - 100
$y = ($screen.Height / 2) - ($form.Height / 2)

$form.Location = New-Object System.Drawing.Point($x, $y)

# Ordner des Skripts (immer korrekt)
$scriptDir = $PSScriptRoot

# ------------------------------------------------------------
# STATUS-LABEL
# ------------------------------------------------------------
$labelStatus = New-Object System.Windows.Forms.Label
$labelStatus.Text = "Redy"
$labelStatus.Location = "20,400"
$labelStatus.Size = "350,30"
$labelStatus.Font = "Segoe UI,10,style=Bold"
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

# ------------------------------------------------------------
# UNIVERSAL STARTER
# ------------------------------------------------------------
function Invoke-ExternalTool {
    param(
        [string]$FileName
    )

    if(-not $FileName){
        Update-Status "Leerer Dateiname!",$false
        return
    }

    $path = Join-Path $scriptDir $FileName

    if(-not (Test-Path $path)){
        Update-Status "Nicht gefunden: $FileName",$false
        return
    }

    $ext = [IO.Path]::GetExtension($path).ToLower()

    switch($ext){
        ".ps1" { 
            # Verwenden Sie WScript.Shell für versteckte Ausführung (wie in VBScript)
            $shell = New-Object -ComObject WScript.Shell
            $shell.Run("powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File ""$path""", 0, $false)
        }
        ".bat" { 
            $shell = New-Object -ComObject WScript.Shell
            $shell.Run("""$path""", 0, $false)
        }
        ".reg" { Start-Process reg.exe "import ""$path""" -Verb RunAs }
        default { Start-Process $path }
    }

    Update-Status "$FileName gestartet.",$true
}

# ------------------------------------------------------------
# BUTTON-FACTORY (stabil dank .Tag)
# ------------------------------------------------------------
function New-ActionButton {
    param(
        [string]$Text,
        [int]$Y,
        [string]$ScriptPath,
        [System.Drawing.Color]$Color
    )

    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = $Text
    $btn.Location = "50,$Y"
    $btn.Size = "300,30"
    $btn.BackColor = $Color

    # Pfad direkt im Button speichern
    $btn.Tag = $ScriptPath

    $btn.Add_Click({
        Invoke-ExternalTool -FileName $this.Tag
    })

    $form.Controls.Add($btn)
}

# ------------------------------------------------------------
# BUTTONS
# ------------------------------------------------------------
New-ActionButton -Text "Clean Up System"            -Y 30  -ScriptPath "MasterTool.ps1"                -Color ([System.Drawing.Color]::lightseagreen)
New-ActionButton -Text "Uninstall Programs"         -Y 70  -ScriptPath "Skripte\RemoveApps.ps1"        -Color ([System.Drawing.Color]::Plum)
New-ActionButton -Text "Optimize Edge"              -Y 110 -ScriptPath "Skripte\Optimierung.ps1"       -Color ([System.Drawing.Color]::LightCoral)  
New-ActionButton -Text "Remove Edge"                -Y 150 -ScriptPath "Skripte\RemoveEdge.ps1"        -Color ([System.Drawing.Color]::Orange)
New-ActionButton -Text "Remove OneDrive"            -Y 190 -ScriptPath "Skripte\RemoveOneDrive.ps1"    -Color ([System.Drawing.Color]::LightGreen)
New-ActionButton -Text "Disable Password Expiration"-Y 230 -ScriptPath "Skripte\Passwort.ps1"          -Color ([System.Drawing.Color]::Aquamarine)
New-ActionButton -Text "Pause Updates"              -Y 270 -ScriptPath "Skripte\Update.ps1"            -Color ([System.Drawing.Color]::PeachPuff)
New-ActionButton -Text "Clean Up Startup"           -Y 310 -ScriptPath "Skripte\Autostart.ps1"         -Color ([System.Drawing.Color]::MistyRose)

# ------------------------------------------------------------
# EXIT-BUTTON
# ------------------------------------------------------------
$exit = New-Object System.Windows.Forms.Button
$exit.Text = "Exit"
$exit.Location = "50,370"
$exit.Size = "300,30"
$exit.BackColor = [System.Drawing.Color]::MintCream
$exit.Add_Click({ $form.Close() })
$form.Controls.Add($exit)

# ------------------------------------------------------------
# START
# ------------------------------------------------------------
$form.ShowDialog()