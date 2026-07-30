$BuildOS = "${build_os}"
$BuildType = "${build_type}"
$BuildLabel = "${build_label}"
$BuildTypeStandalone = "${build_type_standalone}"
$BuildTypeSource = "${build_type_source}"
$SourceSource = "${source_source}"
$StandaloneSource = "${standalone_source}"

$BuildSlug = "${build_slug}"
$BuildSlugParts = $BuildSlug -Split "/"
$BuildBucket = $BuildSlugParts[0]
$BuildKeyPrefix = $BuildSlugParts[1..($BuildSlugParts.Length - 1)] -Join "/"
$StandaloneErrorSignalFile = "${standalone_error_signal_file}"
$GitHubArtifactRepoOwner = "${github_artifact_repo_owner}"
$GitHubArtifactRepoName = "${github_artifact_repo_name}"
$GitHubArtifactRunId = "${github_artifact_run_id}"
$GitHubArtifactTokenSsmParameter = "${github_artifact_token_ssm_parameter}"
$FirehoseDeliveryStream = "${firehose_delivery_stream_name}"
$WinUser = "${user}"
$PypiUrl = "${url_pypi}"
$UserFormulasJsonBase64 = "${user_formulas_json_base64}"
$UserFormulasJson = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($UserFormulasJsonBase64)) -replace '"', '\"'
$DebugMode = "${debug}"
$UserdataLogS3Prefix = "s3://$BuildBucket/$BuildKeyPrefix/$BuildLabel"

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
}

function Check-Metadata {
  $MetadataApiToken = "http://169.254.169.254/latest/api/token"
  $MetadataLoopbackAZ = "http://169.254.169.254/latest/meta-data/placement/availability-zone"
  Test-Command -Description "Check metadata endpoint availability" -Tries 50 -Command {
    Invoke-RestMethod -Headers @{"X-aws-ec2-metadata-token-ttl-seconds" = "21600"} -Method PUT -Uri $MetadataApiToken | Out-Null
  }

  $token = Invoke-RestMethod -Headers @{"X-aws-ec2-metadata-token-ttl-seconds" = "21600"} -Method PUT -Uri $MetadataApiToken
  $availability_zone = Invoke-RestMethod -Headers @{"X-aws-ec2-metadata-token" = $token} -Method GET -Uri $MetadataLoopbackAZ
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
    try {
      Debug-2S3 "$Msg $OutResult"
    }
    catch {
      $DebugError = [String]$_.Exception
      "$(Get-Date): Debug-2S3 failed: $DebugError" | Out-File "$UserdataLogFile" -Append -Encoding utf8
    }
  }
}

function Test-Command {
  param (
    [Parameter(Mandatory = $true)][scriptblock]$Command,
    [Parameter(Mandatory = $false)][string]$Description = $Command.ToString().Trim(),
    [Parameter(Mandatory = $false)][int]$Tries = 1,
    [Parameter(Mandatory = $false)][int]$SecondsDelay = 2,
    [Parameter(Mandatory = $false)][ValidateRange(1, 3600)][int]$HeartbeatSeconds = 20
  )
  $TryCount = 0
  $Completed = $false
  $MsgFailed = "Command failed [{0}]" -f $Description
  $MsgSucceeded = "Command succeeded [{0}]" -f $Description
  $OriginalErrorActionPreference = $ErrorActionPreference

  while (-not $Completed) {
    $Attempt = $TryCount + 1
    $HeartbeatJob = $null

    try {
      $ErrorActionPreference = "Stop"
      $global:LASTEXITCODE = 0

      Write-Tfi ("Command started (attempt {1}/{2}) [{0}]" -f $Description, $Attempt, $Tries)

      try {
        $HeartbeatJob = Start-Job -ScriptBlock {
          param (
            [string]$LogPath,
            [string]$CommandDescription,
            [int]$AttemptNumber,
            [int]$MaxAttempts,
            [int]$IntervalSeconds
          )

          # Use a FileStream append with shared read/write access to reduce cross-process contention.
          function Add-HeartbeatLogLine {
            param (
              [string]$Path,
              [string]$Message
            )
            $RetryCount = 5
            $RetryDelayMilliseconds = 200
            $Bytes = [System.Text.Encoding]::UTF8.GetBytes($Message + [Environment]::NewLine)
            for ($RetryAttempt = 1; $RetryAttempt -le $RetryCount; $RetryAttempt++) {
              $FileStream = $null
              try {
                $FileStream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Append, [System.IO.FileAccess]::Write, [System.IO.FileShare]::ReadWrite)
                $FileStream.Write($Bytes, 0, $Bytes.Length)
                $FileStream.Flush()
                return
              }
              catch {
                if ($RetryAttempt -eq $RetryCount) {
                  throw
                }
                Start-Sleep -Milliseconds $RetryDelayMilliseconds
              }
              finally {
                if ($null -ne $FileStream) {
                  $FileStream.Dispose()
                }
              }
            }
          }

          $HeartbeatCount = 0

          while ($true) {
            Start-Sleep -Seconds $IntervalSeconds
            $HeartbeatCount++
            $SecondsRunning = $HeartbeatCount * $IntervalSeconds

            Add-HeartbeatLogLine -Path "$LogPath" -Message "$(Get-Date): Command still running at $${SecondsRunning}s (attempt $AttemptNumber/$MaxAttempts) [$CommandDescription]"
          }
        } -ArgumentList "$UserdataLogFile", "$Description", $Attempt, $Tries, $HeartbeatSeconds
      }
      catch {
        Write-Tfi ("Unable to start heartbeat logger for command [{0}]: {1}" -f $Description, [String]$_.Exception.Message)
      }

      & $Command
      $Result = @{
        Success  = $?
        ExitCode = $LASTEXITCODE
      }
      if (($False -eq $Result.Success) -Or (0 -ne $Result.ExitCode)) {
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
        $ErrorMessage = [String]$_.Exception + " Invocation Info: " + ($PSItem.InvocationInfo | Format-List * | Out-String)
        Write-Tfi $ErrorMessage
        Write-Tfi ("Command [{0}] failed the maximum number of {1} time(s)." -f $Description, $Tries)
        Write-Tfi ("Error code (if available): {0}" -f ($Result.ExitCode))
        throw ("Command [{0}] failed" -f $Description)
      }
      else {
        Write-Tfi ("Command [{0}] failed. Retrying in {1} second(s)." -f $Description, $SecondsDelay)
        Start-Sleep $SecondsDelay
      }
    }
    finally {
      if ($null -ne $HeartbeatJob) {
        Stop-Job -Job $HeartbeatJob -ErrorAction SilentlyContinue | Out-Null
        Remove-Job -Job $HeartbeatJob -Force -ErrorAction SilentlyContinue | Out-Null
      }

      $ErrorActionPreference = $OriginalErrorActionPreference
    }
  }
}

function Copy-OptionalArtifact {
  param (
    [Parameter(Mandatory = $true)][string]$Source,
    [Parameter(Mandatory = $true)][string]$Destination,
    [Parameter(Mandatory = $true)][string]$Label
  )

  if (-not (Test-Path -Path $Source)) {
    Write-Tfi "Artifact [$Label] missing at $Source (skipping)"
    return
  }

  try {
    Copy-Item -Path $Source -Destination $Destination -Recurse -Force
    Write-Tfi "Artifact [$Label] copied from $Source to $Destination" $true
  }
  catch {
    $CopyError = [String]$_.Exception + " Invocation Info: " + ($PSItem.InvocationInfo | Format-List * | Out-String)
    Write-Tfi "Artifact [$Label] copy failed: $CopyError"
  }
}

function Publish-Artifacts {
  ## Upload files to s3 related to the build
  $ErrorActionPreference = "Continue"
  $ArtifactDir = "$TempDir\build-artifacts"
  New-Item -Path $ArtifactDir -ItemType Directory -Force | Out-Null

  # Watchmaker logs and SCAP results
  New-Item -Path "$ArtifactDir\watchmaker" -ItemType Directory -Force | Out-Null
  Copy-OptionalArtifact -Source "C:\Watchmaker\Logs\*log" -Destination "$ArtifactDir\watchmaker" -Label "watchmaker logs"
  Copy-OptionalArtifact -Source "C:\Watchmaker\SCAP" -Destination "$ArtifactDir\scap" -Label "watchmaker scap"

  # AWS EC2 Launch mechanisms (userdata execution logs)
  Copy-OptionalArtifact -Source "C:\ProgramData\Amazon\EC2Launch\Log" -Destination "$ArtifactDir\ec2launchv2" -Label "ec2launchv2 logs"
  Copy-OptionalArtifact -Source "C:\ProgramData\Amazon\EC2-Windows\Launch\Log" -Destination "$ArtifactDir\ec2launch" -Label "ec2launch logs"
  Copy-OptionalArtifact -Source "C:\Program Files\Amazon\Ec2ConfigService\Logs" -Destination "$ArtifactDir\ec2config" -Label "ec2config logs"

  # AWS Systems Manager logs
  Copy-OptionalArtifact -Source "C:\ProgramData\Amazon\SSM\Logs" -Destination "$ArtifactDir\ssm" -Label "ssm logs"

  # CloudFormation logs (cfn-init, cfn-hup, cfn-signal)
  Copy-OptionalArtifact -Source "C:\cfn\log" -Destination "$ArtifactDir\cfn" -Label "cloudformation logs"

  # Windows Event Logs (Application, System, Security for troubleshooting)
  New-Item -Path "$ArtifactDir\eventlogs" -ItemType Directory -Force | Out-Null
  wevtutil epl Application "$ArtifactDir\eventlogs\Application.evtx"
  wevtutil epl System "$ArtifactDir\eventlogs\System.evtx"
  wevtutil epl Security "$ArtifactDir\eventlogs\Security.evtx"
  wevtutil epl "Microsoft-Windows-PowerShell/Operational" "$ArtifactDir\eventlogs\PowerShell-Operational.evtx"

  # Userdata execution artifacts
  New-Item -Path "$ArtifactDir\cloud" -ItemType Directory -Force | Out-Null
  New-Item -Path "$ArtifactDir\sys" -ItemType Directory -Force | Out-Null
  Copy-OptionalArtifact -Source "C:\Windows\TEMP\*.tmp" -Destination "$ArtifactDir\cloud" -Label "temp tmp files"
  Copy-OptionalArtifact -Source "C:\Program Files\Amazon\Ec2ConfigService\Scripts\User*ps1" -Destination "$ArtifactDir\cloud" -Label "ec2config user scripts"
  Copy-OptionalArtifact -Source "C:\Windows\Temp\UserScript.ps1" -Destination "$ArtifactDir\cloud\UserScript.ps1" -Label "userscript.ps1"
  Copy-OptionalArtifact -Source "C:\Windows\system32\config\systemprofile\AppData\Local\Temp\EC2Launch*" -Destination "$ArtifactDir\cloud\" -Label "ec2launch temp artifacts"

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
  Test-Command -Description "Compress-Archive $ArtifactDir\* -> $ZipFile" -Command {
    Compress-Archive -Path "$ArtifactDir\*" -DestinationPath $ZipFile -Force
  }

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
  New-Item -Path $ScanDir -ItemType Directory -Force | Out-Null
  Copy-Item "C:\Watchmaker\SCAP" -Destination "$ScanDir" -Recurse -Force
  Write-S3Object -BucketName "$ScanBucket" -KeyPrefix "$${ScanKeyPrefix}/$${BuildOS}" -Folder "$${ScanDir}\SCAP\Sessions" -Recurse
  Write-Tfi "Wrote SCAP scan to ${scan_slug}/$BuildOS" $?
}

function Get-GitHubArtifactName {
  if ("${standalone_builder}" -eq "pyapp") {
    return "standalone-pyapp-dists-windows"
  }
  return "standalone-dists-windows"
}

function Get-GitHubToken {
  if ([string]::IsNullOrEmpty($GitHubArtifactTokenSsmParameter)) {
    throw "github_artifact_token_ssm_parameter must be set when standalone_source is github_actions_artifact"
  }

  $Response = Get-SSMParameterValue -Name $GitHubArtifactTokenSsmParameter -WithDecryption $true
  $Token = $null

  if ($null -ne $Response.Parameter) {
    $Token = $Response.Parameter.Value
  }
  elseif ($null -ne $Response.Parameters -and $Response.Parameters.Count -gt 0) {
    $Token = $Response.Parameters[0].Value
  }

  if ([string]::IsNullOrEmpty($Token)) {
    throw "Unable to retrieve GitHub token from SSM parameter '$GitHubArtifactTokenSsmParameter'"
  }

  return $Token
}

function Install-StandaloneFromGitHubArtifact {
  $ArtifactName = Get-GitHubArtifactName
  $Token        = Get-GitHubToken
  $Headers = @{
    Authorization = "Bearer $Token"
    Accept        = "application/vnd.github+json"

    "X-GitHub-Api-Version" = "2022-11-28"
  }

  if ([string]::IsNullOrEmpty($GitHubArtifactRunId)) {
    throw "github_artifact_run_id must be set when standalone_source is github_actions_artifact"
  }

  $ArtifactsUri = "https://api.github.com/repos/$GitHubArtifactRepoOwner/$GitHubArtifactRepoName/actions/runs/$GitHubArtifactRunId/artifacts"
  Write-Tfi "Querying GitHub artifact metadata from $ArtifactsUri"
  $ArtifactsResponse = Invoke-RestMethod -Headers $Headers -Uri $ArtifactsUri -Method Get
  $Artifact = $ArtifactsResponse.artifacts | Where-Object { $_.name -eq $ArtifactName } | Select-Object -First 1

  if ($null -eq $Artifact) {
    throw "GitHub artifact '$ArtifactName' was not found for run $GitHubArtifactRunId"
  }

  $DownloadDir = "${download_dir}"
  if (-not (Test-Path $DownloadDir)) {
    New-Item -ItemType Directory -Force -Path $DownloadDir | Out-Null
  }

  $ArtifactZip = Join-Path $DownloadDir "$ArtifactName.zip"
  $ArtifactExtractDir = Join-Path $DownloadDir $ArtifactName
  Remove-Item -Path $ArtifactZip -Force -ErrorAction SilentlyContinue
  Remove-Item -Path $ArtifactExtractDir -Force -Recurse -ErrorAction SilentlyContinue

  Write-Tfi "Downloading GitHub artifact '$ArtifactName'"
  Invoke-WebRequest -Headers $Headers -Uri $Artifact.archive_download_url -OutFile $ArtifactZip

  Write-Tfi "Extracting GitHub artifact '$ArtifactName'"
  Expand-Archive -Path $ArtifactZip -DestinationPath $ArtifactExtractDir -Force

  $Executable = Get-ChildItem -Path $ArtifactExtractDir -Filter "watchmaker-*-standalone-windows-amd64.exe" -File -Recurse | Select-Object -First 1
  if ($null -eq $Executable) {
    throw "No Windows standalone executable was found in artifact '$ArtifactName'"
  }

  $Destination = Join-Path $DownloadDir "watchmaker.exe"
  Copy-Item -Path $Executable.FullName -Destination $Destination -Force
  return $Destination
}

function Install-SourceWheelFromGitHubArtifact {
  $ArtifactName = "dists"
  $Token        = Get-GitHubToken
  $Headers = @{
    Authorization = "Bearer $Token"
    Accept        = "application/vnd.github+json"

    "X-GitHub-Api-Version" = "2022-11-28"
  }

  if ([string]::IsNullOrEmpty($GitHubArtifactRunId)) {
    throw "github_artifact_run_id must be set when source_source is github_actions_artifact"
  }

  $ArtifactsUri = "https://api.github.com/repos/$GitHubArtifactRepoOwner/$GitHubArtifactRepoName/actions/runs/$GitHubArtifactRunId/artifacts"
  Write-Tfi "Querying GitHub artifact metadata from $ArtifactsUri"
  $ArtifactsResponse = Invoke-RestMethod -Headers $Headers -Uri $ArtifactsUri -Method Get
  $Artifact = $ArtifactsResponse.artifacts | Where-Object { $_.name -eq $ArtifactName } | Select-Object -First 1

  if ($null -eq $Artifact) {
    throw "GitHub artifact '$ArtifactName' was not found for run $GitHubArtifactRunId"
  }

  $DownloadDir = "${download_dir}"
  if (-not (Test-Path $DownloadDir)) {
    New-Item -ItemType Directory -Force -Path $DownloadDir | Out-Null
  }

  $ArtifactZip = Join-Path $DownloadDir "$ArtifactName.zip"
  $ArtifactExtractDir = Join-Path $DownloadDir $ArtifactName
  Remove-Item -Path $ArtifactZip -Force -ErrorAction SilentlyContinue
  Remove-Item -Path $ArtifactExtractDir -Force -Recurse -ErrorAction SilentlyContinue

  Write-Tfi "Downloading GitHub artifact '$ArtifactName'"
  Invoke-WebRequest -Headers $Headers -Uri $Artifact.archive_download_url -OutFile $ArtifactZip

  Write-Tfi "Extracting GitHub artifact '$ArtifactName'"
  Expand-Archive -Path $ArtifactZip -DestinationPath $ArtifactExtractDir -Force

  $Wheel = Get-ChildItem -Path $ArtifactExtractDir -Filter "watchmaker-*-py3-none-any.whl" -File -Recurse | Select-Object -First 1
  if ($null -eq $Wheel) {
    throw "No wheel distribution was found in artifact '$ArtifactName'"
  }

  return $Wheel.FullName
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
  param (
    [Parameter(Mandatory = $true)]$UserdataStatus
  )

  $StatusJson = $UserdataStatus | ConvertTo-Json -Compress
  $StatusJson | Out-File "${userdata_status_file}" -Encoding utf8
  Write-Tfi "Write userdata status file" $?
}

function New-UserdataStatus {
  param (
    [Parameter(Mandatory = $true)][int]$Code,
    [Parameter(Mandatory = $true)][string]$Message
  )

  return [ordered]@{
    code      = $Code
    message   = $Message
    timestamp = (Get-Date).ToString("o")
    log_path  = $UserdataLogFile
    s3_prefix = $UserdataLogS3Prefix
  }
}

function Invoke-PostStep {
  param (
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][scriptblock]$Script,
    [Parameter(Mandatory = $false)][bool]$FailBuild = $true
  )

  try {
    & $Script
    Write-Tfi "Post-step [$Name] succeeded" $true
  }
  catch {
    $StepError = [String]$_.Exception + " Invocation Info: " + ($PSItem.InvocationInfo | Format-List * | Out-String)
    Write-Tfi "Post-step [$Name] failed: $StepError"
    if ($FailBuild -and ($UserdataStatus.code -eq 0)) {
      $script:UserdataStatus = New-UserdataStatus -Code 1 -Message "Post-step '$Name' failed: $([String]$_.Exception.Message)"
    }
  }
}

function Open-WinRM {
  Test-Command -Description "winrm quickconfig -q" -Command {
    & winrm quickconfig -q
  }
  $SaltCall = "C:\Program Files\Salt Project\salt\salt-call.exe"
  if (Test-Path -path "C:\Program Files\Salt Project\salt\salt-call.bat") {
    $SaltCall = "C:\Program Files\Salt Project\salt\salt-call.bat"
  } elseif (Test-Path -path "C:\salt\salt-call.bat") {
    $SaltCall = "C:\salt\salt-call.bat"
  }

  if (Test-Path -path $SaltCall) {
    # fix the lgpos to allow winrm
    Test-Command -Description "salt-call set WinRM AllowBasic policy" -Command {
      & $SaltCall --local -c C:\Watchmaker\salt\conf ash_lgpo.set_reg_value `
        key='HKLM\SOFTWARE\Policies\Microsoft\Windows\WinRM\Service\AllowBasic' `
        value='1' `
        vtype='REG_DWORD'
    }

    Test-Command -Description "salt-call set WinRM AllowUnencryptedTraffic policy" -Command {
      & $SaltCall --local -c C:\Watchmaker\salt\conf ash_lgpo.set_reg_value `
        key='HKLM\SOFTWARE\Policies\Microsoft\Windows\WinRM\Service\AllowUnencryptedTraffic' `
        value='1' `
        vtype='REG_DWORD'
    }
  }

  Test-Command -Description "winrm set service AllowUnencrypted=true" -Command {
    & winrm set winrm/config/service '@{AllowUnencrypted="true"}'
  }
  Test-Command -Description "winrm set auth Basic=true" -Command {
    & winrm set winrm/config/service/auth '@{Basic="true"}'
  }
  Test-Command -Description "winrm set MaxTimeoutms=1900000" -Command {
    & winrm set winrm/config '@{MaxTimeoutms="1900000"}'
  }
}

function Close-Firewall {
  Test-Command -Description "netsh block WinRM in" -Command {
    & netsh advfirewall firewall add rule name="WinRM in" protocol=tcp dir=in profile=any localport=5985 remoteip=any localip=any action=block
  }
}

function Open-Firewall {
  Test-Command -Description "netsh allow WinRM in" -Command {
    & netsh advfirewall firewall set rule name="WinRM in" new action=allow
  }
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

  Test-Command -Description "git clone $GitRepo --recursive" -Tries 5 -Command {
    Remove-Item -force -recurse watchmaker -ErrorAction SilentlyContinue
    & git clone "$GitRepo" --recursive
  }
  cd watchmaker
  if ($GitRef) {
    if ($GitRef -match "^[0-9]+$") {
      Test-Command -Description "git fetch origin +refs/pull/$${GitRef}/merge:$${GitRef}" -Tries 2 -Command {
        & git fetch origin "+refs/pull/$${GitRef}/merge:$${GitRef}"
      }
    }
    elseif ($GitRef -match "^refs/pull/.*") {
      Test-Command -Description "git fetch origin +$${GitRef}:$${GitRef}" -Tries 2 -Command {
        & git fetch origin "+$${GitRef}:$${GitRef}"
      }
    }
    Test-Command -Description "git checkout $GitRef" -Command {
      & git checkout $GitRef
    }
  }

  Test-Command -Description "git submodule update" -Command {
    & git submodule update
  }
}

function Install-WatchmakerPrereqs {
  Test-Command -Description "python -m pip install --index-url $PypiUrl --upgrade pip" -Tries 2 -Command {
    & python -m pip install --index-url "$PypiUrl" --upgrade pip
  }
  Test-Command -Description "python -m pip --version" -Tries 1 -Command {
    & python -m pip --version
  }
  Test-Command -Description "python -m pip install --index-url $PypiUrl --upgrade boto3" -Tries 2 -Command {
    & python -m pip install --index-url "$PypiUrl" --upgrade boto3
  }
}

function Install-Watchmaker {
  Install-WatchmakerPrereqs
  Test-Command -Description "python -m pip install --index-url $PypiUrl --editable ." -Tries 2 -Command {
    & python -m pip install --index-url "$PypiUrl" --editable .
  }
}

function Install-WatchmakerFromGitHubArtifact {
  Install-WatchmakerPrereqs
  $WheelPath = Install-SourceWheelFromGitHubArtifact
  Test-Command -Description "python -m pip install --index-url $PypiUrl $WheelPath" -Tries 2 -Command {
    & python -m pip install --index-url "$PypiUrl" "$WheelPath"
  }
}

function Configure-KinesisAgent {
  if ([string]::IsNullOrEmpty($FirehoseDeliveryStream)) {
    Write-Tfi "Kinesis Agent setup skipped: firehose delivery stream name was not provided"
    return
  }

  $KinesisTapService = Get-Service -Name "AWSKinesisTap" -ErrorAction SilentlyContinue
  if ($null -eq $KinesisTapService) {
    try {
      $InstallerScript = Join-Path $TempDir "InstallKinesisAgent.ps1"
      Test-Command -Description "Download InstallKinesisAgent.ps1" -Command {
        Invoke-WebRequest -Uri "https://s3-us-west-2.amazonaws.com/kinesis-agent-windows/downloads/InstallKinesisAgent.ps1" -OutFile $InstallerScript -UseBasicParsing
      }
      Test-Command -Description "Run InstallKinesisAgent.ps1" -Command {
        & $InstallerScript
      }
      $KinesisTapService = Get-Service -Name "AWSKinesisTap" -ErrorAction SilentlyContinue
    }
    catch {
      Write-Tfi "Kinesis Agent install failed: $([String]$_.Exception.Message)"
      return
    }
  }

  if ($null -eq $KinesisTapService) {
    Write-Tfi "Kinesis Agent setup skipped: AWSKinesisTap service is not available"
    return
  }

  try {
    $ConfigDir = Join-Path $Env:ProgramFiles "Amazon\AWSKinesisTap"
    New-Item -Path $ConfigDir -ItemType Directory -Force | Out-Null
    $ConfigPath = Join-Path $ConfigDir "appsettings.json"

    $UserdataDir = Split-Path -Path $UserdataLogFile -Parent
    $UserdataLeaf = Split-Path -Path $UserdataLogFile -Leaf

    $KinesisConfig = [ordered]@{
      Sources = @(
        [ordered]@{
          Id             = "UserdataLogSource"
          SourceType     = "DirectorySource"
          Directory      = $UserdataDir
          FileNameFilter = $UserdataLeaf
          RecordParser   = "SingleLine"
          InitialPosition = "0"
        }
      )
      Sinks = @(
        [ordered]@{
          Id                  = "UserdataFirehoseSink"
          SinkType            = "KinesisFirehose"
          StreamName          = $FirehoseDeliveryStream
          Region              = "${aws_region}"
          QueueType           = "file"
          ParallelUploadCount = 1
        }
      )
      Pipes = @(
        [ordered]@{
          Id        = "UserdataToFirehose"
          SourceRef = "UserdataLogSource"
          SinkRef   = "UserdataFirehoseSink"
        }
      )
    }

    $KinesisConfig | ConvertTo-Json -Depth 8 | Out-File $ConfigPath -Encoding utf8

    if ($KinesisTapService.Status -eq "Running") {
      Test-Command -Description "Restart AWSKinesisTap service" -Command {
        Restart-Service -Name "AWSKinesisTap" -ErrorAction Stop
      }
    }
    else {
      Test-Command -Description "Start AWSKinesisTap service" -Command {
        Start-Service -Name "AWSKinesisTap" -ErrorAction Stop
      }
    }

    Write-Tfi "Kinesis Agent configured for stream $FirehoseDeliveryStream" $true
  }
  catch {
    Write-Tfi "Kinesis Agent configuration failed: $([String]$_.Exception.Message)"
  }
}

try {
  $ErrorActionPreference = "Stop"
  $StartDate = Get-Date

  Write-Tfi "----------------------------- $BuildLabel ---------------------"

  Set-Password -User "Administrator" -Pass "${password}"
  Close-Firewall
  $UserdataStatus = New-UserdataStatus -Code 1 -Message "Error: Build not completed (should never see this error)"
  [Net.ServicePointManager]::SecurityProtocol = "Tls12, Tls13"
  Check-Metadata
  Configure-KinesisAgent
  Write-Tfi "Start Build ============"

%{~ if build_type == build_type_builder }
  Test-Command -Description "Set-ExecutionPolicy Bypass -Scope Process -Force" -Command {
    Set-ExecutionPolicy Bypass -Scope Process -Force
  }
  Test-Command -Description "Install Chocolatey bootstrap script" -Command {
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
  }
  Test-Command -Description "choco install jq" -Tries 2 -Command {
    & choco install jq -y --force --no-progress --limit-output --execution-timeout=600
  }
  Test-Command -Description "choco install pwsh" -Tries 2 -Command {
    & choco install pwsh -y --force --no-progress --limit-output --execution-timeout=600
  }

  Install-PythonGit
  Clone-Watchmaker

  Test-Command -Description "python -m pip install --index-url $PypiUrl -r requirements\\basics.txt" -Tries 2 -Command {
    & python -m pip install --index-url "$PypiUrl" -r requirements\basics.txt
  }

  $VirtualEnvDir = ".\venv"
  Test-Command -Description "python -m venv $VirtualEnvDir" -Command {
    & python -m venv $VirtualEnvDir
  }
  Test-Command -Description "$${VirtualEnvDir}\Scripts\activate" -Command {
    . "$${VirtualEnvDir}\Scripts\Activate.ps1"
  }

%{~ if standalone_builder == "pyapp" }
  Write-Tfi "Using PyApp build..."
  Test-Command -Description "choco install rust -y --force --no-progress --limit-output --execution-timeout=600" -Command {
    & choco install rust -y --force --no-progress --limit-output --execution-timeout=600
  }
  Test-Command -Description "pwsh ci\\build_pyapp.ps1" -Tries 2 -Command {
    & pwsh ci\build_pyapp.ps1
  }
  $STAGING_DIR = ".pyapp\dist"
%{~ else }
  Write-Tfi "Using PyInstaller build..."
  Test-Command -Description "pwsh ci\\build.ps1" -Tries 2 -Command {
    & pwsh ci\build.ps1
  }
  $STAGING_DIR = ".pyinstaller\dist"
%{~ endif }

  if (Test-Path ".\$STAGING_DIR\latest") {
    Test-Command -Description "Remove-Item .\\$STAGING_DIR\\latest" -Tries 3 -Command {
      Remove-Item -Path ".\$STAGING_DIR\latest" -Force -Recurse
    }
  }

  Test-Command -Description "Rename dist directory to latest" -Tries 3 -Command {
    Get-ChildItem -Path ".\$STAGING_DIR\*" | Rename-Item -NewName latest
  }
  Test-Command -Description "Rename standalone executable to watchmaker-latest-standalone-windows-amd64.exe" -Tries 3 -Command {
    Get-Item -Path ".\$STAGING_DIR\latest\watchmaker-*-standalone-windows-amd64.exe" | Rename-Item -NewName watchmaker-latest-standalone-windows-amd64.exe
  }

  Test-Command -Description "Write-S3Object standalone release to $${BuildBucket}/$${BuildKeyPrefix}/${release_prefix}" -Command {
    Write-S3Object -BucketName "$BuildBucket" -KeyPrefix "$${BuildKeyPrefix}/${release_prefix}" -Folder ".\$STAGING_DIR" -Recurse
  }
  Test-DisplayResult "Copied standalone to $${BuildBucket}/$${BuildKeyPrefix}/${release_prefix}" $?

  $UserdataStatus = New-UserdataStatus -Code 0 -Message "Success"

%{~ else }
%{~ if build_type == build_type_standalone }

  Write-Tfi "Installing Watchmaker from standalone executable..."

%{~ if standalone_source == "github_actions_artifact" }
  $ExecutablePath = Install-StandaloneFromGitHubArtifact
%{~ else }
  $SleepTime = 20
  $MaxWaitSeconds = 600
  $StandaloneWaitDeadline = (Get-Date).AddSeconds($MaxWaitSeconds)
  $Standalone = "${executable}"
  $ErrorKey = $StandaloneErrorSignalFile

  Write-Tfi "Looking for standalone executable at $BuildSlug/$Standalone"
  Write-Tfi "Looking for error signal at $BuildSlug/$ErrorKey"
  Write-Tfi "Waiting up to $MaxWaitSeconds second(s) for standalone artifact readiness"

  #block until executable exists, an error, or timeout
  while ($true) {
    if ((Get-Date) -gt $StandaloneWaitDeadline) {
      $ErrorMsg = "Timed out waiting for standalone executable after $MaxWaitSeconds second(s): $BuildSlug/$Standalone"
      Write-Tfi $ErrorMsg
      throw $ErrorMsg
    }

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
      Get-S3ObjectMetadata -BucketName "$BuildBucket" -Key "$${BuildKeyPrefix}/$${ErrorKey}"
    }
    catch {
      $SignaledError = $false
    }

    if ($SignaledError) {
      # error signaled by the builder
      $ErrorMsg = "Error signaled by the builder (Error file found at $BuildSlug/$ErrorKey)"
      Write-Tfi $ErrorMsg
      throw $ErrorMsg
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
  Test-Command -Description "Read-S3Object standalone executable from $${BuildBucket}/$${BuildKeyPrefix}/$${Standalone}" -Command {
    Read-S3Object -BucketName "$BuildBucket" -Key "$${BuildKeyPrefix}/$${Standalone}" -File "$${DownloadDir}\watchmaker.exe"
  }
  $ExecutablePath = "$${DownloadDir}\watchmaker.exe"
%{~ endif }
  if ($UserFormulasJson -ne "{}") {
    Test-Command -Description "$ExecutablePath ${args} --user-formulas=<json>" -Command {
      & "$ExecutablePath" ${args} "--user-formulas=$UserFormulasJson"
    }
  }
  else {
    Test-Command -Description "$ExecutablePath ${args}" -Command {
      & "$ExecutablePath" ${args}
    }
  }
  $UserdataStatus = New-UserdataStatus -Code 0 -Message "Success"

%{~ else }
  Write-Tfi "Installing Watchmaker from source..."
  Install-PythonGit

  if ($SourceSource -eq "github_actions_artifact") {
    Install-WatchmakerFromGitHubArtifact
  }
  else {
    Clone-Watchmaker
    Install-Watchmaker
  }

  if ($UserFormulasJson -ne "{}") {
    Test-Command -Description "watchmaker ${args} --user-formulas=<json>" -Command {
      & watchmaker ${args} "--user-formulas=$UserFormulasJson"
    }
  }
  else {
    Test-Command -Description "watchmaker ${args}" -Command {
      & watchmaker ${args}
    }
  }
  $UserdataStatus = New-UserdataStatus -Code 0 -Message "Success"

%{~ endif }
%{~ endif }

}
catch {
  $ErrorMessage = [String]$_.Exception + " Invocation Info: " + ($PSItem.InvocationInfo | Format-List * | Out-String)
  Write-Tfi "*** ERROR caught ***"
  Write-Tfi $ErrorMessage

%{~ if build_type == build_type_builder }
  # signal builds waiting to test a standalone that the build failed
  if (-not (Test-Path "$StandaloneErrorSignalFile")) {
    New-Item "$StandaloneErrorSignalFile" -ItemType "file" -Force
  }
  $Msg = "$ErrorMessage (For more information on the error, see the win_builder/userdata.log file.)"
  "$(Get-Date): $Msg" | Out-File "$StandaloneErrorSignalFile" -Append -Encoding utf8
  try {
    Test-Command -Description "Write-S3Object standalone error signal to $${BuildBucket}/$${BuildKeyPrefix}/$${StandaloneErrorSignalFile}" -Command {
      Write-S3Object -BucketName "$BuildBucket" -Key "$${BuildKeyPrefix}/$${StandaloneErrorSignalFile}" -File "$StandaloneErrorSignalFile"
    }
    Write-Tfi "Signal error to S3" $true
  }
  catch {
    Write-Tfi "Signal error to S3 failed: $([String]$_.Exception.Message)"
  }
%{~ endif }

  $ErrCode = 1
  $UserdataStatus = New-UserdataStatus -Code $ErrCode -Message "Error [$([String]$_.Exception.Message)]"
}

$EndDate = Get-Date
Write-Tfi "End Build =============="
Write-Tfi ("Build took {0} seconds." -f [math]::Round(($EndDate - $StartDate).TotalSeconds))

Invoke-PostStep -Name "Rename-User" -Script {
  Rename-User -From "Administrator" -To "$WinUser"
}
Invoke-PostStep -Name "Open-WinRM" -Script {
  Open-WinRM
}
Invoke-PostStep -Name "Write-UserdataStatus" -Script {
  Write-UserdataStatus -UserdataStatus $UserdataStatus
}

Invoke-PostStep -Name "Publish-Artifacts" -FailBuild $false -Script {
  Publish-Artifacts
}

Invoke-PostStep -Name "Open-Firewall" -Script {
  Open-Firewall
}

if (($BuildType -eq $BuildTypeSource) -and ("${scan_slug}" -ne "")) {
  Invoke-PostStep -Name "Publish-SCAP-Scan" -FailBuild $false -Script {
    Publish-SCAP-Scan
  }
}

exit ([int]$UserdataStatus.code)
