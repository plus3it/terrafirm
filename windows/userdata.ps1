<powershell>
function Tfi-Out([String] $Msg, $Success) 
{
  if ( $Msg -eq "history" )
  {
    $Msg = [String](Get-History -Count 1).CommandLine
  }

  $ThrowError = $False
  # result is succeeded or failed or nothing if success is null
  If($Success)
  {
    $Result = ": Succeeded"
  }
  ElseIf ($False -eq $Success) # order is important in case of null since coercing types
  {
    $Result = ": Failed"
    $ThrowError = $True
  }
  "$(Get-Date): $Msg $Result" | Out-File "${tfi_win_userdata_log}" -Append -Encoding utf8
  If( $ThrowError) 
  {
    return $ThrowError
  }
}

function Tfi-OutThrow([String] $Msg, $Success) {
  If ( Tfi-Out $Msg $Success ) {
    Throw "TFI:" + $Msg
  }
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

  # ---------- begin of wam install ----------
  $GitRepo = "${tfi_git_repo}"
  $GitRef = "${tfi_git_ref}"

  Tfi-Out "Security protocol before bootstrap: $([Net.ServicePointManager]::SecurityProtocol | Out-String)"

  $BootstrapUrl = "https://raw.githubusercontent.com/plus3it/watchmaker/develop/docs/files/bootstrap/watchmaker-bootstrap.ps1"
  $PythonUrl = "https://www.python.org/ftp/python/3.6.4/python-3.6.4-amd64.exe"
  $GitUrl = "https://github.com/git-for-windows/git/releases/download/v2.16.2.windows.1/Git-2.16.2-64-bit.exe"
  $PypiUrl = "https://pypi.org/simple"

  # Use TLS, as git won't do SSL now
  [Net.ServicePointManager]::SecurityProtocol = "Ssl3, Tls, Tls11, Tls12"

  # Download bootstrap file
  $Stage = "download bootstrap"
  $BootstrapFile = "$${Env:Temp}\$($${BootstrapUrl}.split("/")[-1])"
  (New-Object System.Net.WebClient).DownloadFile($BootstrapUrl, $BootstrapFile)

  # Install python and git
  $Stage = "install python/git"
  & "$BootstrapFile" `
      -PythonUrl "$PythonUrl" `
      -GitUrl "$GitUrl" `
      -Verbose -ErrorAction Stop

  Tfi-Out "Security protocol after bootstrap: $([Net.ServicePointManager]::SecurityProtocol | Out-String)"

  # Upgrade pip and setuptools
  $Stage = "upgrade pip setuptools boto3"
  pip install --index-url="$PypiUrl" --upgrade pip setuptools boto3
  Tfi-OutThrow "history" $?

  # Clone watchmaker
  $Stage = "git"
  git clone "$GitRepo" --recursive
  Tfi-OutThrow "history" $?
  cd watchmaker
  if ($GitRef)
  {
    # decide whether to switch to pull request or branch
    if($GitRef -match "^[0-9]+$")
    {
      git fetch origin pull/$GitRef/head:pr-$GitRef
      Tfi-OutThrow "history" $?
      git checkout pr-$GitRef
      Tfi-OutThrow "history" $?
    }
    else
    {
      git checkout $GitRef
      Tfi-OutThrow "history" $?
    }
  }

  # Install watchmaker
  $Stage = "install wam"
  pip install --index-url "$PypiUrl" --editable .
  Tfi-OutThrow "history" $?

  # Run watchmaker
  $Stage = "run wam"
  #Invoke-Expression -Command "watchmaker ${tfi_common_args} ${tfi_win_args}" -ErrorAction Stop
  watchmaker ${tfi_common_args} ${tfi_win_args}
  Tfi-OutThrow "history" $?
  # ----------  end of wam install ----------

  $EndDate = Get-Date
  Tfi-Out("WAM install took {0} seconds." -f [math]::Round(($EndDate - $StartDate).TotalSeconds))
  Tfi-Out("End install")

  $UserdataStatus=@(0,"Success") # made it this far, it's a success
}
catch
{
  # check for two broad classes of exceptions, those thrown by tfi code and those naturally occurring
  $em = [String]$_.Exception
  If ($em -match "TFI:") 
  {
    Tfi-Out "TFI Thrown Exception ****************************************"
    Tfi-Out ($error | Format-List * -Force | Out-String)
    Tfi-Out "Error[0]:" + ($error[0] | Format-List * -Force | Out-String)
    Tfi-Out "Error[1]:" + ($error[1] | Format-List * -Force | Out-String)
    Tfi-Out "Error[2]:" + ($error[2] | Format-List * -Force | Out-String)
    Tfi-Out (Get-History | Out-String)
  }
  Else
  {
    Tfi-Out "Other Exception *********************************************"
    $ErrorMessage = [String]$_.Exception + "Invocation Info: " + ($PSItem.InvocationInfo | Format-List * | Out-String)
  }
  Tfi-Out ("*** ERROR caught ($Stage) ***")
  Tfi-Out $ErrorMessage

  # setup userdata status for passing to the test script via a file
  $ErrCode = 1  # trying to set this to $lastExitCode does not work (always get 0)
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
Add-Content $ErrorLog -value $Error | Format-List *

# upload logs to S3 bucket
$S3Keyfix="Win" + (((Get-WmiObject -class Win32_OperatingSystem).Caption) -replace '.+(\d\d)\s(.{2}).+','$1$2')
If ($S3Keyfix.Substring($S3Keyfix.get_Length()-2) -eq 'Da') {
    $S3Keyfix=$S3Keyfix -replace ".{2}$"
}

$ArtifactPrefix = "${tfi_build_date}/${tfi_build_hour}_${tfi_build_id}/$S3Keyfix"

Write-S3Object -BucketName "${tfi_s3_bucket}/$ArtifactPrefix" -File ${tfi_win_userdata_log} -ErrorAction SilentlyContinue
Write-S3Object -BucketName "${tfi_s3_bucket}/$ArtifactPrefix" -File $ErrorLog -ErrorAction SilentlyContinue
Write-S3Object -BucketName "${tfi_s3_bucket}" -Folder "C:\\Program Files\\Amazon\\Ec2ConfigService\\Logs" -KeyPrefix $ArtifactPrefix/cloud/ -ErrorAction SilentlyContinue
Write-S3Object -BucketName "${tfi_s3_bucket}" -Folder "C:\\ProgramData\\Amazon\\EC2-Windows\\Launch\\Log" -KeyPrefix $ArtifactPrefix/cloud/ -ErrorAction SilentlyContinue
Write-S3Object -BucketName "${tfi_s3_bucket}" -Folder "C:\\Watchmaker\\Logs" -KeyPrefix $ArtifactPrefix/watchmaker/ -SearchPattern *.log -ErrorAction SilentlyContinue
Write-S3Object -BucketName "${tfi_s3_bucket}" -Folder "C:\\Watchmaker\\SCAP\\Results" -KeyPrefix $ArtifactPrefix/scap_output/ -ErrorAction SilentlyContinue

Start-Process -FilePath "winrm" -ArgumentList "set winrm/config @{MaxTimeoutms=`"1900000`"}"
</powershell>
