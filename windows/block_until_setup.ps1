function Reload-Profile {
    @(
        $Profile.AllUsersAllHosts,
        $Profile.AllUsersCurrentHost,
        $Profile.CurrentUserAllHosts,
        $Profile.CurrentUserCurrentHost
    ) | % {
        if(Test-Path $_){
            Write-Verbose "Running $_"
            . $_
        }
    }    
}

#Wait for the signal from the userdata script before testing
while (!(Test-Path 'C:\Temp\SETUP_COMPLETE_SIGNAL')) {
  . Reload-Profile
  Write-Host ("Setup not complete. Retrying...")
  Start-Sleep 20 
}
