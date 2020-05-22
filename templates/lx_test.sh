#!/bin/bash

export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8

build_os="${build_os}"
build_type="${build_type}"
build_label="lx_$build_type-$build_os"

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
build_title=$${build_type^}
echo "Running Watchmaker $test_title Build ($build_label)"
echo "***************************************************************"

# everything below this is the TRY
if [ "$build_os" = "xenial" ]; then
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

if [ "$build_type" != "builder" ] && [ "$${userdata_status[0]}" -eq 0 ]; then
  # ------------------------------------------------------------ WAM TESTS BEGIN
  if [ "$build_type" = "standalone" ]; then
    ./watchmaker --version
  else
    watchmaker --version
  fi
  # ------------------------------------------------------------ WAM TESTS END
fi

test_status=(0 "Passed")

finally
