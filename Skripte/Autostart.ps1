
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- Check Admin Rights and Restart Script if necessary ---
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {

    # Restart script with Administrator privileges
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell.exe"
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`""
    $psi.Verb = "runas"
    [System.Diagnostics.Process]::Start($psi) | Out-Null
    exit
}
# --- End Admin Block ---

# Helper function for list entries (Display + Data)
function New-Entry($display, $data) {
    $obj = New-Object PSObject -Property @{
        Display = $display
        Data    = $data
    }
    $obj | Add-Member -MemberType ScriptMethod -Name ToString -Value { $this.Display } -Force
    return $obj
}

# Main Window
$form = New-Object System.Windows.Forms.Form
$form.Text = "Autostart Overview"
$form.Size = New-Object System.Drawing.Size(600,450)
$form.StartPosition = "CenterScreen"
$form.BackColor = [System.Drawing.Color]::FromArgb(223,228,176)

# TabControl
$tabs = New-Object System.Windows.Forms.TabControl
$tabs.Dock = "Top"
$tabs.Height = 280   # smaller to leave space for labels + buttons
$tabs.BackColor = [System.Drawing.Color]::FromArgb(240,240,220)
$form.Controls.Add($tabs)

function New-CheckedListBox {
    $clb = New-Object System.Windows.Forms.CheckedListBox
    $clb.Dock = "Fill"
    $clb.BackColor = [System.Drawing.Color]::FromArgb(250,250,235)
    $clb.ForeColor = [System.Drawing.Color]::DarkBlue
    $clb.Font = New-Object System.Drawing.Font("Segoe UI",10)
    $clb.CheckOnClick = $true
    return $clb
}

# Tabs + Lists
$tabReg = New-Object System.Windows.Forms.TabPage
$tabReg.Text = "Registry"
$tabReg.BackColor = [System.Drawing.Color]::FromArgb(240,245,200)
$listReg = New-CheckedListBox
$tabReg.Controls.Add($listReg)

$tabFolder = New-Object System.Windows.Forms.TabPage
$tabFolder.Text = "Startup Folder"
$tabFolder.BackColor = [System.Drawing.Color]::FromArgb(220,235,250)
$listFolder = New-CheckedListBox
$tabFolder.Controls.Add($listFolder)

$tabTasks = New-Object System.Windows.Forms.TabPage
$tabTasks.Text = "Scheduled Tasks"
$tabTasks.BackColor = [System.Drawing.Color]::FromArgb(230,250,220)
$listTasks = New-CheckedListBox
$tabTasks.Controls.Add($listTasks)

$tabs.Controls.AddRange(@($tabReg,$tabFolder,$tabTasks))

# Status Label
$labelStatus = New-Object System.Windows.Forms.Label
$labelStatus.Text = "Ready"
$labelStatus.Dock = "Bottom"
$labelStatus.Height = 30
$labelStatus.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$labelStatus.TextAlign = "MiddleCenter"
$form.Controls.Add($labelStatus)

function Update-Status($text, $success = $true) {
    $labelStatus.Text = $text
    $labelStatus.ForeColor = if ($success) {
        [System.Drawing.Color]::ForestGreen
    } else {
        [System.Drawing.Color]::Firebrick
    }
    $form.Refresh()
    Start-Sleep -Seconds 1
    $labelStatus.Text = "Ready"
    $labelStatus.ForeColor = [System.Drawing.Color]::Black
    $form.Refresh()
}

# Button Styling
function Style-Button($btn, $bgColor) {
    $btn.BackColor = $bgColor
    $btn.ForeColor = [System.Drawing.Color]::Black
    $btn.FlatStyle = 'Flat'
    $btn.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Regular)
}

# Button Panel
$panelButtons = New-Object System.Windows.Forms.Panel
$panelButtons.Dock = "Bottom"
$panelButtons.Height = 50
$panelButtons.BackColor = [System.Drawing.Color]::FromArgb(210,210,180)
$form.Controls.Add($panelButtons)

$btnDelete = New-Object System.Windows.Forms.Button
$btnDelete.Text = "Delete Selected"
$btnDelete.Width = 120
$btnDelete.Location = New-Object System.Drawing.Point(180,10)
Style-Button $btnDelete ([System.Drawing.Color]::LightSalmon)

$btnExit = New-Object System.Windows.Forms.Button
$btnExit.Text = "Exit"
$btnExit.Width = 100
$btnExit.Location = New-Object System.Drawing.Point(310,10)
Style-Button $btnExit ([System.Drawing.Color]::LightGreen)

$panelButtons.Controls.Add($btnDelete)
$panelButtons.Controls.Add($btnExit)

# --- Populating Data ---
$regPaths = @(
    "HKU:\DEFAULT\Software\Microsoft\Windows\CurrentVersion\Run",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce",
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run",
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce"
)
foreach ($path in $regPaths) {
    if (Test-Path $path) {
        $props = Get-ItemProperty $path
        $props.PSObject.Properties | Where-Object {
            $_.Name -notmatch "PS(Path|ParentPath|ChildName|Drive|Provider)"
        } | ForEach-Object {
            $shortPath = ($path -replace "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\","HKCU\\") `
                         -replace "HKLM:\\Software\\Microsoft\\Windows\\CurrentVersion\\","HKLM\\"
            $display = "$shortPath – $($_.Name)"
            $data    = "$path|$($_.Name)"
            $listReg.Items.Add((New-Entry $display $data))
        }
    }
}


# Startup Folders
$startupPaths = @(
    "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup",
    "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup"
)
foreach ($folder in $startupPaths) {
    if (Test-Path $folder) {
        Get-ChildItem $folder | ForEach-Object {
            $display = $_.Name
            $data    = $_.FullName
            $listFolder.Items.Add((New-Entry $display $data))
        }
    }
}

# Scheduled Tasks
try {
    $tasks = Get-ScheduledTask | Where-Object {
        $_.Triggers | Where-Object { $_.TriggerType -eq "Logon" }
    }
    foreach ($task in $tasks) {
        $display = $task.TaskName
        $data    = $task.TaskName
        $listTasks.Items.Add((New-Entry $display $data))
    }
} catch {
    $listTasks.Items.Add("Error reading scheduled tasks")
}

# --- Button Actions ---
$btnDelete.Add_Click({
    $tab = $tabs.SelectedTab
    $list = $tab.Controls[0]
    $checkedItems = $list.CheckedItems
    if ($checkedItems.Count -eq 0) { 
        [System.Windows.Forms.MessageBox]::Show("Please select at least one entry.") 
        return 
    }

    $result = [System.Windows.Forms.MessageBox]::Show(
        "Are you sure you want to delete the selected entries?",
        "Confirmation",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    )

    if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
        # Create a copy of the items to avoid collection modification errors during removal
        $itemsToRemove = @()
        foreach ($sel in $checkedItems) { $itemsToRemove += $sel }

        foreach ($sel in $itemsToRemove) {
            $data = $sel.Data
            switch ($tab.Text) {
                "Registry" {
                    $parts = $data -split "\|"
                    if ($parts.Count -ge 2) {
                        $path = $parts[0]; $name = $parts[1]
                        Remove-ItemProperty -Path $path -Name $name -ErrorAction SilentlyContinue
                        $list.Items.Remove($sel)
                    }
                }
                "Startup Folder" {
                    if (Test-Path $data) {
                        Remove-Item $data -Force -ErrorAction SilentlyContinue
                        $list.Items.Remove($sel)
                    }
                }
                "Scheduled Tasks" {
                    try {
                        Unregister-ScheduledTask -TaskName $data -Confirm:$false -ErrorAction SilentlyContinue
                        $list.Items.Remove($sel)
                    } catch {}
                }
            }
        }
        Update-Status "Selected entries have been deleted."
    }
})

$btnExit.Add_Click({ $form.Close() })

# Start GUI
[void]$form.ShowDialog()
