<powershell>

function Tfi-Out([String] $Msg, $Success) {
  # result is succeeded or failed or nothing if success is null
  If($Success)
  {
    $result = ": Succeeded"
  }
  ElseIf ($False -eq $Success) # order is important in case of null since coercing types
  {
    $result = ": Failed"
  }
  "$(Get-Date): $Msg $result" | Out-File "${tfi_win_userdata_log}" -Append
}

# directory needed by logs and for various other purposes
Invoke-Expression -Command "mkdir C:\Temp" -ErrorAction SilentlyContinue

# Set Administrator password, for logging in before wam changes Administrator account name to ${tfi_rm_user}
$Admin = [adsi]("WinNT://./Administrator, user")
$Admin.psbase.invoke("SetPassword", "${tfi_rm_pass}")
Tfi-Out "Set admin password" $?

# initial winrm setup
Start-Process -FilePath "winrm" -ArgumentList "quickconfig -q"
Tfi-Out "WinRM quickconfig" $?

# close the firewall
netsh advfirewall firewall add rule name="WinRM in" protocol=tcp dir=in profile=any localport=5985 remoteip=any localip=any action=block
Tfi-Out "Close firewall" $?

# declare an array to hold the status (number and message)
$UserdataStatus=@(1,"Error: Install not completed (should never see this error)")

Try {

  Tfi-Out "Start install"

  # time wam install
  $StartDate=Get-Date

  # this will become the watchmaker portion of install
  WATCHMAKER_INSTALL_GOES_HERE

  $EndDate = Get-Date
  Tfi-Out("WAM install took {0} seconds." -f [math]::Round(($EndDate - $StartDate).TotalSeconds))
  Tfi-Out("End install")

  $UserdataStatus=@(0,"Success") # made it this far, it's a success
}
Catch 
{
  $ErrCode = 1  # trying to set this to $lastExitCode does not work (always get 0)

  Tfi-Out ("*** ERROR caught ($Stage) ***")

  $ErrorMessage = $_.Exception.ItemName + " reported: " + $_.Exception.Message
  Tfi-Out $ErrorMessage
  $UserdataStatus=@($ErrCode,"Error at: " + $Stage + " [$ErrorMessage]")
}

# Set Administrator password - should always go after wm install because username not yet changed
$Admin = [adsi]("WinNT://./${tfi_rm_user}, user")
$Admin.psbase.invoke("SetPassword", "${tfi_rm_pass}")
Tfi-Out "Set admin password" $?

If (Test-Path -path "C:\salt\salt-call.bat") 
{
  # fix the lgpos to allow winrm
  C:\salt\salt-call --local -c C:\Watchmaker\salt\conf lgpo.set_reg_value `
    key='HKLM\SOFTWARE\Policies\Microsoft\Windows\WinRM\Service\AllowBasic' `
    value='1' `
    vtype='REG_DWORD'
  Tfi-Out "Salt modify lgpo, allow basic" $?
    
  C:\salt\salt-call --local -c C:\Watchmaker\salt\conf lgpo.set_reg_value `
    key='HKLM\SOFTWARE\Policies\Microsoft\Windows\WinRM\Service\AllowUnencryptedTraffic' `
    value='1' `
    vtype='REG_DWORD'
  Tfi-Out "Salt modify lgpo, unencrypted" $?
}
Else
{
  # if salt isn't around to open winrm because of an error, use the old fashioned method
  Start-Process -FilePath "winrm" -ArgumentList "set winrm/config/service @{AllowUnencrypted=`"true`"}" -Wait
  Tfi-Out "Open winrm/unencrypted without salt" $?
  Start-Process -FilePath "winrm" -ArgumentList "set winrm/config/service/auth @{Basic=`"true`"}" -Wait
  Tfi-Out "Open winrm/auth/basic without salt" $?
}

# in case wam didn't change admin account name, winrm won't be able to log in so let's change it ourselves
$Admin = [adsi]("WinNT://./Administrator, user")
If ($Admin.Name) 
{ 
  $Admin.psbase.rename("${tfi_rm_user}")
  Tfi-Out "Rename admin account" $?
}

# write the status to a file for reading by test script
$UserdataStatus | Out-File C:\Temp\userdata_status
Tfi-Out "Write userdata status file" $?

# open firewall for winrm - rule was added previously, now we modify it with "set"
netsh advfirewall firewall set rule name="WinRM in" new action=allow
Tfi-Out "Open firewall" $?

# if $Error variables has a queue of errors, this will output them to a file
$ErrorLog = "C:\Temp\errors.log"
Add-Content $ErrorLog -value "ERRORS --------------------"
Add-Content $ErrorLog -value $Error|Format-List -Force

# upload logs to S3 bucket
$S3Keyfix="Win" + (((Get-WmiObject -class Win32_OperatingSystem).Caption) -replace '.+(\d\d)\s(.{2}).+','$1$2')
If ($S3Keyfix.Substring($S3Keyfix.get_Length()-2) -eq 'Da') {
    $S3Keyfix=$S3Keyfix -replace ".{2}$"
}

Write-S3Object -BucketName "${tfi_s3_bucket}/${tfi_build_date}/${tfi_build_id}/$S3Keyfix" -File ${tfi_win_userdata_log} -ErrorAction SilentlyContinue
Write-S3Object -BucketName "${tfi_s3_bucket}/${tfi_build_date}/${tfi_build_id}/$S3Keyfix" -File $ErrorLog -ErrorAction SilentlyContinue
Write-S3Object -BucketName "${tfi_s3_bucket}" -Folder "C:\\Program Files\\Amazon\\Ec2ConfigService\\Logs" -KeyPrefix ${tfi_build_date}/${tfi_build_id}/$S3Keyfix/cloud/ -ErrorAction SilentlyContinue
Write-S3Object -BucketName "${tfi_s3_bucket}" -Folder "C:\\ProgramData\\Amazon\\EC2-Windows\\Launch\\Log" -KeyPrefix ${tfi_build_date}/${tfi_build_id}/$S3Keyfix/cloud/ -ErrorAction SilentlyContinue
Write-S3Object -BucketName "${tfi_s3_bucket}" -Folder "C:\\Watchmaker\\Logs" -KeyPrefix ${tfi_build_date}/${tfi_build_id}/$S3Keyfix/watchmaker/ -SearchPattern *.log -ErrorAction SilentlyContinue

Start-Process -FilePath "winrm" -ArgumentList "set winrm/config @{MaxTimeoutms=`"1900000`"}"
</powershell>