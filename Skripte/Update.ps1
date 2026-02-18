Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ------------------------------------------------------------
# FORM
# ------------------------------------------------------------
$form = New-Object System.Windows.Forms.Form
$form.Text = "Windows Update Pause"
$form.Size = New-Object System.Drawing.Size(410, 300)
$form.BackColor = [System.Drawing.Color]::FromArgb(223,228,176)
$form.StartPosition = "CenterScreen"

# ------------------------------------------------------------
# STATUS LABEL
# ------------------------------------------------------------
$labelStatus = New-Object System.Windows.Forms.Label
$labelStatus.Text = "Ready"
$labelStatus.Location = "20,220"
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
# REGISTRY PATH
# ------------------------------------------------------------
$RegPath = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"

# ------------------------------------------------------------
# FUNCTION: SET PAUSE
# ------------------------------------------------------------
function Set-WindowsUpdatePause {
    param([string]$Duration)

    $Start = (Get-Date).ToUniversalTime()

    switch ($Duration) {
        "4 Weeks"   { $End = $Start.AddDays(28) }
        "6 Months"  { $End = $Start.AddMonths(6) }
        "1 Year"    { $End = $Start.AddYears(1) }
        "100 Years" { $End = $Start.AddYears(100) }
    }

    $StartISO = $Start.ToString("yyyy-MM-ddTHH:mm:ssZ")
    $EndISO   = $End.ToString("yyyy-MM-ddTHH:mm:ssZ")

    if (-not (Test-Path $RegPath)) {
        New-Item -Path $RegPath -Force | Out-Null
    }

    Set-ItemProperty -Path $RegPath -Name "ExcludeWUDriversInQualityUpdate" -Value 1 -Type DWord
    Set-ItemProperty -Path $RegPath -Name "PauseFeatureUpdatesStartTime" -Value $StartISO -Type String
    Set-ItemProperty -Path $RegPath -Name "PauseFeatureUpdatesEndTime"   -Value $EndISO   -Type String
    Set-ItemProperty -Path $RegPath -Name "PauseQualityUpdatesStartTime" -Value $StartISO -Type String
    Set-ItemProperty -Path $RegPath -Name "PauseQualityUpdatesEndTime"   -Value $EndISO   -Type String
    Set-ItemProperty -Path $RegPath -Name "PauseUpdatesStartTime"        -Value $StartISO -Type String
    Set-ItemProperty -Path $RegPath -Name "PauseUpdatesExpiryTime"       -Value $EndISO   -Type String
    Set-ItemProperty -Path $RegPath -Name "TrayIconVisibility"           -Value 0 -Type DWord

    Update-Status "Updates paused until $EndISO" $true
}

# ------------------------------------------------------------
# FUNCTION: REMOVE PAUSE
# ------------------------------------------------------------
function Remove-WindowsUpdatePause {

    if (Test-Path $RegPath) {
        "PauseFeatureUpdatesStartTime","PauseFeatureUpdatesEndTime",
        "PauseQualityUpdatesStartTime","PauseQualityUpdatesEndTime",
        "PauseUpdatesStartTime","PauseUpdatesExpiryTime" |
        ForEach-Object {
            Remove-ItemProperty -Path $RegPath -Name $_ -ErrorAction SilentlyContinue
        }
    }

    Update-Status "Update pause removed." $true
}

# ------------------------------------------------------------
# LABEL
# ------------------------------------------------------------
$label = New-Object System.Windows.Forms.Label
$label.Text = "     Select Duration:"
$label.Location = "110,40"
$label.Size = "300,20"
$label.Font = "Segoe UI,10,style=Bold"
$form.Controls.Add($label)

# ------------------------------------------------------------
# DROPDOWN
# ------------------------------------------------------------
$combo = New-Object System.Windows.Forms.ComboBox
$combo.Location = "50,60"
$combo.Size = "300,30"
$combo.Font = "Segoe UI,10"
$combo.DropDownStyle = "DropDownList"
$combo.Items.AddRange(@("4 Weeks","6 Months","1 Year","100 Years"))
# Dies setzt den Standardwert auf den ersten Eintrag (4 Weeks):
$combo.SelectedIndex = 0 
$form.Controls.Add($combo)


# ------------------------------------------------------------
# BUTTON: ENABLE PAUSE
# ------------------------------------------------------------
$btnApply = New-Object System.Windows.Forms.Button
$btnApply.Text = "Enable Pause"
$btnApply.Location = "50,110"
$btnApply.Size = "300,30"
$btnApply.BackColor = [System.Drawing.Color]::LightCoral
$btnApply.Add_Click({
    if ($combo.SelectedItem) {
        Set-WindowsUpdatePause -Duration $combo.SelectedItem
    } else {
        Update-Status "Please select a duration!" $false
    }
})
$form.Controls.Add($btnApply)

# ------------------------------------------------------------
# BUTTON: REMOVE PAUSE
# ------------------------------------------------------------
$btnRemove = New-Object System.Windows.Forms.Button
$btnRemove.Text = "Remove Pause"
$btnRemove.Location = "50,150"
$btnRemove.Size = "300,30"
$btnRemove.BackColor = [System.Drawing.Color]::MistyRose
$btnRemove.Add_Click({
    Remove-WindowsUpdatePause
})
$form.Controls.Add($btnRemove)

# ------------------------------------------------------------
# EXIT
# ------------------------------------------------------------
$exit = New-Object System.Windows.Forms.Button
$exit.Text = "Exit"
$exit.Location = "50,190"
$exit.Size = "300,30"
$exit.BackColor = [System.Drawing.Color]::MintCream
$exit.Add_Click({ $form.Close() })
$form.Controls.Add($exit)

# ------------------------------------------------------------
# START
# ------------------------------------------------------------
$form.ShowDialog()

