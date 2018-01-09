function Retry-Command
{
    param (
     [Parameter(Mandatory=$true)][string]$command,
     [Parameter(Mandatory=$false)][int]$retries = 5,
     [Parameter(Mandatory=$false)][int]$secondsDelay = 2
    )

    $retrycount = 0
    $success = $false

    while (-not $success) {
        try {
            Invoke-Expression -Command:$command
            Write-Host ("Command [{0}] succeeded." -f $command)
            Write-Host (".............................................................................Success!")
            $success = $true
        } catch {
            if ($retrycount -ge $retries) {
                Write-Host ("Command [{0}] failed the maximum number of {1} times." -f $command, $retrycount)
                throw
            } else {
                Write-Host ("Command [{0}] failed. Retrying in {1} seconds." -f $command, $secondsDelay)
                Start-Sleep $secondsDelay
                $retrycount++
            }
        }
    }
    
    return $success
}

Write-Host ("*****************************************************************************")
Write-Host ("Running Watchmaker test script: WINDOWS")
Write-Host ("*****************************************************************************")

#Wait for the signal from the userdata script before testing
while (!(Test-Path "C:\scripts\SIGNAL.txt")) {
    Write-Host ("Waiting for Watchmaker install to complete...")
    Start-Sleep 20 
}

#Perform test
Write-Host ("Performing test...")
Retry-Command -Command 'watchmaker --version' -Retries 3 -SecondsDelay 30
