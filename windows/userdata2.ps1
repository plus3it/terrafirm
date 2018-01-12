<script>
  winrm quickconfig -q & winrm set winrm/config @{MaxTimeoutms="1800000"} & winrm set winrm/config/service @{AllowUnencrypted="true"} & winrm set winrm/config/service/auth @{Basic="true"}
</script>
<powershell>
# Get ready for winrm for terraform winrm provisioner connection

# open firewall for winrm
netsh advfirewall firewall add rule name="WinRM in" protocol=TCP dir=in profile=any localport=5985 remoteip=any localip=any action=allow

# Set Administrator password
$admin = [adsi]("WinNT://./administrator, user")
$admin.psbase.invoke("SetPassword", "THIS_IS_NOT_THE_PASSWORD")
$admin.description = "Stage0"
$admin.psbase.CommitChanges()

Start-Sleep 360

$admin.description = "Stage1"
$admin.psbase.CommitChanges()

Start-Sleep 360

$admin.description = "Stage2"
$admin.psbase.CommitChanges()

Start-Sleep 360

$admin.description = "Stage3"
$admin.psbase.CommitChanges()

</powershell>
