
# functions, vars in common between builder and normal userdata

# global vars
$BuildSlug = "${tfi_build_slug}"
$ErrorSignalFile = "${tfi_error_signal_file}"
$RMUser = "${tfi_rm_user}"
$PypiUrl = "${tfi_pypi_url}"

# log file
$UserdataLogFile = "${tfi_userdata_log}"
If(-not (Test-Path "$UserdataLogFile"))
{
  New-Item "$UserdataLogFile" -ItemType "file" -Force
}

# directory needed by logs and for various other purposes
$TempDir = "${tfi_temp_dir}"
If(-not (Test-Path "$TempDir"))
{
  New-Item "$TempDir" -ItemType "directory" -Force
}
cd $TempDir

function Write-Tfi
## Writes messages to a Terrafirm log file. If a second parameter is included,
## it will display success/failure outcome.
{

  Param
  (
    [String]$Msg,
    $Success = $null
  )

  # result is succeeded or failed or nothing if success is null
  If( $Success -ne $null )
  {
    If ($Success)
    {
      $OutResult = ": Succeeded"
    }
    Else
    {
      $OutResult = ": Failed"
    }
  }

  "$(Get-Date): $Msg $OutResult" | Out-File "$UserdataLogFile" -Append -Encoding utf8
}

function Test-Command
## Tests commands and handles errors that result. Can also re-try commands if
## -Tries is set > 1.
{
  #
  Param (
    [Parameter(Mandatory=$true)][string]$Test,
    [Parameter(Mandatory=$false)][int]$Tries = 1,
    [Parameter(Mandatory=$false)][int]$SecondsDelay = 2
  )
  $TryCount = 0
  $Completed = $false
  $MsgFailed = "Command [{0}] failed" -f $Test
  $MsgSucceeded = "Command [{0}] succeeded." -f $Test

  While (-not $Completed)
  {
    Try
    {
      $Result = @{}
      # Invokes commands and in the same context captures the $? and $LastExitCode
      Invoke-Expression -Command ($Test+';$Result = @{ Success = $?; ExitCode = $LastExitCode }')
      If (($False -eq $Result.Success) -Or ((($Result.ExitCode) -ne $null) -And (0 -ne ($Result.ExitCode)) ))
      {
        Throw $MsgFailed
      }
      Else
      {
        Write-Tfi $MsgSucceeded
        $Completed = $true
      }
    }
    Catch
    {
      $TryCount++
      If ($TryCount -ge $Tries)
      {
        $Completed = $true
        $ErrorMessage = [String]$_.Exception + "Invocation Info: " + ($PSItem.InvocationInfo | Format-List * | Out-String)
        Write-Tfi $ErrorMessage
        Write-Tfi ("Command [{0}] failed the maximum number of {1} time(s)." -f $Test, $Tries)
        Write-Tfi ("Error code (if available): {0}" -f ($Result.ExitCode))
        Throw ("Command [{0}] failed" -f $Test)
      }
      Else
      {
        Write-Tfi ("Command [{0}] failed. Retrying in {1} second(s)." -f $Test, $SecondsDelay)
        Start-Sleep $SecondsDelay
      }
    }
  }
}

function Publish-Artifacts
## Uploads various useful files to s3 relative to the test/build.
{
  $ErrorActionPreference = "Continue"

  # create a directory with all the build artifacts
  $ArtifactDir = "$TempDir\build-artifacts"
  Invoke-Expression -Command "mkdir $ArtifactDir" -ErrorAction SilentlyContinue
  Invoke-Expression -Command "mkdir $ArtifactDir\watchmaker" -ErrorAction SilentlyContinue # need to create dir if globbing to it
  Copy-Item "C:\Watchmaker\Logs\*log" -Destination "$ArtifactDir\watchmaker" -Recurse -Force
  Copy-Item "C:\Watchmaker\SCAP\Results" -Destination "$ArtifactDir\scap_output" -Recurse -Force
  Copy-Item "C:\Watchmaker\SCAP\Logs" -Destination "$ArtifactDir\scap_logs" -Recurse -Force
  Copy-Item "C:\ProgramData\Amazon\EC2-Windows\Launch\Log" -Destination "$ArtifactDir\cloud" -Recurse -Force
  Copy-Item "C:\Program Files\Amazon\Ec2ConfigService\Logs" -Destination "$ArtifactDir\cloud" -Recurse -Force
  Copy-Item "C:\Windows\TEMP\*.tmp" -Destination "$ArtifactDir\cloud" -Recurse -Force
  Copy-Item "C:\Program Files\Amazon\Ec2ConfigService\Scripts\User*ps1" -Destination "$ArtifactDir\cloud" -Recurse -Force
  Get-ChildItem Env: | Out-File "$ArtifactDir\cloud\environment_variables.log" -Append -Encoding utf8

  # copy artifacts to s3
  Write-Tfi "Writing logs to $BuildSlug/$IndexStr$AMIKey"
  Copy-Item $UserdataLogFile -Destination "$ArtifactDir" -Force
  Write-S3Object -BucketName "$BuildSlug" -KeyPrefix "$IndexStr$AMIKey" -Folder "$ArtifactDir" -Recurse

  # creates compressed archive to upload to s3
  $BuildSlugZipName = "$BuildSlug" -replace '/','-'
  $ZipFile = "$TempDir\$BuildSlugZipName-$IndexStr$AMIKey.zip"
  cd 'C:\Program Files\7-Zip'
  Test-Command ".\7z a -y -tzip $ZipFile -r $ArtifactDir\*"
  Write-S3Object -BucketName "$BuildSlug" -File $ZipFile
}

function Test-DisplayResult
## For some situations, Test-Command is not an option because, for instance,
## several commands need to share an environment. In that case, after a
## command, this function can be called with $? to log the outcome and throw
## errors.
{
  Param
  (
    [String]$Msg,
    $Success = $null
  )

  Write-Tfi $Msg $Success
  If (-not $Success)
  {
    throw "$Msg : FAILED"
  }
}

function Debug-2S3
## With as few dependencies as possible, immediately upload the debug and log
## files to S3. Calling this multiple times will simply overwrite the
## previously uploaded logs.
{
  Param
  (
    [Parameter(Mandatory=$false)][string]$Msg
  )

  $DebugFile = "$TempDir\debug.log"
  "$(Get-Date): $Msg" | Out-File $DebugFile -Append -Encoding utf8
  Write-S3Object -BucketName "$BuildSlug/$IndexStr$AMIKey" -File $DebugFile
  Write-S3Object -BucketName "$BuildSlug/$IndexStr$AMIKey" -File $UserdataLogFile
}

function Write-UserdataStatus
## Write a file to the local system that can be read by other processes (e.g.,
## the test process) to indicate the outcome of the userdata script.
{
  Param
  (
    [Parameter(Mandatory=$true)]$UserdataStatus
  )

  # write the status to a file for reading by test script
  $UserdataStatus | Out-File "${tfi_userdata_status_file}"
  Write-Tfi "Write userdata status file" $?
}

function Open-WinRM
## Open WinRM for access by, for example, a Terraform remote-exec provisioner.
{
  # initial winrm setup
  Start-Process -FilePath "winrm" -ArgumentList "quickconfig -q"
  Write-Tfi "WinRM quickconfig" $?
  Start-Process -FilePath "winrm" -ArgumentList "set winrm/config/service @{AllowUnencrypted=`"true`"}" -Wait
  Write-Tfi "Open winrm/unencrypted" $?
  Start-Process -FilePath "winrm" -ArgumentList "set winrm/config/service/auth @{Basic=`"true`"}" -Wait
  Write-Tfi "Open winrm/auth/basic" $?
  Start-Process -FilePath "winrm" -ArgumentList "set winrm/config @{MaxTimeoutms=`"1900000`"}"
  Write-Tfi "Set winrm timeout" $?
}

function Close-Firewall
## Close the local firewall to WinRM traffic. Useful for preventing, for
## example, a Terraform remote-exec provisioner from connecting before the
## userdata script has finished.
{
  # close the firewall
  netsh advfirewall firewall add rule name="WinRM in" protocol=tcp dir=in profile=any localport=5985 remoteip=any localip=any action=block
  Write-Tfi "Close firewall" $?
}

function Open-Firewall
## Open the local firewall to WinRM traffic.
{
  # open firewall for winrm - rule was added previously, now we modify it with "set"
  netsh advfirewall firewall set rule name="WinRM in" new action=allow
  Write-Tfi "Open firewall" $?
}

function Rename-User
## Renames a system username.
{
  Param
  (
    [Parameter(Mandatory=$true)][string]$From,
    [Parameter(Mandatory=$true)][string]$To
  )

  $Admin = [adsi]("WinNT://./$From, user")
  If ($Admin.Name)
  {
    $Admin.psbase.rename("$To")
    Write-Tfi "Rename $From account to $To" $?
  }
}

function Set-Password
## Changes a system user's password.
{
  Param
  (
    [Parameter(Mandatory=$true)][string]$User,
    [Parameter(Mandatory=$true)][string]$Pass
  )
  # Set Administrator password, for logging in before wam changes Administrator account name
  $Admin = [adsi]("WinNT://./$User, user")
  If ($Admin.Name)
  {
    $Admin.psbase.invoke("SetPassword", $Pass)
    Write-Tfi "Set $User password" $?
  }
  Else
  {
    Write-Tfi "Unable to set password because user ($User) was not found."
  }
  
}

function Invoke-CmdScript
## Invoke the specified batch file (and parameters), but also propagate any
## environment variable changes back to the PowerShell environment that
## called it.
##
## Recipe from "Windows PowerShell Cookbook by Lee Holmes"
## https://www.safaribooksonline.com/library/view/windows-powershell-cookbook/9780596528492/ch01s09.html
{

  Param
  (
    [string] $script,
    [string] $parameters
  )

  $tempFile = [IO.Path]::GetTempFileName()

  ## Store the output of cmd.exe. We also ask cmd.exe to output
  ## the environment table after the batch file completes
  cmd /c " `"$script`" $parameters && set > `"$tempFile`" "

  ## Go through the environment variables in the temp file.
  ## For each of them, set the variable in our local environment.
  Get-Content $tempFile | Foreach-Object {
      if($_ -match "^(.*?)=(.*)$")
      {
          Set-Content "env:\$($matches[1])" $matches[2]
      }
  }

  Remove-Item $tempFile
}

function Install-PythonGit
## Use the Watchmaker bootstrap to install Python and Git.
{

  $BootstrapUrl = "${tfi_bootstrap_url}"
  $PythonUrl = "${tfi_python_url}"
  $GitUrl = "${tfi_git_url}"

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
}

function Install-Watchmaker
{
  Param
  (
    [Parameter(Mandatory=$false)][bool]$UseVenv=$false
  )

  $GitRepo = "${tfi_git_repo}"
  $GitRef = "${tfi_git_ref}"

  # Upgrade pip and setuptools
  $Stage = "upgrade pip setuptools boto3"
  Test-Command "python -m pip install --index-url=`"$PypiUrl`" --upgrade pip setuptools" -Tries 2
  #Test-Command "python -m ensurepip --index-url=`"$PypiUrl`"" -Tries 2
  #Test-Command "python -m pip install -U pip --index-url=`"$PypiUrl`"" -Tries 2

  Test-Command "pip install --index-url=`"$PypiUrl`" --upgrade boto3" -Tries 2

  If($UseVenv)
  {
    $Stage = "install virtualenv wheel"
    Test-Command "pip install virtualenv wheel"

    # ----- build the standalone binary
    # use a virtual env
    $Stage = "virtualenv"
    $VirtualEnvDir = "C:\venv"
    mkdir $VirtualEnvDir
    Test-DisplayResult "Create virtualenv directory" $?

    Test-Command "virtualenv $VirtualEnvDir"
    Invoke-CmdScript "$VirtualEnvDir\Scripts\activate.bat"
    Test-DisplayResult "Activate virtualenv" $?
  }

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
}

$ErrorActionPreference = "Stop"

Write-Tfi "AMI KEY: ----------------------------- $IndexStr$AMIKey ---------------------"

Set-Password -User "Administrator" -Pass "${tfi_rm_pass}"

Close-Firewall

# declare an array to hold the status (number and message)
$UserdataStatus=@(1,"Error: Build not completed (should never see this error)")

# Use TLS, as git won't do SSL now
[Net.ServicePointManager]::SecurityProtocol = "Ssl3, Tls, Tls11, Tls12"

# install 7-zip for use with artifacts - download fails after wam install, fyi
(New-Object System.Net.WebClient).DownloadFile("${tfi_7zip_url}", "$TempDir\7z-install.exe")
Invoke-Expression -Command "$TempDir\7z-install.exe /S /D='C:\Program Files\7-Zip'" -ErrorAction Continue
