#!/bin/bash

echo "**************************************************************************************************"
echo "Running Watchmaker test script"
echo "**************************************************************************************************"


wait_file() {
  local file="$1"; shift
  local wait_seconds="${1:-10}"; shift # 10 seconds as default timeout

  until test $((wait_seconds--)) -eq 0 -o -f "$file" ; do sleep 5; done

  ((++wait_seconds))
}

exec_file=/usr/bin/watchmaker

wait_file "$exec_file" 100 || {
  echo "Executable on remote instance never became available for $? seconds: '$exec_file'"
  exit 1
}

echo "Version number: " ; /usr/bin/watchmaker --version
