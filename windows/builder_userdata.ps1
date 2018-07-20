Rename-User -From "Administrator" -To "${tfi_rm_user}"
Set-Password -User "${tfi_rm_user}" -Pass "${tfi_rm_pass}"

Close-Firewall

# declare an array to hold the status (number and message)
$UserdataStatus=@(1,"Error: Build not completed (should never see this error)")

# Use TLS, as git won't do SSL now
[Net.ServicePointManager]::SecurityProtocol = "Ssl3, Tls, Tls11, Tls12"

# install 7-zip for use with artifacts - download fails after wam install, fyi
(New-Object System.Net.WebClient).DownloadFile("https://www.7-zip.org/a/7z1805-x64.exe", "$TempDir\7z-install.exe")
Invoke-Expression -Command "$TempDir\7z-install.exe /S /D='C:\Program Files\7-Zip'" -ErrorAction Continue

Try {

  Write-Tfi "Start build"

  # time wam install
  $StartDate=Get-Date

  # ---------- begin of wam standalone package build ----------
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
  Test-DisplayResult "Install Python/Git" $?

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

  # Install prereqs
  $Stage = "install boto3"
  pip install --index-url="$PypiUrl" --upgrade boto3
  pip install --index-url="$PypiUrl" -r requirements\deploy.txt
  Test-DisplayResult "Install prerequisites" $?

  # Install watchmaker
  $Stage = "install wam"
  pip install --index-url "$PypiUrl" --editable .
  Test-DisplayResult "Install watchmaker" $?

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

Open-WinRM

Write-UserdataStatus -UserdataStatus $UserdataStatus

Open-Firewall

Publish-Artifacts
