#Wait for the signal from the userdata script before testing
while (!(. C:\scripts\check_block.ps1)) {
  Write-Host ("Setup not complete. Retrying...")
  Start-Sleep 10 
}
Write-Host ("Setup complete!")
