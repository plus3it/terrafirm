
$BuildOS = "${build_os}"
$BuildType = "${build_type}"
$BuildLabel = "${build_label}"
$BuildTypeBuilder = "${build_type_builder}"
$BuildTypeStandalone = "${build_type_standalone}"

Write-Host ("***************************************************************")
Write-Host ("Running Watchmaker Test: $BuildLabel")
Write-Host ("***************************************************************")
Write-Host ((Get-WmiObject -class Win32_OperatingSystem).Caption)

$UdPath = "${win_userdata_status_file}"

if (Test-Path -Path $UdPath) {
    # file exists, read into variable
    $UserdataStatus=gc $UdPath
} else {   # error, no userdata status found
    # declare an array to hold the status (number and message)
    $UserdataStatus=@($lastExitCode,"No status returned by userdata")
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
            Invoke-Expression -Command "${win_download_dir}\watchmaker.exe --version"  -ErrorAction Stop
        } else {
            Invoke-Expression -Command "watchmaker --version"  -ErrorAction Stop
        }
        # ------------------------------------------------------------ WAM TESTS END

        $TestStatus=@(0,"Passed")
    } catch {
        $TestStatus=@(1,"Testing error")
    }
}

# FINALLY after everything, give results
if ($UserdataStatus[0] -eq 0 -and $TestStatus[0] -eq 0) {
    Write-Host (".......................................................Success!")
} else {
    Write-Host ("........................................................FAILED!")
    Write-Host ("Userdata Status: ($UserdataStatus[0]) $UserdataStatus[1]")
    Write-Host ("Test Status    : ($TestStatus[0]) $TestStatus[1]")
    exit 1
}
