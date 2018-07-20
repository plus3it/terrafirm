$AMIKey = [IO.File]::ReadAllText("C:\scripts\ami-key")

Write-Host ("*****************************************************************************")
Write-Host ("Running Windows standalone package builder test script: $AMIKey")
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


# FINALLY after everything, give results
If ( $UserdataStatus[0] -eq 0 )
{
    Write-Host (".............................................................................Success!")
}
Else
{
    Write-Host (".............................................................................FAILED!")
    Write-Host ("Userdata Status: ($UserdataStatus[0]) $UserdataStatus[1]")
    exit 1
}


