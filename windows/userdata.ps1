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

# time wam install
$start=Get-Date

# this will become the watchmaker portion of install
WATCHMAKER_INSTALL_GOES_HERE

$end=Get-Date
Write-Host ("WAM install took {0} seconds." -f [math]::Round(($end - $start).TotalSeconds)) -ErrorAction SilentlyContinue

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
$S3_TOP_KEYFIX=("${tfi_build_id}" -split "_",2)[0]
$BUILD_ID=("${tfi_build_id}" -split "_",3)[2]
#$RAND=-join ((65..90) + (97..122) | Get-Random -Count 4 | % {[char]$_})
$OS_VERSION="Win" + (((Get-WmiObject -class Win32_OperatingSystem).Caption) -replace '.+(\d\d)\s(.{2}).+','$1$2')
If ($OS_VERSION.Substring($OS_VERSION.get_Length()-2) -eq 'Da') {
  $OS_VERSION=$OS_VERSION -replace ".{2}$"
}
#$S3_KEYFIX=(Get-Date -UFormat "%H%M%S_") + $OS_VERSION
$S3_KEYFIX=$OS_VERSION

Write-S3Object -BucketName "${tfi_s3_bucket}/$S3_TOP_KEYFIX/$BUILD_ID/$S3_KEYFIX" -File ${tfi_win_userdata_log} -ErrorAction SilentlyContinue
Write-S3Object -BucketName "${tfi_s3_bucket}" -Folder "C:\\Program Files\\Amazon\\Ec2ConfigService\\Logs" -KeyPrefix $S3_TOP_KEYFIX/$BUILD_ID/$S3_KEYFIX/cloud-init/ -ErrorAction SilentlyContinue
Write-S3Object -BucketName "${tfi_s3_bucket}" -Folder "C:\\ProgramData\\Amazon\\EC2-Windows\\Launch\\Log" -KeyPrefix $S3_TOP_KEYFIX/$BUILD_ID/$S3_KEYFIX/cloud-init/ -ErrorAction SilentlyContinue
Write-S3Object -BucketName "${tfi_s3_bucket}" -Folder "C:\\Watchmaker\\Logs" -KeyPrefix $S3_TOP_KEYFIX/$BUILD_ID/$S3_KEYFIX/watchmaker/ -SearchPattern *.log -ErrorAction SilentlyContinue

# script will setup winrm and set the timeout
</powershell>
<script>
winrm quickconfig -q & winrm set winrm/config @{MaxTimeoutms="1900000"} 
</script>
