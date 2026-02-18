# Logging.psm1 – Neues Modernes, robustes Logging für RichTextBox
# ------------------------------------------------------------

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ------------------------------------------------------------
# INTERN: Sicherstellen, dass LogBox eine RichTextBox ist
# ------------------------------------------------------------
function Test-WmfEnsureRichTextBox {
    param([object]$LogBox)

    if ($LogBox -isnot [System.Windows.Forms.RichTextBox]) {
        throw "FEHLER: LogBox ist kein RichTextBox! Tatsächlicher Typ: $($LogBox.GetType().FullName)"
    }
}

# ------------------------------------------------------------
# BASIS-LOG (thread-safe, fallback)
# ------------------------------------------------------------
function Write-WmfLog {
    param(
        [Parameter(Mandatory)]
        [string]$Text,

        [Parameter(Mandatory)]
        [object]$LogBox
    )

    if ($LogBox -isnot [System.Windows.Forms.RichTextBox]) {
        try { $LogBox.AppendText("$Text`r`n") } catch { Write-Host $Text }
        return
    }

    $LogBox.Invoke({
        param($Text)
        $this.SelectionStart = $this.TextLength
        $this.SelectionLength = 0
        $this.SelectionColor = [System.Drawing.Color]::Black
        $this.AppendText("$Text`r`n")
        $this.ScrollToCaret()
    }, $Text)
}

# ------------------------------------------------------------
# FARBE: Write-WmfLogColor
# ------------------------------------------------------------
function Write-WmfLogColor {
    param(
        [Parameter(Mandatory)]
        [string]$Text,

        [Parameter(Mandatory)]
        [object]$LogBox,

        [System.Drawing.Color]$Color = [System.Drawing.Color]::Black
    )

    if ($LogBox -isnot [System.Windows.Forms.RichTextBox]) {
        try { $LogBox.AppendText("$Text`r`n") } catch { Write-Host $Text }
        return
    }

    $LogBox.Invoke({
        param($Text, $Color)
        $this.SelectionStart = $this.TextLength
        $this.SelectionLength = 0
        $this.SelectionColor = $Color
        $this.AppendText("$Text`r`n")
        $this.SelectionColor = [System.Drawing.Color]::Black
        $this.ScrollToCaret()
    }, $Text, $Color)
}

# ------------------------------------------------------------
# BOX: Write-WmfLogBox
# ------------------------------------------------------------
function Write-WmfLogBox {
    param(
        [Parameter(Mandatory)]
        [string[]]$Lines,

        [Parameter(Mandatory)]
        [object]$LogBox,

        [System.Drawing.Color]$Color = [System.Drawing.Color]::DodgerBlue
    )

    Test-WmfEnsureRichTextBox -LogBox $LogBox

    $max = ($Lines | Measure-Object -Property Length -Maximum).Maximum
    $top =    "╔" + ("═" * ($max + 2)) + "╗"
    $bottom = "╚" + ("═" * ($max + 2)) + "╝"

    Write-WmfLogColor -Text $top -LogBox $LogBox -Color $Color

    foreach ($line in $Lines) {
        $pad = $line.PadRight($max)
        Write-WmfLogColor -Text ("║ $pad ║") -LogBox $LogBox -Color $Color
    }

    Write-WmfLogColor -Text $bottom -LogBox $LogBox -Color $Color
}

# ------------------------------------------------------------
# STATUS
# ------------------------------------------------------------
function Update-WmfStatus {
    param(
        [Parameter(Mandatory)]
        [System.Windows.Forms.Label]$StatusLabel,

        [Parameter(Mandatory)]
        [string]$Text,

        [bool]$Success = $true,

        [int]$ResetAfterSeconds = 0
    )

    $StatusLabel.Invoke({
        param($Text, $Success)
        $this.Text = $Text
        $this.ForeColor = if ($Success) {
            [System.Drawing.Color]::ForestGreen
        } else {
            [System.Drawing.Color]::Firebrick
        }
    }, $Text, $Success)

    if ($ResetAfterSeconds -gt 0) {
        Start-Sleep -Seconds $ResetAfterSeconds
        $StatusLabel.Invoke({
            $this.Text = "Bereit"
            $this.ForeColor = [System.Drawing.Color]::Black
        })
    }
}

# ------------------------------------------------------------
# Export
# ------------------------------------------------------------
function Export-WmfLog {
    param(
        [Parameter(Mandatory)]
        [string[]]$Lines,

        [string]$FileNamePrefix = "Log",
        [string]$Directory = $([Environment]::GetFolderPath("Desktop"))
    )

    $timestamp = (Get-Date -Format "yyyy-MM-dd_HH-mm")
    $file = Join-Path $Directory "$FileNamePrefix`_$timestamp.txt"

    $Lines -join "`r`n" | Out-File -FilePath $file -Encoding UTF8

    return $file
}

Export-ModuleMember -Function *-Wmf*
