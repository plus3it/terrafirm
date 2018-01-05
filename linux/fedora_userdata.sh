#!/bin/sh

exec &> /tmp/fedora_install.txt

PIP_URL=https://bootstrap.pypa.io/get-pip.py
PYPI_URL=https://pypi.org/simple

# Install pip
curl "$PIP_URL" | python - --index-url="$PYPI_URL" wheel==0.29.0

# Fedora
dnf install -y python-pip
dnf install -y python3

# Install watchmaker
pip install --index-url="$PYPI_URL" --upgrade pip setuptools watchmaker

# Run watchmaker
watchmaker -n --log-level debug --log-dir=/var/log/watchmaker
