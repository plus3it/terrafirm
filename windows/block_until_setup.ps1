#Wait for the signal from the userdata script before testing
while (!(.\check_block.ps1)) {
  Write-Host ("Setup not complete. Retrying...")
  Start-Sleep 20 
}
