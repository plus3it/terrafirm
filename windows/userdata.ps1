<powershell>

# log of the userdata install
mkdir C:\Temp -ErrorAction SilentlyContinue
Start-Transcript -path ${tfi_win_userdata_log}

# Set Administrator password, for logging in before wam changes Administrator account name to ${tfi_rm_user}
$admin = [adsi]("WinNT://./administrator, user")
$admin.psbase.invoke("SetPassword", "${tfi_rm_pass}")
$admin.psbase.CommitChanges()

# close the firewall
netsh advfirewall firewall add rule name="WinRM in" protocol=TCP dir=in profile=any localport=5985 remoteip=any localip=any action=deny

# this will become the watchmaker portion of install
WATCHMAKER_INSTALL_GOES_HERE

# Set Administrator password - should always go after wm install because username not yet changed
$admin = [adsi]("WinNT://./${tfi_rm_user}, user")
$admin.psbase.invoke("SetPassword", "${tfi_rm_pass}")
$admin.psbase.CommitChanges()

# open firewall for winrm
netsh advfirewall firewall add rule name="WinRM in" protocol=TCP dir=in profile=any localport=5985 remoteip=any localip=any action=allow

# fix the lgpos to allow winrm
C:\salt\salt-call --local -c C:\Watchmaker\salt\conf lgpo.set_reg_value `
    key='HKLM\SOFTWARE\Policies\Microsoft\Windows\WinRM\Service\AllowBasic' `
    value='1' `
    vtype='REG_DWORD'
    
C:\salt\salt-call --local -c C:\Watchmaker\salt\conf lgpo.set_reg_value `
    key='HKLM\SOFTWARE\Policies\Microsoft\Windows\WinRM\Service\AllowUnencryptedTraffic' `
    value='1' `
    vtype='REG_DWORD'
    
Stop-Transcript

# upload logs to S3 bucket
$S3_TOP_KEYFIX=Get-Date -UFormat "%Y%m%d"
$RAND=-join ((48..57) + (65..90) + (97..122) | Get-Random -Count 4 | % {[char]$_})
$OS_VERSION="Win" + (((Get-WmiObject -class Win32_OperatingSystem).Caption) -replace '.+(\d\d)\s(.{2}).+','$1$2')
$S3_KEYFIX=(Get-Date -UFormat "%Y%m%d_%H%M%S_") + $OS_VERSION + "_" + $RAND

Write-S3Object -BucketName "${tfi_s3_bucket}" -File ${tfi_win_userdata_log} -KeyPrefix $S3_TOP_KEYFIX/$S3_KEYFIX/ -ErrorAction SilentlyContinue
Write-S3Object -BucketName "${tfi_s3_bucket}" -Folder "C:\\Program Files\\Amazon\\Ec2ConfigService\\Logs" -KeyPrefix $S3_TOP_KEYFIX/$S3_KEYFIX/cloud-init/ -ErrorAction SilentlyContinue
Write-S3Object -BucketName "${tfi_s3_bucket}" -Folder "C:\\ProgramData\\Amazon\\EC2-Windows\\Launch\\Log" -KeyPrefix $S3_TOP_KEYFIX/$S3_KEYFIX/cloud-init/ -ErrorAction SilentlyContinue
Write-S3Object -BucketName "${tfi_s3_bucket}" -Folder "C:\\Watchmaker\\Logs" -KeyPrefix $S3_TOP_KEYFIX/$S3_KEYFIX/watchmaker/ -SearchPattern *.log -ErrorAction SilentlyContinue

# script will setup winrm and set the timeout
</powershell>
<script>
winrm quickconfig -q & winrm set winrm/config @{MaxTimeoutms="1900000"} 
</script>
