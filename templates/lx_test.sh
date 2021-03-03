#!/bin/bash -e

export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8

build_os="${build_os}"
build_type="${build_type}"
build_label="${build_label}"
build_type_builder="${build_type_builder}"
build_type_standalone="${build_type_standalone}"

finally() {
  local exit_code=0

  if [ $${userdata_status[0]} -ne 0 ] || [ $${test_status[0]} -ne 0 ] ; then
    echo "........................................................FAILED!"
    echo "Userdata Status: ($${userdata_status[0]}) $${userdata_status[1]}"
    echo "Test Status    : ($${test_status[0]}) $${test_status[1]}"
    ((exit_code=userdata_status[0]+test_status[0]))

    if [ "$exit_code" -eq 0 ] ; then
      exit_code=1
    fi
  else
    echo ".......................................................Success!"
  fi

  exit "$exit_code"
}

catch() {
  local exit_code="$${1:-1}"

  test_status=("$exit_code" "Testing error")

  finally
}

trap 'catch $? $LINENO' ERR

echo "***************************************************************"
echo "Running Watchmaker Test: $build_label"
echo "***************************************************************"

# everything below this is the TRY
if [ -f "/etc/redhat-release" ]; then
  # this will only work for redhat and centos
  cat /etc/redhat-release
else
  lsb_release -a
fi

ud_path="${userdata_status_file}"

if [ -f "$ud_path" ] ; then
  readarray -t userdata_status < "$ud_path"
else
  userdata_status=(1 "No status returned by userdata")
fi

test_status=(0 "Not run")

if [ "$build_type" != "$build_type_builder" ] && [ "$${userdata_status[0]}" -eq 0 ]; then
  # ------------------------------------------------------------ WAM TESTS BEGIN
  if [ "$build_type" = "$build_type_standalone" ]; then
    ./watchmaker --version
  else
    watchmaker --version
  fi

  # Test sudo is functional
  sudo --non-interactive --list
  # ------------------------------------------------------------ WAM TESTS END
fi

test_status=(0 "Passed")

finally
