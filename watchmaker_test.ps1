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

Retry-Command -Command 'wotchmaker --version' -Retries 3 -SecondsDelay 30
