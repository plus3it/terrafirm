$GitRepo = "${tfi_repo}"
$GitBranch = "${tfi_branch}"
$GitPr = "${tfi_pr}"

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
git clone "$GitRepo" --branch "$GitBranch" --recursive
cd watchmaker
if ($GitPr)
{
  git fetch origin pull/$GitPr/head:pr-$GitPr
  git checkout pr-$GitPr
}

# Install watchmaker
pip install --index-url "$PypiUrl" --editable .

# Run watchmaker
watchmaker ${tfi_common_args} ${tfi_win_args}
