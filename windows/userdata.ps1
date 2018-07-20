# Set Administrator password, for logging in before wam changes Administrator account name
Set-Password -User "Administrator" -Pass "${tfi_rm_pass}"

Close-Firewall

# declare an array to hold the status (number and message)
$UserdataStatus=@(1,"Error: Install not completed (should never see this error)")

# ensure TLS is priority
[Net.ServicePointManager]::SecurityProtocol = "Ssl3, Tls, Tls11, Tls12"

# install 7-zip for use with artifacts - download fails after wam install
(New-Object System.Net.WebClient).DownloadFile("https://www.7-zip.org/a/7z1805-x64.exe", "$TempDir\7z-install.exe")
Invoke-Expression -Command "$TempDir\7z-install.exe /S /D='C:\Program Files\7-Zip'" -ErrorAction Continue

Try {

  Write-Tfi "Start install"

  # time wam install
  $StartDate=Get-Date

  If ($AMIKey.EndsWith("pkg")) {
    Write-Tfi "Installing Watchmaker from standalone executable package............."

    # if it ends with 'pkg', test standalone
    $SleepTime=20
    $StandaloneKey = "${tfi_build_date}/${tfi_build_hour}_${tfi_build_id}/release/latest/watchmaker-latest-standalone-windows-amd64.exe"
    $ErrorKey = "${tfi_build_date}/${tfi_build_hour}_${tfi_build_id}/release/error.log"

    Write-Tfi "Looking for standalone executable at ${tfi_s3_bucket}/$StandaloneKey"

    #block until executable exists, an error, or timeout
    While($true)
    {
      # find out what's happening with the builder
      $Exists = $true
      $SignaledError = $true

      # see if the standalone is ready yet
      Try
      {
        Get-S3ObjectMetadata -BucketName "${tfi_s3_bucket}" -Key "$StandaloneKey"
      }
      Catch
      {
        $Exists = $false
      }

      # see if the builder encountered an error
      Try
      {
        Get-S3ObjectMetadata -BucketName "${tfi_s3_bucket}" -Key "$ErrorKey"
      }
      Catch
      {
        $SignaledError = $false
      }

      If($SignaledError)
      {
        # error signaled by the builder
        Write-Tfi "Error signaled by the builder"
        Write-Tfi "Error file found at ${tfi_s3_bucket}/$ErrorKey"
        $PSCmdlet.ThrowTerminatingError($PSItem)
        break
      }
      Else
      {
        If($Exists)
        {
          Write-Tfi "The standalone executable was found!"
          Break
        }
        Else
        {
          Write-Tfi "The standalone executable was not found. Trying again in $SleepTime s..."
          Start-Sleep -Seconds $SleepTime
        }
      }

    } # end of While($true)

    Invoke-Expression -Command "mkdir C:\scripts" -ErrorAction SilentlyContinue
    Read-S3Object -BucketName "${tfi_s3_bucket}" -Key "$StandaloneKey" -File "C:\scripts\watchmaker.exe"
    Test-Command "C:\scripts\watchmaker.exe ${tfi_common_args} ${tfi_win_args}"
  }
  Else {
    # ---------- begin of wam install ----------
    Write-Tfi "Installing Watchmaker from source...................................."

    $GitRepo = "${tfi_git_repo}"
    $GitRef = "${tfi_git_ref}"

    $BootstrapUrl = "https://raw.githubusercontent.com/plus3it/watchmaker/develop/docs/files/bootstrap/watchmaker-bootstrap.ps1"
    $PythonUrl = "https://www.python.org/ftp/python/3.6.5/python-3.6.5-amd64.exe"
    $GitUrl = "https://github.com/git-for-windows/git/releases/download/v2.18.0.windows.1/Git-2.18.0-64-bit.exe"
    $PypiUrl = "https://pypi.org/simple"

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

    # Upgrade pip and setuptools
    $Stage = "upgrade pip setuptools boto3"
    Test-Command "python -m pip install --index-url=`"$PypiUrl`" --upgrade pip setuptools" -Tries 2

    # Install boto3
    $Stage = "install boto3"
    Test-Command "pip install --index-url=`"$PypiUrl`" --upgrade boto3" -Tries 2

    # Clone watchmaker
    $Stage = "git"
    Test-Command "git clone `"$GitRepo`" --recursive" -Tries 2
    cd watchmaker
    If ($GitRef)
    {
      # decide whether to switch to pull request or branch
      If($GitRef -match "^[0-9]+$")
      {
        Test-Command "git fetch origin pull/$GitRef/head:pr-$GitRef" -Tries 2
        Test-Command "git checkout pr-$GitRef"
      }
      Else
      {
        Test-Command "git checkout $GitRef"
      }
    }

    # Update submodule refs
    $Stage = "update submodules"
    Test-Command "git submodule update"

    # Install watchmaker
    $Stage = "install wam"
    Test-Command "pip install --index-url `"$PypiUrl`" --editable ."

    # Run watchmaker
    $Stage = "run wam"
    Test-Command "watchmaker ${tfi_common_args} ${tfi_win_args}"
    # ----------  end of wam install ----------
  }

  $EndDate = Get-Date
  Write-Tfi ("WAM install took {0} seconds." -f [math]::Round(($EndDate - $StartDate).TotalSeconds))
  Write-Tfi "End install"

  $UserdataStatus=@(0,"Success") # made it this far, it's a success
}
Catch
{
  $ErrorMessage = [String]$_.Exception + "Invocation Info: " + ($PSItem.InvocationInfo | Format-List * | Out-String)
  Write-Tfi ("*** ERROR caught ($Stage) ***")
  Write-Tfi $ErrorMessage
  Debug-2S3 $ErrorMessage

  # setup userdata status for passing to the test script via a file
  $ErrCode = 1  # trying to set this to $lastExitCode does not work (always get 0)
  $UserdataStatus=@($ErrCode,"Error at: " + $Stage + " [$ErrorMessage]")
}

# in case wam didn't change admin account name, winrm won't be able to log in so make sure
Rename-User -From "Administrator" -To "${tfi_rm_user}"

# Set Administrator password - should always go after wm install because username not yet changed
Set-Password -User "${tfi_rm_user}" -Pass "${tfi_rm_pass}"

# Open-WinRM won't work if lgpo is blocking, but we'll have salt in that case
Open-WinRM

If (Test-Path -path "C:\salt\salt-call.bat")
{
  # fix the lgpos to allow winrm
  C:\salt\salt-call --local -c C:\Watchmaker\salt\conf lgpo.set_reg_value `
    key='HKLM\SOFTWARE\Policies\Microsoft\Windows\WinRM\Service\AllowBasic' `
    value='1' `
    vtype='REG_DWORD'
  Write-Tfi "Salt modify lgpo, allow basic" $?

  C:\salt\salt-call --local -c C:\Watchmaker\salt\conf lgpo.set_reg_value `
    key='HKLM\SOFTWARE\Policies\Microsoft\Windows\WinRM\Service\AllowUnencryptedTraffic' `
    value='1' `
    vtype='REG_DWORD'
  Write-Tfi "Salt modify lgpo, unencrypted" $?
}

Write-UserdataStatus -UserdataStatus $UserdataStatus

Open-Firewall
Publish-Artifacts
