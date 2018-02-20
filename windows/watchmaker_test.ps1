

Write-Host ("*****************************************************************************")
Write-Host ("Running Watchmaker test script: WINDOWS")
Write-Host ("*****************************************************************************")
Write-Host ((Get-WmiObject -class Win32_OperatingSystem).Caption)

$UdPath = "C:\Temp\userdata_status"

If (Test-Path -Path $UdPath)
{   # file exists, read into variable
    $UserdataStatus=gc $UdPath
}
Else
{   # error, no userdata status found
    # declare an array to hold the status (number and message)
    $UserdataStatus=@($lastExitCode,"No status returned by userdata")
}

$TestStatus=@(0,"Not run")

If ($UserdataStatus[0] -eq 0) 
{   # userdata was successful so now TRY the watchmaker tests

    Try 
    {   
        # userdata was successful so now try the watchmaker tests
        # put the tests between the dashed comments
        # NOTE: if tests don't have an error action of "Stop," by default or explicitly set, won't be caught
        # NOTE: default erroraction in powershell is "Continue"
        # ------------------------------------------------------------ WAM TESTS BEGIN
        Invoke-Expression -Command "watchmaker --version"  -ErrorAction Stop

        # ------------------------------------------------------------ WAM TESTS END
        
        # if we made it here through all the tests, consider it a success
        $TestStatus=@(0,"Success")
    }
    Catch
    {
        $TestStatus=@(1,"Testing error")
    }
}

# FINALLY after everything, give results
If ( $UserdataStatus[0] -eq 0 -and $TestStatus[0] -eq 0 )
{
    Write-Host (".............................................................................Success!")
}
Else
{
    Write-Host (".............................................................................FAILED!")
    Write-Host ("Userdata Status: ($UserdataStatus[0]) $UserdataStatus[1]")
    Write-Host ("Test Status    : ($TestStatus[0]) $TestStatus[1]")
    exit 1
}


