#Wait for the signal from the userdata script before testing
while (!(Test-Path 'C:\Temp\SETUP_COMPLETE_SIGNAL')) {
    Write-Host ("Setup not complete. Retrying...")
    Start-Sleep 20 
}
