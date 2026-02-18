Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- Check admin privileges and restart script if necessary ---
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {

    # Restart script with administrative privileges
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell.exe"
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`""
    $psi.Verb = "runas"
    [System.Diagnostics.Process]::Start($psi) | Out-Null
    exit
}
# --- End Admin Block ---


# Define log file path
$logPath = "$env:USERPROFILE\Desktop\RemoveApps.log"

# --- Helper Functions ---
function Remove-AppxAndProvisioned {
    param([string]$PackageName)
    Get-AppxPackage -Name $PackageName -AllUsers | Remove-AppxPackage -ErrorAction SilentlyContinue | Out-Null
    Get-AppxProvisionedPackage -Online | Where-Object DisplayName -like "*$PackageName*" | ForEach-Object {
        Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null
    }
}

function Remove-AutostartEntry { 
    param([string]$AppName)
    $runKeys = @("HKCU:\Software\Microsoft\Windows\CurrentVersion\Run","HKLM:\Software\Microsoft\Windows\CurrentVersion\Run")
    foreach ($key in $runKeys) {
        if (Get-ItemProperty -Path $key -Name $AppName -ErrorAction SilentlyContinue) {
            Remove-ItemProperty -Path $key -Name $AppName -ErrorAction SilentlyContinue | Out-Null
        }
    }
}

function Clean-RegistryEntries { 
    param([string]$AppName)
    $paths = @("HKCU:\Software\$AppName","HKLM:\Software\$AppName","HKCU:\Software\Microsoft\$AppName","HKLM:\Software\Microsoft\$AppName","HKLM:\Software\Wow6432Node\$AppName")
    foreach ($path in $paths) { 
        if (Test-Path $path) { Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue | Out-Null } 
    }
}

function Kill-ServiceProcess { 
    param([string]$PackageName)
    Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like "*$PackageName*" -or $_.Path -like "*$PackageName*" } | Stop-Process -Force -ErrorAction SilentlyContinue | Out-Null
}

function Remove-AppData { 
    param([string]$PackageName)
    $paths = @("$env:LOCALAPPDATA\Packages\$PackageName","$env:APPDATA\$PackageName","$env:ProgramData\$PackageName","$env:TEMP\$PackageName")
    foreach ($path in $paths) { 
        if (Test-Path $path) { Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue | Out-Null } 
    }
}

function Check-AppRemovalStatus { 
    param([string]$PackageName,[string]$DisplayName)
    $stillInstalled = Get-AppxPackage -Name $PackageName -ErrorAction SilentlyContinue
    $stillProvisioned = Get-AppxProvisionedPackage -Online | Where-Object DisplayName -like "*$PackageName*"
    $registryPaths = @("HKCU:\Software\$DisplayName","HKLM:\Software\$DisplayName","HKCU:\Software\Microsoft\$DisplayName","HKLM:\Software\Microsoft\$DisplayName","HKLM:\Software\Wow6432Node\$DisplayName")
    
    $registryExists = $false
    foreach ($path in $registryPaths) { if (Test-Path $path) { $registryExists = $true; break } }
    
    if ($stillInstalled -or $stillProvisioned -or $registryExists) {
        Update-Status "⚠️ App '$DisplayName' not fully removed." $false
        Add-Content -Path $logPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') WARNING: '$DisplayName' was not removed - SystemApp."
    } else {
        Update-Status "✅ App '$DisplayName' removed." $true
        Add-Content -Path $logPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') Removed: '$DisplayName' successfully purged!."
    }
}

# --- Create GUI ---
$form = New-Object System.Windows.Forms.Form
$form.Text = "Windows App Remover"
$form.Size = New-Object System.Drawing.Size(440,580)
$form.StartPosition = "CenterScreen"
$form.BackColor = [System.Drawing.Color]::FromArgb(223,228,176)

# Status Label
$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Location = New-Object System.Drawing.Point(10,440)
$statusLabel.Size = New-Object System.Drawing.Size(400,20)
$statusLabel.Text = "Ready"
$statusLabel.Font = New-Object System.Drawing.Font("Segoe UI",12,[System.Drawing.FontStyle]::Bold)
$statusLabel.TextAlign = "MiddleCenter"
$form.Controls.Add($statusLabel)

function Update-Status($text, $success=$true){
    $statusLabel.Text = $text
    $statusLabel.ForeColor = if ($success){[System.Drawing.Color]::ForestGreen} else {[System.Drawing.Color]::Firebrick}
    $form.Refresh()
}

function Style-Button($btn, $bgColor){
    $btn.BackColor = $bgColor
    $btn.ForeColor = [System.Drawing.Color]::Black
    $btn.FlatStyle = 'Flat'
    $btn.Font = New-Object System.Drawing.Font("Segoe UI",10,[System.Drawing.FontStyle]::Regular)
}

# List Box
$listBox = New-Object System.Windows.Forms.CheckedListBox
$listBox.Size = New-Object System.Drawing.Size(400,280)
$listBox.Location = New-Object System.Drawing.Point(10,10)
$listBox.DrawMode = 'OwnerDrawFixed'
$listBox.CheckOnClick = $true
$form.Controls.Add($listBox)


################################################################
# --- Info Label for detailed app descriptions (bottom, 2 lines) ---
$infoLabel = New-Object System.Windows.Forms.Label
$infoLabel.Dock = 'Bottom'                       
$infoLabel.AutoSize = $false
$infoLabel.Height = 40                              # Height for 2 lines
$infoLabel.BackColor = [System.Drawing.Color]::LightYellow
$infoLabel.BorderStyle = 'FixedSingle'
$infoLabel.TextAlign = 'TopLeft'
$form.Controls.Add($infoLabel)

# Descriptions for your list
$appDescriptions = @{
    "Clipchamp.Clipchamp"                   = "A simple tool for cutting and editing videos."
    "Microsoft.AV1VideoExtension"           = "Extension to enable playback of various video formats." 
    "Microsoft.AVCEncoderVideoExtension"    = "Extension to enable playback of various video formats."
    "Microsoft.VP9VideoExtensions"          = "Extension to enable playback of various video formats."
    "Microsoft.RawImageExtension"           = "Enables viewing of specialized photo formats (from iPhones or professional cameras)."
    "Microsoft.HEIFImageExtension"          = "Enables viewing of specialized photo formats (from iPhones or professional cameras)."
    "Microsoft.HEVCVideoExtension"          = "An important codec for high-resolution 4K video playback."
    "Microsoft.MPEG2VideoExtension"         = "Extension to enable playback of MPEG2 video formats."
    "Microsoft.WebMediaExtensions"          = "Helps Windows display specific video formats from the web."
    "Microsoft.WebpImageExtension"          = "Enables viewing of specialized photo formats (from iPhones or professional cameras)."
    "Microsoft.GamingApp"                   = "The hub for games, purchases, and PC game subscriptions (Xbox)."
    "Microsoft.GetHelp"                     = "An app to find solutions or support for Windows issues."
    "MicrosoftWindows.Client.WebExperience" = "Background services for Windows Widgets." 
    "Microsoft.Copilot"                     = "An AI assistant that answers questions and helps with writing tasks."
    "Microsoft.MicrosoftOfficeHub"          = "An overview of all your documents (Word, Excel, etc.) in one place."
    "Microsoft.MicrosoftSolitaireCollection"= "A collection of various card games."
    "Microsoft.MicrosoftStickyNotes"        = "Digital yellow sticky notes for your desktop."
    "Microsoft.OneDriveSync"                = "Automatically saves your files to the Microsoft Cloud."
    "Microsoft.OutlookForWindows"           = "The standard program for sending and receiving emails."
    "Microsoft.Paint"                       = "A simple program for drawing or basic image editing."
    "Microsoft.PowerAutomateDesktop"        = "A tool to automate recurring tasks on your PC."
    "Microsoft.ScreenSketch"                = "Allows creating and annotating screenshots."
    "Microsoft.StorePurchaseApp"            = "Background service that ensures purchases in the Microsoft Store work correctly."
    "Microsoft.Todos"                       = "A simple list for your daily tasks and to-dos."
    "Microsoft.Windows.DevHome"             = "Developer interface - Dashboard to monitor CPU, GPU, and RAM usage."
    "Microsoft.Windows.Photos"              = "The main app for viewing and organizing your photos."
    "Microsoft.WindowsAlarms"               = "Alarm clock, timer, and stopwatch for your computer."
    "Microsoft.WindowsCalculator"           = "Calculator." 
    "Microsoft.Windows.Camera"              = "The app for using your webcam for photos or videos."
    "Microsoft.WindowsFeedbackHub"          = "Report bugs to Microsoft or suggest new features."
    "Microsoft.WindowsSoundRecorder"        = "A simple program for recording voice or audio."
    "Microsoft.WindowsStore"                = "The official store to download and install programs." 
    "Microsoft.WindowsTerminal"             = "A professional tool for executing text-based system commands."
    "Microsoft.YourPhone"                   = "Connects your smartphone to your PC (for SMS, photos, and calls)."
    "Microsoft.ZuneMusic"                   = "The legacy name for the music app used to play audio files."
    "MicrosoftCorporationII.MicrosoftFamily"= "Settings for parental controls and family account management."
    "MicrosoftCorporationII.QuickAssist"    = "Allows a helper to remotely access your PC over the internet."
    "MicrosoftWindows.CrossDevice"          = "App that enables communication between Windows PC and other devices (smartphones, tablets)."
    "MSTeams"                               = "A program for video conferences, chats, and team collaboration."
    "Microsoft.Win32WebViewHost"            = "Enables Win32 apps to display modern web content."
    "Microsoft.Windows.Apprep.ChxApp"       = "Validates apps after installation (Compatibility Host Experience)."
    "Microsoft.Windows.AugLoop.CBS"         = "Automatic detection of data like phone numbers, dates, and emails."
    "Microsoft.Windows.CapturePicker"       = "Screen and window capturing tool."
    "Microsoft.Windows.XGpuEjectDialog"     = "Dialog for safely removing external graphics cards (eGPUs)."
    "Microsoft.Windows.CrossDevice"         = "Communication between Windows PC and other devices (smartphones, tablets)."    
}


# --- Mouse Move over ListBox ---
$listBox.Add_MouseMove({
    param($sender, $e)

    $index = $listBox.IndexFromPoint($e.Location)
    if ($index -ge 0) {
        $displayName = $listBox.Items[$index]
        $packageName = $appMap[$displayName]

        if ($appDescriptions.ContainsKey($packageName)) {
            $description = $appDescriptions[$packageName]
        } else {
            $description = "Package Name: $packageName"
        }

        # Two lines: Description + Package Name
        $infoLabel.Text = "$description`n"
     
        # Debug output to PowerShell window
        Write-Host "PackageName: $packageName"

        # Color highlighting:
        # Red for all critical packages mentioned
        if ($packageName -like "ApplicationCompatibilityEnhancements*" -or
            $packageName -like "1527c705-839a-4832-9118-54d4Bd6a0c89*" -or
            $packageName -like "c5e2524a-ea46-4f67-841f-6a9465d9d515*" -or
            $packageName -like "E2A4F912-2574-4A75-9BB0-0D023378592B*" -or
            $packageName -like "F46D4000-FD22-4DB4-AC8E-4E1DDDE828FE*" -or
            $packageName -like "Microsoft.AAD.BrokerPlugin*" -or
            $packageName -like "Microsoft.AccountsControl*" -or
            $packageName -like "Microsoft.AsyncTextService*" -or
            $packageName -like "Microsoft.BioEnrollment*" -or
            $packageName -like "Microsoft.CredDialogHost*" -or
            $packageName -like "MicrosoftWindows.Client.FileExp*" -or
            $packageName -like "MicrosoftWindows.Client.OOBE*" -or
            $packageName -like "MicrosoftWindows.Client.Photon*" -or
            $packageName -like "MicrosoftWindows.Client.WebExperience*" -or
            $packageName -like "MicrosoftWindows.UndockedDevKit*" -or
            $packageName -like "Windows.CBSPreview*" -or
            $packageName -like "windows.immersivecontrolpanel*" -or
            $packageName -like "Windows.PrintDialog*" -or
            $packageName -like "Microsoft.DesktopAppInstaller*" -or
            $packageName -like "Microsoft.Windows.AssignedAccessLockApp*" -or
            $packageName -like "Microsoft.Windows.SecureAssessmentBrowser*" ) {
            $infoLabel.ForeColor = [System.Drawing.Color]::Red
            Write-Host "Critical package detected" -ForegroundColor Red
        }
        else {
            $infoLabel.ForeColor = [System.Drawing.Color]::Blue
            Write-Host "Non-critical package" -ForegroundColor Blue
        }
    }
    else {
        $infoLabel.Text = ""
        $infoLabel.ForeColor = [System.Drawing.Color]::Black
    }
})

# Protection Lists
function Load-AppList($filePath){ if(Test-Path $filePath){ Get-Content $filePath | Where-Object {$_ -notmatch '^#' -and $_.Trim() -ne ''} | ForEach-Object { $_.Trim().ToLower() } } else { @() } }
$protectedApps   = Load-AppList "$PSScriptRoot\ProtectedApps.txt"
$preselectedApps = Load-AppList "$PSScriptRoot\AppsList_to_remove.txt"

# Collect Apps
$appMap = @{}
$installedApps = Get-AppxPackage | Sort-Object Name
foreach ($app in $installedApps){
    $rawName=$app.Name; $niceName=$app.DisplayName
    if(-not $niceName -or $niceName -match "^[{].*[}]$"){ $niceName=$app.PackageFamilyName }
    if($niceName -match "^Microsoft\."){ $niceName=$rawName -replace "^Microsoft\.",""; $niceName=$niceName -replace "_.*","" }
    if(-not $niceName){ $niceName=$rawName }
    if($protectedApps -contains $rawName.ToLower()){continue }

    $index=$listBox.Items.Add($niceName)
    $appMap[$niceName]=$rawName
}

# Search Box
$searchBox=New-Object System.Windows.Forms.TextBox
$searchBox.Location=New-Object System.Drawing.Point(10,300)
$searchBox.Size=New-Object System.Drawing.Size(400,20)
$searchBox.Text="🔍 Search App..."
$searchBox.ForeColor='Gray'
$form.Controls.Add($searchBox)

$searchBox.Add_GotFocus({ if($searchBox.Text -eq "🔍 Search App..."){ $searchBox.Text=""; $searchBox.ForeColor='Black' } })
$searchBox.Add_LostFocus({ if([string]::IsNullOrWhiteSpace($searchBox.Text)){ $searchBox.Text="🔍 Search App..."; $searchBox.ForeColor='Gray' } })

$searchBox.Add_TextChanged({
    $listBox.Items.Clear()
    if($searchBox.Text -eq "🔍 Search App..." -or [string]::IsNullOrWhiteSpace($searchBox.Text)){
        foreach($displayName in $appMap.Keys){
            $index=$listBox.Items.Add($displayName)
            $rawName=$appMap[$displayName]
            if($preselectedApps -contains $rawName.ToLower()){ $listBox.SetItemChecked($index,$true) }
        }
        return
    }
    foreach($displayName in $appMap.Keys){
        if($displayName.ToLower() -like "*$($searchBox.Text.ToLower())*"){
            $index=$listBox.Items.Add($displayName)
            $rawName=$appMap[$displayName]
            if($preselectedApps -contains $rawName.ToLower()){ $listBox.SetItemChecked($index,$true) }
        }
    }
})

# --- Draw Item with Color for System Apps ---
$listBox.Add_DrawItem({
    param($sender, $e)
    $e.DrawBackground()
    $displayName = $listBox.Items[$e.Index]
    $packageName = $appMap[$displayName]

    # Color Logic: System apps red, selected green, others black
    if ($packageName -like "Microsoft.*") {
        $color = 'Red'
    } elseif ($listBox.GetItemChecked($e.Index)) {
        $color = 'DarkGreen'
    } else {
        $color = 'Black'
    }

    $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::$color)
    $e.Graphics.DrawString($displayName, $e.Font, $brush, $e.Bounds.Location)
    $e.DrawFocusRectangle()
})


# --- Buttons ---
$selectAllButton = New-Object System.Windows.Forms.Button
$selectAllButton.Text = "Select All"
$selectAllButton.Location = New-Object System.Drawing.Point(10,330)
$selectAllButton.Size = New-Object System.Drawing.Size(195,30)
$selectAllButton.Add_Click({
    for ($i = 0; $i -lt $listBox.Items.Count; $i++) {
        $listBox.SetItemChecked($i, $true) | Out-Null
    }
})
Style-Button $selectAllButton ([System.Drawing.Color]::LightGreen)
$form.Controls.Add($selectAllButton)

$clearAllButton = New-Object System.Windows.Forms.Button
$clearAllButton.Text = "Deselect All"
$clearAllButton.Location = New-Object System.Drawing.Point(215,330)
$clearAllButton.Size = New-Object System.Drawing.Size(195,30)
$clearAllButton.Add_Click({
    for ($i = 0; $i -lt $listBox.Items.Count; $i++) {
        $listBox.SetItemChecked($i, $false) | Out-Null
    }
})
Style-Button $clearAllButton ([System.Drawing.Color]::LightSkyBlue)
$form.Controls.Add($clearAllButton)

$removeButton = New-Object System.Windows.Forms.Button
$removeButton.Text = "Remove Selected"
$removeButton.Location = New-Object System.Drawing.Point(10,370)
$removeButton.Size = New-Object System.Drawing.Size(400,30)
$removeButton.Add_Click({
    $progressBar.Value = 0
    $progressBar.Maximum = $listBox.CheckedItems.Count

    foreach ($displayName in $listBox.CheckedItems) {
        $packageName = $appMap[$displayName]
        #Update-Status "Removing: $displayName"
        #Add-Content -Path $logPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') Removing: $displayName ($packageName)" | Out-Null

        Remove-AppxAndProvisioned -PackageName $packageName | Out-Null
        Remove-AutostartEntry -AppName $displayName | Out-Null
        Clean-RegistryEntries -AppName $displayName | Out-Null
        Kill-ServiceProcess -PackageName $packageName | Out-Null
        Remove-AppData -PackageName $packageName | Out-Null
        Check-AppRemovalStatus -PackageName $packageName -DisplayName $displayName

        $progressBar.Value += 1
    }

    Update-Status "Done!"
    [System.Windows.Forms.MessageBox]::Show("Selected apps have been removed.", "Finished", 0, 64) | Out-Null
})
Style-Button $removeButton ([System.Drawing.Color]::LightSalmon)
$form.Controls.Add($removeButton)

# --- Progress Bar ---
$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(10,410)
$progressBar.Size = New-Object System.Drawing.Size(400,20)
$progressBar.Minimum = 0
$form.Controls.Add($progressBar)

# --- Show Window ---
$form.Topmost = $false
$form.ShowDialog() | Out-Null
