$admin = [adsi]("WinNT://./administrator, user")
Write-Host "Admin SID: " -NoNewline
Write-Host $admin.objectSid
Write-Host "Admin name: " -NoNewline
Write-Host $admin.Name
