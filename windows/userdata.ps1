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
$admin.description = "State0"
$admin.psbase.CommitChanges()

#### watchmaker starts here ####
$GitRepo = "THIS_IS_NOT_THE_REPO"
$GitBranch = "THIS_IS_NOT_THE_BRANCH"

$BootstrapUrl = "https://raw.githubusercontent.com/plus3it/watchmaker/master/docs/files/bootstrap/watchmaker-bootstrap.ps1"
$PythonUrl = "https://www.python.org/ftp/python/3.6.3/python-3.6.3-amd64.exe"
$GitUrl = "https://github.com/git-for-windows/git/releases/download/v2.14.3.windows.1/Git-2.14.3-64-bit.exe"
$PypiUrl = "https://pypi.org/simple"

# Download bootstrap file
$BootstrapFile = "${Env:Temp}\$(${BootstrapUrl}.split("/")[-1])"
(New-Object System.Net.WebClient).DownloadFile($BootstrapUrl, $BootstrapFile)

# Install python and git
& "$BootstrapFile" `
    -PythonUrl "$PythonUrl" `
    -GitUrl "$GitUrl" `
    -Verbose -ErrorAction Stop

# Upgrade pip and setuptools
pip install --index-url="$PypiUrl" --upgrade pip setuptools boto3
$admin.description = "State1"
$admin.psbase.CommitChanges()

# Clone watchmaker
git clone "$GitRepo" --branch "$GitBranch" --recursive

# Install watchmaker
cd watchmaker
pip install --index-url "$PypiUrl" --editable .
$admin.description = "State2"
$admin.psbase.CommitChanges()

# Run watchmaker
watchmaker -n --log-level debug --log-dir=C:\Watchmaker\Logs
$admin = [adsi]("WinNT://./administrator, user")
$admin.description = "State3"
$admin.psbase.CommitChanges()

# Signal completion of userdata
New-Item 'C:\Temp\SETUP_COMPLETE_SIGNAL' -type file -force

</powershell>
