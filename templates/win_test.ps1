
$InstanceOS = "${instance_os}"
$InstanceType = "${instance_type}"
$InstanceSlug = "win_$InstanceType-$InstanceOS"

Write-Host ("***************************************************************")
switch ($InstanceType) {
    "src" {$testType = "From Source"; Break}
    "sa" {$testType = "Standalone"; Break}
    "builder" {$testType = "Standalone Builder"; Break}
}
Write-Host ("Running Watchmaker $testType Test ($InstanceSlug)")
Write-Host ("***************************************************************")
Write-Host ((Get-WmiObject -class Win32_OperatingSystem).Caption)

$UdPath = "${userdata_status_file}"

if (Test-Path -Path $UdPath) {   
    # file exists, read into variable
    $UserdataStatus=gc $UdPath
} else {   # error, no userdata status found
    # declare an array to hold the status (number and message)
    $UserdataStatus=@($lastExitCode,"No status returned by userdata")
}

$TestStatus=@(0,"Not run")

if ($InstanceType -ne "builder" -and $UserdataStatus[0] -eq 0) {   
    # userdata was successful so now TRY the watchmaker tests

    try {
        # userdata was successful so now try the watchmaker tests
        # put the tests between the dashed comments
        # NOTE: if tests don't have an error action of "Stop," by default or explicitly set, won't be caught
        # NOTE: default erroraction in powershell is "Continue"
        # ------------------------------------------------------------ WAM TESTS BEGIN
        if ( $InstanceType -eq "sa" ) {
            Invoke-Expression -Command "${standalone_path}\watchmaker.exe --version"  -ErrorAction Stop
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
