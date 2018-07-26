#!/bin/bash

finally() {
  local exit_code="$${1:-0}"

  # FINALLY after everything, give results
  if [ "$${userdata_status[0]}" -ne 0 ]; then
    echo ".............................................................................FAILED!"
    echo "Userdata Status: ($${userdata_status[0]}) $${userdata_status[1]}"
    exit_code=$${userdata_status[0]}
    if [ "$${exit_code}" -eq 0 ] ; then
      exit_code=1
    fi
  else
    echo ".............................................................................Success!"
  fi
  exit "$${exit_code}"
}

catch() {
  local this_script="$0"
  local exit_code="$1"
  local err_lineno="$2"

  test_status=($exit_code "Testing error")

  finally $@ #important to call here and as the last line of the script
}

trap 'catch $? $${LINENO}' ERR

# everything below this is the TRY

echo "*****************************************************************************"
echo "Running Linux standalone package builder test script: ${tfi_ami_key}"
echo "*****************************************************************************"
lsb_release -a # this works on Ubuntu

ud_path=${tfi_userdata_status_file}

if [ -f "$${ud_path}" ] ; then
  # file exists, read into variable
  readarray -t userdata_status < "$${ud_path}"
else
  # error, no userdata status found
  userdata_status=(1 "No status returned by userdata")
fi

finally
