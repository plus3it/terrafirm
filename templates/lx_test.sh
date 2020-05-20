#!/bin/bash

export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8

instance_os="${instance_os}"
instance_type="${instance_type}"
instance_slug="lx_$instance_type-$instance_os"

finally() {
  local exit_code=0

  if [ "$${userdata_status[0]}" -ne 0 ] || [ "$${test_status[0]}" -ne 0 ] ; then
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
case "$instance_type" in
  builder)
    test_title="Standalone Builder"
    ;;
  sa)
    test_title="Standalone"
    ;;
  src)
    test_title="From Source"
    ;;
esac
echo "Running Watchmaker $test_title Test ($instance_slug)"
echo "***************************************************************"

# everything below this is the TRY
if [ "$instance_os" = "xenial" ]; then
  lsb_release -a
else
  # this will only work for redhat and centos
  cat /etc/redhat-release
fi

ud_path="${userdata_status_file}"

if [ -f "$ud_path" ] ; then
  readarray -t userdata_status < "$ud_path"
else
  userdata_status=(1 "No status returned by userdata")
fi

test_status=(0 "Not run")

if [ "$instance_type" != "builder" ] && [ "$${userdata_status[0]}" -eq 0 ]; then
  # ------------------------------------------------------------ WAM TESTS BEGIN
  if [ "$instance_type" = "sa" ]; then
    ./watchmaker --version
  else
    watchmaker --version
  fi
  # ------------------------------------------------------------ WAM TESTS END
fi

test_status=(0 "Passed")

finally
