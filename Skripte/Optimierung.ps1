Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ------------------------------------------------------------
# FORM
# ------------------------------------------------------------
$form = New-Object System.Windows.Forms.Form
$form.Text = "Microsoft Edge Optimization"
$form.Size = New-Object System.Drawing.Size(600, 700)
$form.StartPosition = "CenterScreen"
$form.BackColor = [System.Drawing.Color]::FromArgb(223,228,176)

# ------------------------------------------------------------
# STATUS LABEL
# ------------------------------------------------------------
$labelStatus = New-Object System.Windows.Forms.Label
$labelStatus.Text = "Ready"
$labelStatus.Location = "20,570"
$labelStatus.Size = "540,30"
$labelStatus.Font = "Segoe UI,10,style=Bold"
$labelStatus.TextAlign = "MiddleCenter"
$form.Controls.Add($labelStatus)

function Update-Status {
    param([string]$text, [bool]$ok = $true)

    $labelStatus.Text = $text
    $labelStatus.ForeColor = if($ok){[System.Drawing.Color]::Green}else{[System.Drawing.Color]::Red}
	$labelStatus.Font = New-Object System.Drawing.Font( $labelStatus.Font.FontFamily, 14, $labelStatus.Font.Style )
}

# ------------------------------------------------------------
# CLEANUP GROUP
# ------------------------------------------------------------
$grpCleanup = New-Object System.Windows.Forms.GroupBox
$grpCleanup.Text = "Cleanup Browser Data"
$grpCleanup.Location = "20,20"
$grpCleanup.Size = "540,120"
$form.Controls.Add($grpCleanup)

$cbCleanup = New-Object System.Windows.Forms.CheckBox
$cbCleanup.Text = "Clear Cache, History & Cookies"
$cbCleanup.Location = "10,25"
$cbCleanup.Width = 500
$grpCleanup.Controls.Add($cbCleanup)

$cbGPU = New-Object System.Windows.Forms.CheckBox
$cbGPU.Text = "Clear GPU Cache"
$cbGPU.Location = "10,50"
$cbGPU.Width = 500
$grpCleanup.Controls.Add($cbGPU)

$cbSW = New-Object System.Windows.Forms.CheckBox
$cbSW.Text = "Clear Service Worker Cache"
$cbSW.Location = "10,75"
$cbSW.Width = 500
$grpCleanup.Controls.Add($cbSW)

$cbUpdate = New-Object System.Windows.Forms.CheckBox
$cbUpdate.Text = "Clear Edge Update Cache"
$cbUpdate.Location = "10,100"
$cbUpdate.Width = 500
$grpCleanup.Controls.Add($cbUpdate)

# ------------------------------------------------------------
# POLICIES SCROLL PANEL
# ------------------------------------------------------------
$panelPolicies = New-Object System.Windows.Forms.Panel
$panelPolicies.Location = "20,160"
$panelPolicies.Size = "540,350"
$panelPolicies.AutoScroll = $true
$panelPolicies.BorderStyle = "FixedSingle"
$form.Controls.Add($panelPolicies)

$grpPolicies = New-Object System.Windows.Forms.GroupBox
$grpPolicies.Text = "Adjust Settings (Policies)"
$grpPolicies.Location = "0,0"
$grpPolicies.Size = "500,900"
$panelPolicies.Controls.Add($grpPolicies)

$y = 25
$policyCheckboxes = @()

function Add-PolicyCheckbox {
    param([string]$text)

    $cb = New-Object System.Windows.Forms.CheckBox
    $cb.Text = $text
    $cb.Location = "10,$y"
    $cb.Width = 450
    $grpPolicies.Controls.Add($cb)

    $script:policyCheckboxes += $cb
    $script:y += 25

    return $cb
}

# ------------------------------------------------------------
# POLICIES – CHECKBOXES
# ------------------------------------------------------------
$cbStartupBoost = Add-PolicyCheckbox "Disable Startup Boost"
$cbBackground   = Add-PolicyCheckbox "Disable background processes after closing"
$cbSleepTabs    = Add-PolicyCheckbox "Enable Sleeping Tabs"
$cbSleepTimeout = Add-PolicyCheckbox "Set Sleep Tab timeout"
$cbGPUAccel     = Add-PolicyCheckbox "Enable hardware acceleration (GPU)"

$cbTelemetry    = Add-PolicyCheckbox "Reduce Telemetry & Data Collection"
$cbAds          = Add-PolicyCheckbox "Disable personalized ads"
$cbFeedback     = Add-PolicyCheckbox "Disable feedback prompts"
$cbSuggest      = Add-PolicyCheckbox "Disable search suggestions"
$cbBing         = Add-PolicyCheckbox "Disable Bing integration & Sidebar"

$cbSmartScreen  = Add-PolicyCheckbox "Enable Microsoft Defender SmartScreen"
$cbCookies      = Add-PolicyCheckbox "Block third-party cookies"
$cbTracking     = Add-PolicyCheckbox "Enable Strict Tracking Prevention"

$cbHome         = Add-PolicyCheckbox "Hide Home button"
$cbRewards      = Add-PolicyCheckbox "Remove Microsoft Rewards"
$cbTopSites     = Add-PolicyCheckbox "Hide Top Sites on New Tab page"
$cbRestore      = Add-PolicyCheckbox "Disable crash restore page"

# ------------------------------------------------------------
# BUTTONS
# ------------------------------------------------------------

$btnSelectAll = New-Object System.Windows.Forms.Button
$btnSelectAll.Text = "Select All"
$btnSelectAll.Location = "20,520"
$btnSelectAll.Size = "200,40"
$btnSelectAll.Font = "Segoe UI,10,style=Bold"
$btnSelectAll.BackColor = [System.Drawing.Color]::Orange
$form.Controls.Add($btnSelectAll)

$btnRun = New-Object System.Windows.Forms.Button
$btnRun.Text = "Run Optimization"
$btnRun.Location = "240,520"
$btnRun.Size = "150,40"
$btnRun.Font = "Segoe UI,10,style=Bold"
$btnRun.BackColor = [System.Drawing.Color]::LightCoral
$form.Controls.Add($btnRun)

$btnUndo = New-Object System.Windows.Forms.Button
$btnUndo.Text = "Reset Settings"
$btnUndo.Location = "400,520"
$btnUndo.Size = "160,40"
$btnUndo.Font = "Segoe UI,10,style=Bold"
$btnUndo.BackColor = [System.Drawing.Color]::Orange
$form.Controls.Add($btnUndo)

$btnClose = New-Object System.Windows.Forms.Button
$btnClose.Text = "Close"
$btnClose.Location = "20,610"
$btnClose.Size = "540,30"
$btnClose.BackColor = [System.Drawing.Color]::LightGreen
$form.Controls.Add($btnClose)

$btnClose.Add_Click({ $form.Close() })

# ------------------------------------------------------------
# BUTTON LOGIC: SELECT ALL
# ------------------------------------------------------------
$btnSelectAll.Add_Click({
    foreach ($cb in $policyCheckboxes) {
        $cb.Checked = $true
    }
    Update-Status "All policies selected."
})

# ------------------------------------------------------------
# GET EDGE PROFILES
# ------------------------------------------------------------
function Get-EdgeProfiles {
    $path = "$env:LOCALAPPDATA\Microsoft\Edge\User Data"
    if (-not (Test-Path $path)) { return @() }

    return Get-ChildItem $path -Directory |
        Where-Object { $_.Name -match "^(Default|Profile \d+)$" }
}


# ------------------------------------------------------------
# SET POLICIES
# ------------------------------------------------------------
function Set-EdgePolicies {

    $edgePolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"

    if (-not (Test-Path $edgePolicyPath)) {
        New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft" -Name "Edge" -Force | Out-Null
    }

    $policies = @{}

    if ($cbStartupBoost.Checked) { $policies["StartupBoostEnabled"] = 0 }
    if ($cbBackground.Checked) { $policies["BackgroundModeEnabled"] = 0 }
    if ($cbSleepTabs.Checked) { $policies["SleepingTabsEnabled"] = 1 }
    if ($cbSleepTimeout.Checked) { $policies["SleepingTabsTimeout"] = 5 }
    if ($cbGPUAccel.Checked) { $policies["HardwareAccelerationModeEnabled"] = 1 }

    if ($cbTelemetry.Checked) { $policies["DiagnosticData"] = 0 }
    if ($cbAds.Checked) { $policies["PersonalizationReportingEnabled"] = 0 }
    if ($cbFeedback.Checked) { $policies["UserFeedbackAllowed"] = 0 }
    if ($cbSuggest.Checked) { $policies["SearchSuggestEnabled"] = 0 }
    if ($cbBing.Checked) { $policies["AddressBarMicrosoftSearchInBingProviderEnabled"] = 0 }

    if ($cbSmartScreen.Checked) { $policies["SmartScreenEnabled"] = 1 }
    if ($cbCookies.Checked) { $policies["BlockThirdPartyCookies"] = 1 }
    if ($cbTracking.Checked) { $policies["TrackingPrevention"] = 3 }

    if ($cbHome.Checked) { $policies["ShowHomeButton"] = 0 }
    if ($cbRewards.Checked) { $policies["ShowMicrosoftRewards"] = 0 }
    if ($cbTopSites.Checked) { $policies["NewTabPageHideDefaultTopSites"] = 1 }
    if ($cbRestore.Checked) { $policies["HideRestoreDialogEnabled"] = 1 }

    foreach ($key in $policies.Keys) {
        Set-ItemProperty -Path $edgePolicyPath -Name $key -Value $policies[$key] -Type DWord
    }

    Update-Status "Policies applied." $true
}

# ------------------------------------------------------------
# UNDO POLICIES
# ------------------------------------------------------------
function Undo-EdgePolicies {
    $edgePolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"

    if (Test-Path $edgePolicyPath) {
        Remove-Item $edgePolicyPath -Recurse -Force
        Update-Status "Policies removed." $true
    }
    else {
        Update-Status "No policies found." $false
    }
}

$btnUndo.Add_Click({
    Undo-EdgePolicies
})

# ------------------------------------------------------------
# OPTIMIZATION
# ------------------------------------------------------------
$btnRun.Add_Click({

    Update-Status "Optimizing Edge..."

    Stop-Process -Name "msedge" -Force -ErrorAction SilentlyContinue

    $profiles = Get-EdgeProfiles

    # CLEANUP
    if ($cbCleanup.Checked) {
        foreach ($profile in $profiles) {
            $files = @("History","History-journal","Cookies","Cookies-journal","Web Data","Web Data-journal","Local State")
            $folders = @("Cache")

            foreach ($file in $files) {
                $path = Join-Path $profile.FullName $file
                if (Test-Path $path) { Remove-Item $path -Force -ErrorAction SilentlyContinue }
            }

            foreach ($folder in $folders) {
                $path = Join-Path $profile.FullName $folder
                if (Test-Path $path) { Remove-Item $path -Recurse -Force -ErrorAction SilentlyContinue }
            }
        }
    }

    # GPU CACHE
    if ($cbGPU.Checked) {
        foreach ($profile in $profiles) {
            $gpu = Join-Path $profile.FullName "GPUCache"
            if (Test-Path $gpu) { Remove-Item $gpu -Recurse -Force -ErrorAction SilentlyContinue }
        }
    }

    # SERVICE WORKER CACHE
    if ($cbSW.Checked) {
        foreach ($profile in $profiles) {
            $sw = Join-Path $profile.FullName "Service Worker\CacheStorage"
            if (Test-Path $sw) { Remove-Item $sw -Recurse -Force -ErrorAction SilentlyContinue }
        }
    }

    # UPDATE CACHE
    if ($cbUpdate.Checked) {
        $update = "$env:LOCALAPPDATA\Microsoft\EdgeUpdate"
        if (Test-Path $update) { Remove-Item $update -Recurse -Force -ErrorAction SilentlyContinue }
    }

    # POLICIES
    Set-EdgePolicies

    Update-Status "Edge optimization completed ✅" $true
})

# ------------------------------------------------------------
# START
# ------------------------------------------------------------
$form.ShowDialog()
