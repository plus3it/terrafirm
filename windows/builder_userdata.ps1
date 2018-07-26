Try {

  Write-Tfi "Start build"

  # time wam install
  $StartDate=Get-Date

  # ---------- begin of wam standalone package build ----------
  Install-PythonGit

  Install-Watchmaker -UseVenv $true

  <#$GitRepo = "$${tfi_git_repo}"
  $GitRef = "$${tfi_git_ref}"

  # Upgrade pip and setuptools
  $Stage = "upgrade pip setuptools"
  python -m ensurepip
  python -m pip install -U pip
  #Test-Command "python -m pip install --index-url=`"$PypiUrl`" --upgrade pip setuptools" -Tries 2
  Test-DisplayResult "Upgrade pip" $?

  $Stage = "install virtualenv wheel"
  pip install virtualenv wheel
  Test-DisplayResult "Install virtualenv, wheel" $?

  # ----- build the standalone binary
  # use a virtual env
  $Stage = "virtualenv"
  $VirtualEnvDir = "C:\venv"
  mkdir $VirtualEnvDir
  Test-DisplayResult "Create virtualenv directory" $?

  virtualenv $VirtualEnvDir
  Invoke-CmdScript "$VirtualEnvDir\Scripts\activate.bat"
  Test-DisplayResult "Activate virtualenv" $?

  python --version
  Test-DisplayResult "Check Python version" $?

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
  pip install --index-url "$PypiUrl" --editable .
  Test-DisplayResult "Install watchmaker" $? #>

  # Install prereqs
  $Stage = "install boto3"
  
  pip install --index-url="$PypiUrl" -r requirements\deploy.txt
  Test-DisplayResult "Install prerequisites" $?

  # create standalone application
  gravitybee --src-dir src --sha file --with-latest --extra-data static --verbose --extra-pkgs boto3 --extra-modules boto3
  Test-DisplayResult "Run gravitybee (build standalone)" $?

  Invoke-CmdScript .\.gravitybee\gravitybee-environs.bat
  Test-DisplayResult "Set environment variables" $?

  If ($env:GB_ENV_STAGING_DIR)
  {
    Remove-Item ".\$env:GB_ENV_STAGING_DIR\0*" -Recurse
    Write-S3Object -BucketName "${tfi_s3_bucket}" -KeyPrefix "${tfi_build_date}/${tfi_build_hour}_${tfi_build_id}/release" -Folder ".\$env:GB_ENV_STAGING_DIR" -Recurse
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
  $SignalFile = "error.log"
  $Msg = "$ErrorMessage (For more information on the error, see the win_builder/userdata.log file.)"
  "$(Get-Date): $Msg" | Out-File "$SignalFile" -Append -Encoding utf8
  Write-S3Object -BucketName "${tfi_s3_bucket}/${tfi_build_date}/${tfi_build_hour}_${tfi_build_id}/release" -File $SignalFile
  Write-Tfi "Signal error to S3" $?

  # setup userdata status for passing to the test script via a file
  $ErrCode = 1  # trying to set this to $lastExitCode does not work (always get 0)
  $UserdataStatus=@($ErrCode,"Error at: " + $Stage + " [$ErrorMessage]")
}

Rename-User -From "Administrator" -To "${tfi_rm_user}"

Open-WinRM

Write-UserdataStatus -UserdataStatus $UserdataStatus

Open-Firewall

Publish-Artifacts
