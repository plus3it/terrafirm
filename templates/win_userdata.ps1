$BuildOS = "${build_os}"
$BuildType = "${build_type}"
$BuildLabel = "${build_label}"
$BuildTypeStandalone = "${build_type_standalone}"
$BuildTypeSource = "${build_type_source}"

$BuildSlug = "${build_slug}"
$BuildSlugParts = $BuildSlug -Split "/"
$BuildBucket = $BuildSlugParts[0]
$BuildKeyPrefix = $BuildSlugParts[1..($BuildSlugParts.Length - 1)] -Join "/"
$StandaloneErrorSignalFile = "${standalone_error_signal_file}"
$WinUser = "${user}"
$PypiUrl = "${url_pypi}"
$DebugMode = "${debug}"

Set-DefaultAWSRegion -Region "${aws_region}"
$Env:AWS_DEFAULT_REGION = "${aws_region}"

$UserdataLogFile = "${userdata_log}"
$UserdataLogFileName = Split-Path $UserdataLogFile -Leaf
if (-not (Test-Path "$UserdataLogFile")) {
  New-Item "$UserdataLogFile" -ItemType "file" -Force
}

$TempDir = "${temp_dir}"
if (-not (Test-Path "$TempDir")) {
  New-Item "$TempDir" -ItemType "directory" -Force
}
cd $TempDir

function Debug-2S3 {
  param ([string]$Msg)

  $DebugFileName = "debug.log"
  $DebugFile = "$TempDir\$DebugFileName"
  "$(Get-Date): $Msg" | Out-File $DebugFile -Append -Encoding utf8
  Write-S3Object -BucketName "$BuildBucket" -Key "$${BuildKeyPrefix}/$${BuildLabel}/$${DebugFileName}" -File "$DebugFile"
  Write-S3Object -BucketName "$BuildBucket" -Key "$${BuildKeyPrefix}/$${BuildLabel}/$${UserdataLogFileName}" -File "$UserdataLogFile"
}

function Check-Metadata {
  $MetadataLoopbackAZ = "http://169.254.169.254/latest/meta-data/placement/availability-zone"
  $MetadataCommand = "Invoke-WebRequest -Uri $MetadataLoopbackAZ -UseBasicParsing | Select-Object -ExpandProperty Content"

  Test-Command $MetadataCommand 50

  Invoke-Expression -Command $MetadataCommand -OutVariable availability_zone
  Write-Tfi "Connect to EC2 metadata (Availability zone is $availability_zone)" $?
}

function Write-Tfi {
  param (
    [String]$Msg,
    $Success = $null
  )

  if ( $Success -ne $null ) {
    if ($Success) {
      $OutResult = ": Succeeded"
    }
    else {
      $OutResult = ": Failed"
    }
  }

  "$(Get-Date): $Msg $OutResult" | Out-File "$UserdataLogFile" -Append -Encoding utf8

  if ("$DebugMode" -ne "false" ) {
    Debug-2S3 "$Msg $OutResult"
  }
}

function Test-Command {
  param (
    [Parameter(Mandatory = $true)][string]$Test,
    [Parameter(Mandatory = $false)][int]$Tries = 1,
    [Parameter(Mandatory = $false)][int]$SecondsDelay = 2
  )
  $TryCount = 0
  $Completed = $false
  $MsgFailed = "Command [{0}] failed" -f $Test
  $MsgSucceeded = "Command [{0}] succeeded." -f $Test

  while (-not $Completed) {
    try {
      $Result = @{}
      # Invokes command and captures the $? and $LastExitCode
      Invoke-Expression -Command ($Test + ';$Result = @{ Success = $?; ExitCode = $LastExitCode }')
      if (($False -eq $Result.Success) -Or ((($Result.ExitCode) -ne $null) -And (0 -ne ($Result.ExitCode)) )) {
        throw $MsgFailed
      }
      else {
        Write-Tfi $MsgSucceeded
        $Completed = $true
      }
    }
    catch {
      $TryCount++
      if ($TryCount -ge $Tries) {
        $Completed = $true
        $ErrorMessage = [String]$_.Exception + "Invocation Info: " + ($PSItem.InvocationInfo | Format-List * | Out-String)
        Write-Tfi $ErrorMessage
        Write-Tfi ("Command [{0}] failed the maximum number of {1} time(s)." -f $Test, $Tries)
        Write-Tfi ("Error code (if available): {0}" -f ($Result.ExitCode))
        throw ("Command [{0}] failed" -f $Test)
      }
      else {
        Write-Tfi ("Command [{0}] failed. Retrying in {1} second(s)." -f $Test, $SecondsDelay)
        Start-Sleep $SecondsDelay
      }
    }
  }
}

function Publish-Artifacts {
  ## Upload files to s3 related to the build
  $ErrorActionPreference = "Continue"
  $ArtifactDir = "$TempDir\build-artifacts"
  Invoke-Expression -Command "mkdir $ArtifactDir" -ErrorAction SilentlyContinue

  # Watchmaker logs and SCAP results
  Invoke-Expression -Command "mkdir $ArtifactDir\watchmaker" -ErrorAction SilentlyContinue
  Copy-Item "C:\Watchmaker\Logs\*log" -Destination "$ArtifactDir\watchmaker" -Recurse -Force
  Copy-Item "C:\Watchmaker\SCAP" -Destination "$ArtifactDir\scap" -Recurse -Force

  # AWS EC2 Launch mechanisms (userdata execution logs)
  Copy-Item "C:\ProgramData\Amazon\EC2Launch\Log" -Destination "$ArtifactDir\ec2launchv2" -Recurse -Force
  Copy-Item "C:\ProgramData\Amazon\EC2-Windows\Launch\Log" -Destination "$ArtifactDir\ec2launch" -Recurse -Force
  Copy-Item "C:\Program Files\Amazon\Ec2ConfigService\Logs" -Destination "$ArtifactDir\ec2config" -Recurse -Force

  # AWS Systems Manager logs
  Copy-Item "C:\ProgramData\Amazon\SSM\Logs" -Destination "$ArtifactDir\ssm" -Recurse -Force

  # CloudFormation logs (cfn-init, cfn-hup, cfn-signal)
  Copy-Item "C:\cfn\log" -Destination "$ArtifactDir\cfn" -Recurse -Force

  # Windows Event Logs (Application, System, Security for troubleshooting)
  Invoke-Expression -Command "mkdir $ArtifactDir\eventlogs" -ErrorAction SilentlyContinue
  wevtutil epl Application "$ArtifactDir\eventlogs\Application.evtx"
  wevtutil epl System "$ArtifactDir\eventlogs\System.evtx"
  wevtutil epl Security "$ArtifactDir\eventlogs\Security.evtx"
  wevtutil epl "Microsoft-Windows-PowerShell/Operational" "$ArtifactDir\eventlogs\PowerShell-Operational.evtx"

  # Userdata execution artifacts
  Invoke-Expression -Command "mkdir $ArtifactDir\cloud" -ErrorAction SilentlyContinue
  Copy-Item "C:\Windows\TEMP\*.tmp" -Destination "$ArtifactDir\cloud" -Recurse -Force
  Copy-Item "C:\Program Files\Amazon\Ec2ConfigService\Scripts\User*ps1" -Destination "$ArtifactDir\cloud" -Recurse -Force
  Copy-Item "C:\Windows\Temp\UserScript.ps1" -Destination "$ArtifactDir\cloud\UserScript.ps1" -Recurse -Force
  Copy-Item "C:\Windows\system32\config\systemprofile\AppData\Local\Temp\EC2Launch*" -Destination "$ArtifactDir\cloud\" -Recurse -Force

  # System information for troubleshooting
  Get-ChildItem Env: | Out-File "$ArtifactDir\sys\environment_variables.log" -Append -Encoding utf8
  systeminfo | Out-File "$ArtifactDir\sys\systeminfo.log" -Encoding utf8
  Get-ComputerInfo | Out-File "$ArtifactDir\sys\computerinfo.log" -Encoding utf8
  Get-HotFix | Out-File "$ArtifactDir\sys\hotfixes.log" -Encoding utf8

  # Network configuration for connectivity troubleshooting
  ipconfig /all | Out-File "$ArtifactDir\sys\ipconfig.log" -Encoding utf8
  route print | Out-File "$ArtifactDir\sys\routes.log" -Encoding utf8

  # PowerShell execution policy and version info
  Get-ExecutionPolicy -List | Out-File "$ArtifactDir\sys\execution_policy.log" -Encoding utf8
  $PSVersionTable | Out-File "$ArtifactDir\sys\powershell_version.log" -Encoding utf8

  Copy-Item $UserdataLogFile -Destination "$ArtifactDir" -Force
  Write-S3Object -BucketName "$BuildBucket" -KeyPrefix "$${BuildKeyPrefix}/$${BuildLabel}" -Folder "$ArtifactDir" -Recurse
  Write-Tfi "Wrote logs to s3://$${BuildBucket}/$${BuildKeyPrefix}/$${BuildLabel}" $?

  $BuildSlugZipName = "$BuildSlug" -replace '/', '-'
  $ZipFile = "$${TempDir}\$${BuildSlugZipName}-$${BuildLabel}.zip"
  $ZipFileName = Split-Path $ZipFile -Leaf
  cd 'C:\Program Files\7-Zip'
  Test-Command ".\7z a -y -tzip $ZipFile -r $ArtifactDir\*"
  Write-S3Object -BucketName "$BuildBucket" -Key "$${BuildKeyPrefix}/$${ZipFileName}" -File "$ZipFile"
}

function Publish-SCAP-Scan {
  $ScanSlug = "${scan_slug}".trimstart("s3://")
  $ScanSlugParts = $ScanSlug.Split('/')
  $ScanBucket = $ScanSlugParts[0]
  $ScanKeyPrefix = $ScanSlugParts[1..($ScanSlugParts.Length - 1)] -Join '/'
  Write-Tfi "Writing SCAP scan to ${scan_slug}/$BuildOS..."
  $ErrorActionPreference = "Continue"
  $ScanDir = "$TempDir\terrafirm\scan"
  Invoke-Expression -Command "mkdir $ScanDir" -ErrorAction SilentlyContinue
  Copy-Item "C:\Watchmaker\SCAP" -Destination "$ScanDir" -Recurse -Force
  Write-S3Object -BucketName "$ScanBucket" -KeyPrefix "$${ScanKeyPrefix}/$${BuildOS}" -Folder "$${ScanDir}\SCAP\Sessions" -Recurse
  Write-Tfi "Wrote SCAP scan to ${scan_slug}/$BuildOS" $?
}

function Test-DisplayResult {
  param (
    [String]$Msg,
    $Success = $null
  )

  Write-Tfi $Msg $Success
  if (-not $Success) {
    throw "$Msg : FAILED"
  }
}

function Write-UserdataStatus {
  param ($UserdataStatus)
  $UserdataStatus | Out-File "${userdata_status_file}"
  Write-Tfi "Write userdata status file" $?
}

function Open-WinRM {
  Test-Command "Start-Process -FilePath `"winrm`" -ArgumentList `"quickconfig -q`""
  Test-Command "Start-Process -FilePath `"winrm`" -ArgumentList `"set winrm/config/service @{AllowUnencrypted=```"true```"}`" -Wait"
  Test-Command "Start-Process -FilePath `"winrm`" -ArgumentList `"set winrm/config/service/auth @{Basic=```"true```"}`" -Wait"
  Test-Command "Start-Process -FilePath `"winrm`" -ArgumentList `"set winrm/config @{MaxTimeoutms=```"1900000```"}`""

  $SaltCall = "C:\Program Files\Salt Project\salt\salt-call.exe"
  if (Test-Path -path "C:\Program Files\Salt Project\salt\salt-call.bat") {
    $SaltCall = "C:\Program Files\Salt Project\salt\salt-call.bat"
  }
  elseif (Test-Path -path "C:\salt\salt-call.bat") {
    $SaltCall = "C:\salt\salt-call.bat"
  }

  if ($BuildType -ne "builder") {
    # fix the lgpos to allow winrm
    & $SaltCall --local -c C:\Watchmaker\salt\conf ash_lgpo.set_reg_value `
      key='HKLM\SOFTWARE\Policies\Microsoft\Windows\WinRM\Service\AllowBasic' `
      value='1' `
      vtype='REG_DWORD'
    Write-Tfi "Command [salt-call --local -c C:\Watchmaker\salt\conf ash_lgpo.set_reg_value key='AllowBasic'...]" $?

    & $SaltCall --local -c C:\Watchmaker\salt\conf ash_lgpo.set_reg_value `
      key='HKLM\SOFTWARE\Policies\Microsoft\Windows\WinRM\Service\AllowUnencryptedTraffic' `
      value='1' `
      vtype='REG_DWORD'
    Write-Tfi "Command [salt-call --local -c C:\Watchmaker\salt\conf ash_lgpo.set_reg_value key='AllowUnencryptedTraffic'...]" $?
  }
}

function Close-Firewall {
  Test-Command "netsh advfirewall firewall add rule name=`"WinRM in`" protocol=tcp dir=in profile=any localport=5985 remoteip=any localip=any action=block"
}

function Open-Firewall {
  Test-Command "netsh advfirewall firewall set rule name=`"WinRM in`" new action=allow"
}

function Rename-User {
  param (
    [Parameter(Mandatory = $true)][string]$From,
    [Parameter(Mandatory = $true)][string]$To
  )

  $Admin = [adsi]("WinNT://./$From, user")
  if ($Admin.Name) {
    $Admin.psbase.rename("$To")
    Write-Tfi "Rename $From account to $To" $?
  }
}

function Set-Password {
  param (
    [Parameter(Mandatory = $true)][string]$User,
    [Parameter(Mandatory = $true)][string]$Pass
  )
  $Admin = [adsi]("WinNT://./$User, user")
  if ($Admin.Name) {
    $Admin.psbase.invoke("SetPassword", $Pass)
    Write-Tfi "Set $User password" $?
  }
  else {
    Write-Tfi "Unable to set password because user ($User) was not found."
  }
}

function Install-PythonGit {
  $BootstrapUrl = "${url_bootstrap}"
  $PythonUrl = "${url_python}"
  $GitUrl = "${url_git}"

  $BootstrapFile = "$${Env:Temp}\$($${BootstrapUrl}.split("/")[-1])"
  (New-Object System.Net.WebClient).DownloadFile($BootstrapUrl, $BootstrapFile)

  & "$BootstrapFile" `
    -PythonUrl "$PythonUrl" `
    -GitUrl "$GitUrl" `
    -Verbose -ErrorAction Stop
  Test-DisplayResult "Install Python/Git [$BootstrapFile -PythonUrl $PythonUrl -GitUrl $GitUrl -Verbose -ErrorAction Stop]" $?
}

function Clone-Watchmaker {
  $GitRepo = "${git_repo}"
  $GitRef = "${git_ref}"

  Test-Command "Remove-Item -force -recurse watchmaker -ErrorAction SilentlyContinue; git clone `"$GitRepo`" --recursive" -Tries 5
  cd watchmaker
  if ($GitRef) {
    if ($GitRef -match "^[0-9]+$") {
      Test-Command "git fetch origin +refs/pull/$${GitRef}/merge:$${GitRef}" -Tries 2
    }
    elseif ($GitRef -match "^refs/pull/.*") {
      Test-Command "git fetch origin +$${GitRef}:$${GitRef}" -Tries 2
    }
    Test-Command "git checkout $GitRef"
  }

  Test-Command "git submodule update"
}

function Install-Watchmaker {
  Test-Command "python -m pip install --index-url=`"$PypiUrl`" -r requirements\basics.txt" -Tries 2
  Test-Command "python -m pip install --index-url=`"$PypiUrl`" --upgrade boto3" -Tries 2

  Test-Command "python -m pip install --index-url `"$PypiUrl`" --editable ." -Tries 2
}

try {
  $ErrorActionPreference = "Stop"
  $StartDate = Get-Date

  Write-Tfi "----------------------------- $BuildLabel ---------------------"

  Set-Password -User "Administrator" -Pass "${password}"
  Close-Firewall
  $UserdataStatus = @(1, "Error: Build not completed (should never see this error)")
  [Net.ServicePointManager]::SecurityProtocol = "Tls12, Tls13"
  (New-Object System.Net.WebClient).DownloadFile("${url_7zip}", "$TempDir\7z-install.exe")
  Invoke-Expression -Command "$TempDir\7z-install.exe /S /D='C:\Program Files\7-Zip'" -ErrorAction Continue

  Check-Metadata
  Write-Tfi "Start Build ============"

%{~ if build_type == build_type_builder }
  Set-ExecutionPolicy Bypass -Scope Process -Force
  Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
  choco install jq -y --force
  choco install pwsh -y --force

  Install-PythonGit
  Clone-Watchmaker

  Test-Command "python -m pip install --index-url=`"$PypiUrl`" -r requirements\basics.txt" -Tries 2

  $VirtualEnvDir = ".\venv"
  Test-Command "python -m venv $VirtualEnvDir"
  Test-Command "$${VirtualEnvDir}\Scripts\activate"

  # Check if PyApp build script exists and use it, otherwise fall back to PyInstaller
  if (Test-Path ".\ci\build_pyapp.ps1") {
    Write-Tfi "Found ci\build_pyapp.ps1, using PyApp build..."
    choco install rust -y --force
    Test-Command "pwsh ci\build_pyapp.ps1" -Tries 2
    $STAGING_DIR = ".pyapp\dist"
  }
  else {
    Write-Tfi "PyApp build script not found, using PyInstaller build..."
    Test-Command "pwsh ci\build.ps1" -Tries 2
    $STAGING_DIR = ".pyinstaller\dist"
  }

  if (Test-Path ".\$STAGING_DIR\latest") {
    Test-Command "Remove-Item -Path `".\$STAGING_DIR\latest`" -Force  -Recurse" -Tries 3
  }

  Test-Command "Get-ChildItem -Path `".\$STAGING_DIR\*`" | Rename-Item -NewName latest" -Tries 3
  Test-Command "Get-Item -Path `".\$STAGING_DIR\latest\watchmaker-*-standalone-windows-amd64.exe`" | Rename-Item -NewName watchmaker-latest-standalone-windows-amd64.exe" -Tries 3

  Write-S3Object -BucketName "$BuildBucket" -KeyPrefix "$${BuildKeyPrefix}/${release_prefix}" -Folder ".\$STAGING_DIR" -Recurse
  Test-DisplayResult "Copied standalone to $${BuildBucket}/$${BuildKeyPrefix}/${release_prefix}" $?

  $UserdataStatus = @(0, "Success")

%{~ else }
%{~ if build_type == build_type_standalone }

  Write-Tfi "Installing Watchmaker from standalone executable..."

  $SleepTime = 20
  $Standalone = "${executable}"
  $ErrorKey = $StandaloneErrorSignalFile

  Write-Tfi "Looking for standalone executable at $BuildSlug/$Standalone"
  Write-Tfi "Looking for error signal at $BuildSlug/$ErrorKey"

  #block until executable exists, an error, or timeout
  while ($true) {
    # find out what's happening with the builder
    $Exists = $true
    $SignaledError = $true

    # see if the standalone is ready yet
    try {
      Get-S3ObjectMetadata -BucketName "$BuildBucket" -Key "$${BuildKeyPrefix}/$${Standalone}"
    }
    catch {
      $Exists = $false
    }

    # see if the builder encountered an error
    try {
      Get-S3ObjectMetadata -BucketName "$BuildBucket" -Key "$${BuuildKeyPrefix}/$${ErrorKey}"
    }
    catch {
      $SignaledError = $false
    }

    if ($SignaledError) {
      # error signaled by the builder
      $ErrorMsg = "Error signaled by the builder (Error file found at $BuildSlug/$ErrorKey)"
      Write-Tfi $ErrorMsg
      throw $ErrorMsg
      break
    }
    else {
      if ($Exists) {
        Write-Tfi "The standalone executable was found!"
        break
      }
      else {
        Write-Tfi "The standalone executable was not found. Trying again in $SleepTime s..."
        Start-Sleep -Seconds $SleepTime
      }
    }
  } # end of while($true)

  $DownloadDir = "${download_dir}"
  Read-S3Object -BucketName "$BuildBucket" -Key "$${BuildKeyPrefix}/$${Standalone}" -File "$${DownloadDir}\watchmaker.exe"
  Test-Command "$${DownloadDir}\watchmaker.exe ${args}"
  $UserdataStatus = @(0, "Success")

%{~ else }
  Write-Tfi "Installing Watchmaker from source..."
  Install-PythonGit
  Clone-Watchmaker
  Install-Watchmaker
  Test-Command "watchmaker ${args}"
  $UserdataStatus = @(0, "Success")

%{~ endif }
%{~ endif }

}
catch {
  $ErrorMessage = [String]$_.Exception + "Invocation Info: " + ($PSItem.InvocationInfo | Format-List * | Out-String)
  Write-Tfi "*** ERROR caught ***"
  Write-Tfi $ErrorMessage

%{~ if build_type == build_type_builder }
  # signal builds waiting to test a standalone that the build failed
  if (-not (Test-Path "$StandaloneErrorSignalFile")) {
    New-Item "$StandaloneErrorSignalFile" -ItemType "file" -Force
  }
  $Msg = "$ErrorMessage (For more information on the error, see the win_builder/userdata.log file.)"
  "$(Get-Date): $Msg" | Out-File "$StandaloneErrorSignalFile" -Append -Encoding utf8
  Write-S3Object -BucketName "$BuildBucket" -Key "$${BuildKeyPrefix}/$${StandaloneErrorSignalFile}" -File "$StandaloneErrorSignalFile"
  Write-Tfi "Signal error to S3" $?
%{~ endif }

  $ErrCode = 1
  $UserdataStatus = @($ErrCode, "Error [$ErrorMessage]")
}

$EndDate = Get-Date
Write-Tfi "End Build =============="
Write-Tfi ("Build took {0} seconds." -f [math]::Round(($EndDate - $StartDate).TotalSeconds))

Rename-User -From "Administrator" -To "$WinUser"
Open-WinRM
Write-UserdataStatus -UserdataStatus $UserdataStatus
Open-Firewall
Publish-Artifacts

if (($BuildType -eq $BuildTypeSource) -and ("${scan_slug}" -ne "")) {
  Publish-SCAP-Scan
}
