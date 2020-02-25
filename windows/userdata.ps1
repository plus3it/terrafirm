
Check-Metadata-Availability

Try {

  Write-Tfi "Start install"

  # time wam install
  $StartDate=Get-Date

  If ($AMIKey.EndsWith("pkg")) {
    Write-Tfi "Installing Watchmaker from standalone executable package............."

    # if it ends with 'pkg', test standalone
    $SleepTime=20
    $Standalone = "${tfi_executable}"
    $ErrorKey = $ErrorSignalFile

    Write-Tfi "Looking for standalone executable at $BuildSlug/$Standalone"
    Write-Tfi "Looking for error signal at $BuildSlug/$ErrorKey"

    #block until executable exists, an error, or timeout
    While($true)
    {
      # find out what's happening with the builder
      $Exists = $true
      $SignaledError = $true

      # see if the standalone is ready yet
      Try
      {
        Get-S3ObjectMetadata -BucketName "$BuildSlug" -Key "$Standalone"
      }
      Catch
      {
        $Exists = $false
      }

      # see if the builder encountered an error
      Try
      {
        Get-S3ObjectMetadata -BucketName "$BuildSlug" -Key "$ErrorKey"
      }
      Catch
      {
        $SignaledError = $false
      }

      If($SignaledError)
      {
        # error signaled by the builder
        $ErrorMsg = "Error signaled by the builder (Error file found at $BuildSlug/$ErrorKey)"
        Write-Tfi $ErrorMsg
        Throw $ErrorMsg
        Break
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

    #Invoke-Expression -Command "mkdir C:\scripts" -ErrorAction SilentlyContinue
    $DownloadDir = "${tfi_download_dir}"
    Read-S3Object -BucketName "$BuildSlug" -Key $Standalone -File "$DownloadDir\watchmaker.exe"
    Test-Command "$DownloadDir\watchmaker.exe ${tfi_common_args} ${tfi_win_args}"
  }
  Else {
    # ---------- begin of wam install ----------
    Write-Tfi "Installing Watchmaker from source...................................."

    Install-PythonGit
    Install-Watchmaker

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
Rename-User -From "Administrator" -To "$RMUser"

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
