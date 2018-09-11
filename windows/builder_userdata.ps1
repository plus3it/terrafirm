
Try {

  Write-Tfi "Start build"

  # time wam install
  $StartDate=Get-Date

  # ---------- begin of wam standalone package build ----------
  Install-PythonGit

  Install-Watchmaker -UseVenv $true

  # Install prereqs
  $Stage = "install boto3"
  
  pip install --index-url="$PypiUrl" -r requirements\build.txt
  Test-DisplayResult "Install build prerequisites" $?

  # create standalone application
  gravitybee --src-dir src --sha file --with-latest --extra-data static --verbose --extra-pkgs boto3 --extra-modules boto3
  Test-DisplayResult "Run gravitybee (build standalone)" $?

  Invoke-CmdScript .\.gravitybee\gravitybee-environs.bat
  Test-DisplayResult "Set environment variables" $?

  If ($env:GB_ENV_STAGING_DIR)
  {
    Remove-Item ".\$env:GB_ENV_STAGING_DIR\0*" -Recurse
    Write-S3Object -BucketName "$BuildSlug" -KeyPrefix "${tfi_release_prefix}" -Folder ".\$env:GB_ENV_STAGING_DIR" -Recurse
    Test-DisplayResult "Copy standalone to $ArtifactDest" $?
  }

  # ----------  end of wam standalone package build ----------

  $EndDate = Get-Date
  Write-Tfi("WAM standalone build took {0} seconds." -f [math]::Round(($EndDate - $StartDate).TotalSeconds))
  Write-Tfi("End build")
  $UserdataStatus=@(0,"Success") # made it this far, it's a success
}
Catch
{
  $ErrorMessage = [String]$_.Exception + "Invocation Info: " + ($PSItem.InvocationInfo | Format-List * | Out-String)
  Write-Tfi ("*** ERROR caught ($Stage) ***")
  Write-Tfi $ErrorMessage
  Debug-2S3 $ErrorMessage

  # signal any instances waiting to test this standalone that the build failed
  If(-not (Test-Path "$ErrorSignalFile"))
  {
    New-Item "$ErrorSignalFile" -ItemType "file" -Force
  }
  $Msg = "$ErrorMessage (For more information on the error, see the win_builder/userdata.log file.)"
  "$(Get-Date): $Msg" | Out-File "$ErrorSignalFile" -Append -Encoding utf8
  Write-S3Object -BucketName "$BuildSlug/${tfi_release_prefix}" -File $ErrorSignalFile
  Write-Tfi "Signal error to S3" $?

  # setup userdata status for passing to the test script via a file
  $ErrCode = 1  # trying to set this to $lastExitCode does not work (always get 0)
  $UserdataStatus=@($ErrCode,"Error at: " + $Stage + " [$ErrorMessage]")
}

Rename-User -From "Administrator" -To "$RMUser"

Open-WinRM

Write-UserdataStatus -UserdataStatus $UserdataStatus

Open-Firewall

Publish-Artifacts
