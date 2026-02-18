# DiagTrack.psm1
# Modul für Diagnose-Tracking (DiagTrack) Bereinigung

# ------------------------------------------------------------
# DiagTrack-Dienst stoppen
# ------------------------------------------------------------
function Stop-WmfDiagTrackService {
    param([System.Windows.Forms.TextBox]$LogBox)

#    #Write-WmfLog -Text "Prüfe DiagTrack-Dienst..." -LogBox $LogBox

    $serviceName = "DiagTrack"
    $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue

    if (-not $service) {
#        Write-WmfLog -Text "→ Dienst nicht gefunden." -LogBox $LogBox
        return
    }

    if ($service.Status -ne "Running") {
#        Write-WmfLog -Text "→ Dienst läuft nicht." -LogBox $LogBox
        return
    }

#    Write-WmfLog -Text "→ Stoppe Dienst..." -LogBox $LogBox

    try {
        Stop-Service -Name $serviceName -Force -ErrorAction Stop
        $service.WaitForStatus("Stopped")
#        Write-WmfLog -Text "→ Dienst gestoppt." -LogBox $LogBox
    }
    catch {
#        Write-WmfLog -Text "Fehler beim Stoppen: $_" -LogBox $LogBox
    }
}

# ------------------------------------------------------------
# ETL-Dateien löschen (mit Besitzübernahme)
# ------------------------------------------------------------
function Remove-WmfDiagTrackETL {
    param([System.Windows.Forms.TextBox]$LogBox)

    $paths = @(
        "$env:PROGRAMDATA\Microsoft\Diagnosis\ETLLogs\AutoLogger\AutoLogger-Diagtrack-Listener.etl",
        "$env:PROGRAMDATA\Microsoft\Diagnosis\ETLLogs\ShutdownLogger\AutoLogger-Diagtrack-Listener.etl"
    )

    foreach ($path in $paths) {
#        Write-WmfLog -Text "Lösche ETL-Datei: $path" -LogBox $LogBox

        if (-not (Test-Path $path)) {
#            Write-WmfLog -Text "→ Datei nicht vorhanden." -LogBox $LogBox
            continue
        }

        try {
            Start-Process "takeown.exe" -ArgumentList "/f `"$path`" /a" -Wait -WindowStyle Hidden
            Start-Process "icacls.exe" -ArgumentList "`"$path`" /grant Administrators:F /t" -Wait -WindowStyle Hidden
            Remove-Item -Path $path -Force -ErrorAction Stop
#            Write-WmfLog -Text "→ Datei gelöscht." -LogBox $LogBox
        }
        catch {
#            Write-WmfLog -Text "Fehler: $_" -LogBox $LogBox
        }
    }
}

# ------------------------------------------------------------
# DiagTrack-Dienst wieder starten
# ------------------------------------------------------------
function Restore-WmfDiagTrackService {
    param([System.Windows.Forms.TextBox]$LogBox)
}
#    Write-WmfLog -Text "Starte DiagTrack-Dienst..." -LogBox $LogBox

 #   try {
        Start-Service "DiagTrack"
#        Write-WmfLog -Text "→ Dienst gestartet." -LogBox $LogBox
#    }
#    catch {
#        Write-WmfLog -Text "Fehler beim Starten: $_" -LogBox $LogBox
#    }
#}

Export-ModuleMember -Function *-Wmf*
