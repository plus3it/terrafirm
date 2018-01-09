#Wait for the signal from the userdata script before testing
while (!(Test-Path 'C:\tmp\SIGNAL')) {
    Write-Host ("Setup not complete. Retrying...")
    Start-Sleep 20 
}
