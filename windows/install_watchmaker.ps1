$GitRepo = "${tfi_git_repo}"
$GitRef = "${tfi_git_ref}"

$BootstrapUrl = "https://raw.githubusercontent.com/plus3it/watchmaker/master/docs/files/bootstrap/watchmaker-bootstrap.ps1"
$PythonUrl = "https://www.python.org/ftp/python/3.6.3/python-3.6.3-amd64.exe"
$GitUrl = "https://github.com/git-for-windows/git/releases/download/v2.14.3.windows.1/Git-2.14.3-64-bit.exe"
$PypiUrl = "https://pypi.org/simple"

# Download bootstrap file
$BootstrapFile = "$${Env:Temp}\$($${BootstrapUrl}.split("/")[-1])"
(New-Object System.Net.WebClient).DownloadFile($BootstrapUrl, $BootstrapFile)

# Install python and git
& "$BootstrapFile" `
    -PythonUrl "$PythonUrl" `
    -GitUrl "$GitUrl" `
    -Verbose -ErrorAction Stop

# Upgrade pip and setuptools
pip install --index-url="$PypiUrl" --upgrade pip setuptools boto3

# Clone watchmaker
git clone "$GitRepo" --recursive
cd watchmaker
if ($GitRef)
{
  if($GitRef -match "^[0-9]+$")
  {
    git fetch origin pull/$GitRef/head:pr-$GitRef
    git checkout pr-$GitRef
  }
  else
  {
    git checkout $GitRef
  }

}

# Install watchmaker
pip install --index-url "$PypiUrl" --editable .

# Run watchmaker
watchmaker ${tfi_common_args} ${tfi_win_args}
