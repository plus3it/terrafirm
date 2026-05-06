
$BuildOS = "${build_os}"
$BuildType = "${build_type}"
$BuildLabel = "${build_label}"
$BuildTypeBuilder = "${build_type_builder}"
$BuildTypeStandalone = "${build_type_standalone}"
$UserdataLogPathDefault = "${userdata_log}"

Write-Host ("***************************************************************")
Write-Host ("Running Watchmaker Test: $BuildLabel")
Write-Host ("***************************************************************")
Write-Host ((Get-WmiObject -class Win32_OperatingSystem).Caption)

$UdPath = "${userdata_status_file}"
$UserdataStatusDetails = $null
$UserdataLogPath = $UserdataLogPathDefault
$UserdataS3Prefix = ""

if (Test-Path -Path $UdPath) {
    # Parse JSON status first; fall back to legacy line-array format.
    $UdRaw = Get-Content -Path $UdPath -Raw
    try {
        $UserdataStatusDetails = $UdRaw | ConvertFrom-Json -ErrorAction Stop
        $UserdataStatus = @([int]$UserdataStatusDetails.code, [string]$UserdataStatusDetails.message)
        if ($UserdataStatusDetails.log_path) {
            $UserdataLogPath = [string]$UserdataStatusDetails.log_path
        }
        if ($UserdataStatusDetails.s3_prefix) {
            $UserdataS3Prefix = [string]$UserdataStatusDetails.s3_prefix
        }
    } catch {
        $UserdataStatus = Get-Content -Path $UdPath
    }
} else {   # error, no userdata status found
    # declare an array to hold the status (number and message)
    $UserdataStatus=@(1,"No status returned by userdata")
}

$TestStatus=@(0,"Not run")

if ($BuildType -ne $BuildTypeBuilder -and $UserdataStatus[0] -eq 0) {
    # userdata was successful so now TRY the watchmaker tests

    try {
        # userdata was successful so now try the watchmaker tests
        # put the tests between the dashed comments
        # NOTE: if tests don't have an error action of "Stop," by default or explicitly set, won't be caught
        # NOTE: default erroraction in powershell is "Continue"
        # ------------------------------------------------------------ WAM TESTS BEGIN
        if ( $BuildType -eq $BuildTypeStandalone ) {
            & "${download_dir}\watchmaker.exe" --version
            if ($LASTEXITCODE -ne 0) {
                throw "Standalone watchmaker version check failed with exit code $LASTEXITCODE"
            }
        } else {
            & watchmaker --version
            if ($LASTEXITCODE -ne 0) {
                throw "Source watchmaker version check failed with exit code $LASTEXITCODE"
            }
        }
        # ------------------------------------------------------------ WAM TESTS END

        $TestStatus=@(0,"Passed")
    } catch {
        $TestStatus=@(1,"Testing error: $([String]$_.Exception.Message)")
    }
}

# FINALLY after everything, give results
if ($UserdataStatus[0] -eq 0 -and $TestStatus[0] -eq 0) {
    Write-Host (".......................................................Success!")
} else {
    Write-Host ("........................................................FAILED!")
    Write-Host ("Userdata Status: ($($UserdataStatus[0])) $($UserdataStatus[1])")
    if ($UserdataS3Prefix) {
        Write-Host ("Userdata Logs S3 Prefix: $UserdataS3Prefix")
    }
    Write-Host ("Userdata Log Path: $UserdataLogPath")
    Write-Host ("Test Status    : ($($TestStatus[0])) $($TestStatus[1])")

    if (Test-Path -Path $UserdataLogPath) {
        Write-Host ("----------------------- userdata.log (last 120 lines) -----------------------")
        Get-Content -Path $UserdataLogPath -Tail 120 | ForEach-Object { Write-Host $_ }
        Write-Host ("-----------------------------------------------------------------------------")
    } else {
        Write-Host ("Userdata log file not found at path: $UserdataLogPath")
    }

    exit 1
}
