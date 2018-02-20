
GIT_REPO="${tfi_git_repo}"
GIT_REF="${tfi_git_ref}"

PIP_URL=https://bootstrap.pypa.io/get-pip.py
PYPI_URL=https://pypi.org/simple

# Install pip
stage="install python/git" && curl "$PIP_URL" | python - --index-url="$PYPI_URL" wheel==0.29.0

# Install git
yum -y install git

# Upgrade pip and setuptools
stage="upgrade pip/setuptools/boto3" && pip install --index-url="$PYPI_URL" --upgrade pip setuptools boto3

# Clone watchmaker
stage="git" && git clone "$GIT_REPO" --recursive
cd watchmaker
if [ -n "$GIT_REF" ] ; then
  # decide whether to switch to pull request or a branch
  num_re='^[0-9]+$'
  if [[ "$GIT_REF" =~ $num_re ]] ; then
    stage="git pr (Repo: $GIT_REPO, PR: $GIT_REF)"
    git fetch origin pull/$GIT_REF/head:pr-$GIT_REF
    git checkout pr-$GIT_REF
  else
    stage="git ref (Repo: $GIT_REPO, Ref: $GIT_REF)"
    git checkout $GIT_REF
  fi
fi

# Install watchmaker
stage="install wam" && pip install --index-url "$PYPI_URL" --editable .

# Run watchmaker
stage="run wam" && watchmaker ${tfi_common_args} ${tfi_lx_args}
