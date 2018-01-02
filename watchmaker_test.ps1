function Retry-Command
{
    param (
    [Parameter(Mandatory=$true)][string]$command, 
    [Parameter(Mandatory=$true)][hashtable]$args, 
    [Parameter(Mandatory=$false)][int]$retries = 5, 
    [Parameter(Mandatory=$false)][int]$secondsDelay = 2
    )
    
    # Setting ErrorAction to Stop is important. This ensures any errors that occur in the command are 
    # treated as terminating errors, and will be caught by the catch block.
    $args.ErrorAction = "Stop"
    
    $retrycount = 0
    $completed = $false

    while (-not $completed) {
        try {
            & $command @args
            Write-Host ("Command [{0}] succeeded." -f $command) -foreground Green
            $completed = $true
        } catch {
            if ($retrycount -ge $retries) {
                Write-Host ("Command [{0}] failed the maximum number of {1} times." -f $command, $retrycount) -foreground Red
                throw
            } else {
                Write-Host ("Command [{0}] failed. Retrying in {1} seconds." -f $command, $secondsDelay) -foreground Blue
                Start-Sleep $secondsDelay
                $retrycount++
            }
        }
    }
}

Retry-Command -Command 'watchmaker --version' -Retries 15 -SecondsDelay 5
