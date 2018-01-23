GIT_REPO=THIS_IS_NOT_THE_REPO
GIT_BRANCH=THIS_IS_NOT_THE_BRANCH

PIP_URL=https://bootstrap.pypa.io/get-pip.py
PYPI_URL=https://pypi.org/simple

# Install pip
curl "$PIP_URL" | python - --index-url="$PYPI_URL" wheel==0.29.0

# Install git
yum -y install git

# Upgrade pip and setuptools
pip install --index-url="$PYPI_URL" --upgrade pip setuptools boto3

# Clone watchmaker
git clone "$GIT_REPO" --branch "$GIT_BRANCH" --recursive

# Install watchmaker
cd watchmaker
pip install --index-url "$PYPI_URL" --editable .

# Run watchmaker
watchmaker COMMON_COMMAND_LINE_ARGUMENTS_GO_HERE LX_COMMAND_LINE_ARGUMENTS_GO_HERE
