#Wait for the signal from the userdata script before testing
while (!(. C:\scripts\check_block.ps1)) {
  Write-Host ("Setup not complete. Retrying...")
  Start-Sleep -s 2
}
Write-Host ("Setup complete!")
