  $GitRepo = "${tfi_git_repo}"
  $GitRef = "${tfi_git_ref}"

  $BootstrapUrl = "https://raw.githubusercontent.com/plus3it/watchmaker/master/docs/files/bootstrap/watchmaker-bootstrap.ps1"
  $PythonUrl = "https://www.python.org/ftp/python/3.6.3/python-3.6.3-amd64.exe"
  $GitUrl = "https://github.com/git-for-windows/git/releases/download/v2.14.3.windows.1/Git-2.14.3-64-bit.exe"
  $PypiUrl = "https://pypi.org/simple"

  # Download bootstrap file
  $Stage = "download bootstrap"
  $BootstrapFile = "$${Env:Temp}\$($${BootstrapUrl}.split("/")[-1])"
  (New-Object System.Net.WebClient).DownloadFile($BootstrapUrl, $BootstrapFile)

  # Install python and git
  $Stage = "install python/git"
  & "$BootstrapFile" `
      -PythonUrl "$PythonUrl" `
      -GitUrl "$GitUrl" `
      -Verbose -ErrorAction Stop

  # Upgrade pip and setuptools
  $Stage = "upgrade pip setuptools boto3"
  Invoke-Expression -Command "pip install --index-url=`"$PypiUrl`" --upgrade pip setuptools boto3" -ErrorAction Stop
  # pip install --index-url="$PypiUrl" --upgrade pip setuptools boto3

  # Clone watchmaker
  $Stage = "git"
  Invoke-Expression -Command "git clone `"$GitRepo`" --recursive" -ErrorAction Stop
  Tfi-Out "git clone $GitRepo" $?
  cd watchmaker
  if ($GitRef)
  {
    # decide whether to switch to pull request or branch
    if($GitRef -match "^[0-9]+$")
    {
      Invoke-Expression -Command "git fetch origin pull/$GitRef/head:pr-$GitRef" -ErrorAction Stop
      Tfi-Out "git fetch (pr: $GitRef)" $?
      Invoke-Expression -Command "git checkout pr-$GitRef" -ErrorAction Stop
      Tfi-Out "git checkout (pr: $GitRef)" $?
    }
    else
    {
      Invoke-Expression -Command "git checkout $GitRef" -ErrorAction Stop
      Tfi-Out "git checkout (ref: $GitRef)" $?
    }
  }

  # Install watchmaker
  $Stage = "install wam"
  Invoke-Expression -Command "pip install --index-url `"$PypiUrl`" --editable . " -ErrorAction Stop

  # Run watchmaker
  # Need to make sure that args have no quotes in them or this will fail
  $Stage = "run wam"
  Tfi-Out ("Make sure that wam args do not have unescaped quotes - for Windows/powershell args use the backtick to escape quotes")
  Invoke-Expression -Command "watchmaker ${tfi_common_args} ${tfi_win_args}" -ErrorAction Stop
