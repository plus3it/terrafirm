GIT_REPO="${tfi_git_repo}"
GIT_REF="${tfi_git_ref}"

PIP_URL=https://bootstrap.pypa.io/get-pip.py
PYPI_URL=https://pypi.org/simple

# Install pip
curl "$PIP_URL" | python - --index-url="$PYPI_URL" wheel==0.29.0

# Install git
yum -y install git

# Upgrade pip and setuptools
pip install --index-url="$PYPI_URL" --upgrade pip setuptools boto3

# Clone watchmaker
git clone "$GIT_REPO" --recursive
cd watchmaker
if [ ! -z "$GIT_REF" ] ; then
  if [[ "$GIT_REF" =~ '^[0-9]+$' ]] ; then
    git fetch origin pull/$GIT_REF/head:pr-$GIT_REF
    git checkout pr-$GIT_REF
  else
    git checkout $GIT_REF
  fi
fi

# Install watchmaker
pip install --index-url "$PYPI_URL" --editable .

# Run watchmaker
watchmaker ${tfi_common_args} ${tfi_lx_args}
