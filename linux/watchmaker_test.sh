#!/bin/bash

echo "*****************************************************************************"
echo "Running Watchmaker test script: LINUX"
echo "*****************************************************************************"

cat /tmp/userdata_install.txt

wait_file() {
  local file="$1"; shift
  local wait_seconds="${1:-10}"; shift # 10 seconds as default timeout

  until test $((wait_seconds--)) -eq 0 -o -f "$file" ; do
    echo "Call to watchmaker FAILED. Trying again in 30 seconds..."
    sleep 30
  done
  
  if [ -f "$file" ]; then
    echo ".............................................................................Success!"
  fi

  ((++wait_seconds))
}

exec_file=/usr/bin/watchmaker

wait_file "$exec_file" 12 || {
  echo "Executable on remote instance never became available for $? seconds: '$exec_file'"
  exit 1
}

watchmaker --version
