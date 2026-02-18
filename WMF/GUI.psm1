# ------------------------------------------------------------
# GUI.psm1 – GUI-Hilfsfunktionen für Windows Maintenance Tool
# ------------------------------------------------------------

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ------------------------------------------------------------
# Globale Checkbox-Y-Position
# ------------------------------------------------------------
$script:NextCheckboxY = 10

function Reset-WmfPanelCheckboxY {
    param([int]$StartY = 10)
    $script:NextCheckboxY = $StartY
}

# ------------------------------------------------------------
# Form erstellen
# ------------------------------------------------------------
function New-WmfForm {
    param(
        [string]$Title,
        [int]$Width = 800,
        [int]$Height = 600,
        [switch]$CenterScreen
    )

    $form = New-Object System.Windows.Forms.Form
    $form.Text = $Title
    $form.Size = New-Object System.Drawing.Size($Width, $Height)
    $form.StartPosition = if ($CenterScreen) { "CenterScreen" } else { "Manual" }
    return $form
}

# ------------------------------------------------------------
# LogBox
# ------------------------------------------------------------
function New-WmfLogBox {
    param(
        [System.Windows.Forms.Form]$Form,
        [int]$X,
        [int]$Y,
        [int]$Width,
        [int]$Height
    )

    $tb = New-Object System.Windows.Forms.TextBox
    $tb.Multiline = $true
    $tb.ScrollBars = "Vertical"
    $tb.ReadOnly = $true
    $tb.BackColor = "White"
    $tb.Location = New-Object System.Drawing.Point($X, $Y)
    $tb.Size = New-Object System.Drawing.Size($Width, $Height)

    $Form.Controls.Add($tb)
    return $tb
}

# ------------------------------------------------------------
# Status Label
# ------------------------------------------------------------
function New-WmfStatusLabel {
    param(
        [System.Windows.Forms.Form]$Form,
        [int]$X,
        [int]$Y,
        [int]$Width
    )

    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Location = New-Object System.Drawing.Point($X, $Y)
    $lbl.Size = New-Object System.Drawing.Size($Width, 30)
    $lbl.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $lbl.Text = ""
    $Form.Controls.Add($lbl)
    return $lbl
}

# ------------------------------------------------------------
# ScrollPanel (KORRIGIERT!)
# ------------------------------------------------------------
function New-WmfScrollPanel {
    param(
        [System.Windows.Forms.Control]$Parent,   # <-- WICHTIG: Control, nicht Form!
        [int]$X = 20,
        [int]$Y = 20,
        [int]$Width = 540,
        [int]$Height = 260
    )

    $panel = New-Object System.Windows.Forms.Panel
    $panel.Location   = New-Object System.Drawing.Point($X, $Y)
    $panel.Size       = New-Object System.Drawing.Size($Width, $Height)
    $panel.AutoScroll = $true
    $panel.BorderStyle = "FixedSingle"
    $panel.BackColor   = [System.Drawing.Color]::FromArgb(230, 235, 190)

    $Parent.Controls.Add($panel)
    $panel.BringToFront()   # <-- Damit es sichtbar ist

    return $panel
}

# ------------------------------------------------------------
# Checkbox in Panel
# ------------------------------------------------------------
function Add-WmfPanelCheckbox {
    param(
        [System.Windows.Forms.Panel]$Panel,
        [string]$Text,
        [ref]$OutVariable,
        [int]$X = 10,
        [int]$Width = 480,
        [int]$Height = 22
    )

    $cb = New-Object System.Windows.Forms.CheckBox
    $cb.Text     = $Text
    $cb.Location = New-Object System.Drawing.Point($X, $script:NextCheckboxY)
    $cb.Size     = New-Object System.Drawing.Size($Width, $Height)
    $cb.Checked  = $true

    $Panel.Controls.Add($cb)
    $OutVariable.Value = $cb

    $script:NextCheckboxY += ($Height + 8)
}

# ------------------------------------------------------------
# Button Style
# ------------------------------------------------------------
function Set-WmfButtonStyle {
    param(
        [System.Windows.Forms.Button]$Button,
        [System.Drawing.Color]$BackColor
    )

    $Button.BackColor = $BackColor
    $Button.FlatStyle = "Popup"
    $Button.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
}

# ------------------------------------------------------------
# Checkbox Style
# ------------------------------------------------------------
function Set-WmfCheckboxStyle {
    param([System.Windows.Forms.CheckBox]$CheckBox)

    $CheckBox.Font = New-Object System.Drawing.Font("Segoe UI", 10)
}

# ------------------------------------------------------------
# Logging
# ------------------------------------------------------------
function Write-WmfLog {
    param(
        [string]$Text,
        [System.Windows.Forms.TextBox]$LogBox
    )

    $LogBox.AppendText("$Text`r`n")
    $LogBox.ScrollToCaret()
}

# ------------------------------------------------------------
# Status Update
# ------------------------------------------------------------
function Update-WmfStatus {
    param(
        [System.Windows.Forms.Label]$StatusLabel,
        [string]$Text,
        [bool]$Success
    )

    $StatusLabel.Text = $Text
    $StatusLabel.ForeColor = if ($Success) { "Green" } else { "Red" }
}

Export-ModuleMember -Function *-Wmf*
