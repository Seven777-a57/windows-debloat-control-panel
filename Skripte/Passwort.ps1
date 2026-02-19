 Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Create Main Window
$form = New-Object System.Windows.Forms.Form
$form.Text = "Stop Password Prompts"
$form.Size = New-Object System.Drawing.Size(580, 400)
$form.StartPosition = "Manual"

# Background color
$form.BackColor = [System.Drawing.Color]::FromArgb(223,228,176)

# Determine screen size
$screenWidth = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea.Width
$screenHeight = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea.Height

$formWidth = $form.Size.Width
$formHeight = $form.Size.Height

$centerX = [Math]::Max(0, ($screenWidth - $formWidth) / 2)
$centerY = [Math]::Max(0, ($screenHeight - $formHeight) / 2)
$form.Location = New-Object System.Drawing.Point($centerX, $centerY)

# Labels
$label1 = New-Object System.Windows.Forms.Label
$label1.Text = "Windows Login Prompt"
$label1.Location = New-Object System.Drawing.Point(40, 40)
$label1.Size = New-Object System.Drawing.Size(460, 40)
$label1.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$label1.ForeColor = [System.Drawing.Color]::DarkGreen
$label1.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$form.Controls.Add($label1)

$label2 = New-Object System.Windows.Forms.Label
$label2.Text = "Change Password"
$label2.Location = New-Object System.Drawing.Point(40, 80)
$label2.Size = New-Object System.Drawing.Size(460, 40)
$label2.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$label2.ForeColor = [System.Drawing.Color]::DarkGreen
$label2.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$form.Controls.Add($label2)

$label3 = New-Object System.Windows.Forms.Label
$label3.Text = "Deactivate"
$label3.Location = New-Object System.Drawing.Point(40, 120)
$label3.Size = New-Object System.Drawing.Size(460, 40)
$label3.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$label3.ForeColor = [System.Drawing.Color]::Firebrick
$label3.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$form.Controls.Add($label3)

# Status Display
$labelStatus = New-Object System.Windows.Forms.Label
$labelStatus.Text = "Ready"
$labelStatus.Location = New-Object System.Drawing.Point(20, 320)
$labelStatus.Size = New-Object System.Drawing.Size(500, 30)
$labelStatus.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$labelStatus.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$form.Controls.Add($labelStatus)

# Exit Button
$btnExit = New-Object System.Windows.Forms.Button
$btnExit.Text = "Exit"
$btnExit.Location = New-Object System.Drawing.Point(220, 220)
$btnExit.Size = New-Object System.Drawing.Size(100, 30)
$btnExit.Visible = $false
$btnExit.BackColor = [System.Drawing.Color]::LightGray
$btnExit.ForeColor = [System.Drawing.Color]::DarkBlue
$btnExit.Add_Click({ $form.Close() })
$form.Controls.Add($btnExit)

function UpdateStatus($text) {
    $labelStatus.Text = $text
    $form.Refresh()
    $btnExit.Visible = $true
    Start-Sleep -Seconds 4
    $labelStatus.Text = "Ready"
    $form.Refresh()
}

# Button: Disable Password Expiration
$btnPasswortablauf = New-Object System.Windows.Forms.Button
$btnPasswortablauf.Text = "Disable Password Expiration"
$btnPasswortablauf.Location = New-Object System.Drawing.Point(170, 180)
$btnPasswortablauf.Size = New-Object System.Drawing.Size(200, 30)
$btnPasswortablauf.BackColor = [System.Drawing.Color]::LightSteelBlue
$btnPasswortablauf.ForeColor = [System.Drawing.Color]::Black
$btnPasswortablauf.Add_Click({
    $currentUser = $env:USERNAME
    try {
        $user = Get-LocalUser -Name $currentUser
        if ($user.Enabled -and -not $user.PasswordNeverExpires) {
            Set-LocalUser -Name $currentUser -PasswordNeverExpires $true
            $labelStatus.Text = "Password expiration for '$currentUser' has been disabled."
            $form.Refresh()
            
            # Show MessageBox
            [System.Windows.Forms.MessageBox]::Show(
                "The prompt to change your password has been removed.",
                "Done!",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            )
            
            # Make Exit Button visible AFTER MessageBox
            $btnExit.Visible = $true
            Start-Sleep -Seconds 1
            $labelStatus.Text = "Ready"
            $form.Refresh()
        } else {
            $labelStatus.Text = "Password expiration is already disabled or user is inactive."
            $form.Refresh()
            $btnExit.Visible = $true
        }
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Error while disabling password expiration.`n$_", "Error", "OK", "Error")
    }
})

$form.Controls.Add($btnPasswortablauf)

# Show Window
$form.Topmost = $false
$form.Show()
[System.Windows.Forms.Application]::Run($form)
