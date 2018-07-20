# functions, vars in common between builder and normal userdata

# global vars

# log file
$UserdataLogFile = "${tfi_win_userdata_log}"
If(-not (Test-Path "$UserdataLogFile"))
{
  New-Item "$UserdataLogFile" -ItemType "file" -Force
}

# directory needed by logs and for various other purposes
$TempDir = "C:\Temp"
If(-not (Test-Path "$TempDir"))
{
  New-Item "$TempDir" -ItemType "directory" -Force
}

$AMIKey="${tfi_ami_key}"

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
    [Parameter(Mandatory=$false)][int]$SecondsDelay = 2,
    [Parameter(Mandatory=$false)][bool]$SignalS3 = $false,
    [Parameter(Mandatory=$false)][string]$S3Bucket,
    [Parameter(Mandatory=$false)][string]$S3Directory
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
        Write-Tfi ("Command [{0}] failed the maximum number of {1} time(s)." -f $Test, $Tries)
        Write-Tfi ("Error code (if available): {0}" -f ($Result.ExitCode))
        $PSCmdlet.ThrowTerminatingError($PSItem)
      }
      Else
      {
        $Msg = $PSItem.ToString()
        If ($Msg -ne $MsgFailed) { Write-Tfi $Msg }
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
  Copy-Item "C:\Watchmaker\Logs\*log" -Destination "$ArtifactDir\watchmaker" -Recurse -Force
  Copy-Item "C:\Watchmaker\SCAP\Results" -Destination "$ArtifactDir\scap_output" -Recurse -Force
  Copy-Item "C:\Watchmaker\SCAP\Logs" -Destination "$ArtifactDir\scap_logs" -Recurse -Force
  Copy-Item "C:\ProgramData\Amazon\EC2-Windows\Launch\Log" -Destination "$ArtifactDir\cloud" -Recurse -Force
  Copy-Item "C:\Program Files\Amazon\Ec2ConfigService\Logs" -Destination "$ArtifactDir\cloud" -Recurse -Force
  Copy-Item "C:\Windows\TEMP\*.tmp" -Destination "$ArtifactDir\cloud" -Recurse -Force
  Copy-Item "C:\Program Files\Amazon\Ec2ConfigService\Scripts\User*ps1" -Destination "$ArtifactDir\cloud" -Recurse -Force
  Get-ChildItem Env: | Out-File "$ArtifactDir\cloud\environment_variables.log" -Append -Encoding utf8

  # copy artifacts to s3
  $ArtifactLocation = "${tfi_build_date}/${tfi_build_hour}_${tfi_build_id}/$AMIKey"
  Write-Tfi "Writing logs to $ArtifactLocation"
  Copy-Item $UserdataLogFile -Destination "$ArtifactDir" -Force
  Write-S3Object -BucketName "${tfi_s3_bucket}" -Folder "$ArtifactDir" -KeyPrefix "$ArtifactLocation/" -Recurse

  # creates compressed archive to upload to s3
  $ZipFile = "$TempDir\${tfi_build_date}-${tfi_build_id}-$AMIKey.zip"
  cd 'C:\Program Files\7-Zip'
  Test-Command ".\7z a -y -tzip '$ZipFile' -r '$ArtifactDir\*'"
  Write-S3Object -BucketName "${tfi_s3_bucket}/${tfi_build_date}/${tfi_build_hour}_${tfi_build_id}" -File "$ZipFile"
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
  Write-S3Object -BucketName "${tfi_s3_bucket}/${tfi_build_date}/${tfi_build_hour}_${tfi_build_id}/$AMIKey" -File "$DebugFile"
  Write-S3Object -BucketName "${tfi_s3_bucket}/${tfi_build_date}/${tfi_build_hour}_${tfi_build_id}/$AMIKey" -File "$UserdataLogFile"
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
  $UserdataStatus | Out-File "$TempDir\userdata_status"
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
  $Admin.psbase.invoke("SetPassword", $Pass)
  Write-Tfi "Set $User password" $?
}

function Invoke-CmdScript
## Invoke the specified batch file (and parameters), but also propagate any
## environment variable changes back to the PowerShell environment that
## called it.
##
## Recipe from "Windows PowerShell Cookbook by Lee Holmes"
## https://www.safaribooksonline.com/library/view/windows-powershell-cookbook/9780596528492/ch01s09.html
{

  param([string] $script, [string] $parameters)

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

$ErrorActionPreference = "Stop"

Write-Tfi "AMI KEY: ----------------------------- $AMIKey ---------------------"
