#!/bin/bash -e
# shellcheck disable=SC2269

build_os="${build_os}"
build_type="${build_type}"
build_label="${build_label}"
build_type_builder="${build_type_builder}"
build_type_standalone="${build_type_standalone}"
build_slug="${build_slug}"
userdata_log="${userdata_log}"
userdata_status_file="${userdata_status_file}"
userdata_s3_prefix=""
userdata_status_code=1
userdata_status_message="No status returned by userdata"
test_status_code=0
test_status_message="Not run"

print_userdata_log_tail() {
  local log_file="$1"
  local tail_lines="$${2:-120}"

  if [[ -f "$log_file" ]]; then
    echo "----------------------- userdata.log (last $${tail_lines} lines) -----------------------"
    tail -n "$tail_lines" "$log_file" || true
    echo "-----------------------------------------------------------------------------"
  else
    echo "Userdata log file not found at path: $log_file"
  fi
}

parse_userdata_status() {
  local ud_path="$1"

  if [[ ! -f "$ud_path" ]]; then
    userdata_status_code=1
    userdata_status_message="No status returned by userdata"
    return
  fi

  local parsed
  parsed=$(jq -r '
    [
      (.code // 1),
      (.message // "No status returned by userdata"),
      (.log_path // ""),
      (.s3_prefix // "")
    ] | .[]
  ' "$ud_path" 2>/dev/null || true)

  if [[ -n "$parsed" ]]; then
    local parsed_code
    local parsed_message
    local parsed_log_path
    local parsed_s3_prefix
    parsed_code=$(printf '%s\n' "$parsed" | sed -n '1p')
    parsed_message=$(printf '%s\n' "$parsed" | sed -n '2p')
    parsed_log_path=$(printf '%s\n' "$parsed" | sed -n '3p')
    parsed_s3_prefix=$(printf '%s\n' "$parsed" | sed -n '4p')

    userdata_status_code="$parsed_code"
    userdata_status_message="$parsed_message"
    if [[ -n "$parsed_log_path" ]]; then
      userdata_log="$parsed_log_path"
    fi
    if [[ -n "$parsed_s3_prefix" ]]; then
      userdata_s3_prefix="$parsed_s3_prefix"
    fi
    return
  fi

  # Legacy fallback format: one line for status code and one line for message.
  userdata_status_code=$(sed -n '1p' "$ud_path")
  userdata_status_message=$(sed -n '2p' "$ud_path")
  if [[ -z "$userdata_status_code" ]]; then
    userdata_status_code=1
  fi
  if [[ -z "$userdata_status_message" ]]; then
    userdata_status_message="No status returned by userdata"
  fi
}

finally() {
  local exit_code=0
  if [[ "$userdata_status_code" -ne 0 || "$test_status_code" -ne 0 ]]; then
    echo "........................................................FAILED!"
    echo "Userdata Status: ($userdata_status_code) $userdata_status_message"
    if [[ -z "$userdata_s3_prefix" ]]; then
      userdata_s3_prefix="s3://$build_slug/$build_label"
    fi
    echo "Userdata Logs S3 Prefix: $userdata_s3_prefix"
    echo "Userdata Log Path: $userdata_log"
    echo "Test Status    : ($test_status_code) $test_status_message"
    print_userdata_log_tail "$userdata_log" 120
    ((exit_code=userdata_status_code+test_status_code))

    if [[ "$exit_code" -eq 0 ]]; then
      exit_code=1
    fi
  else
    echo ".......................................................Success!"
  fi

  exit "$exit_code"
}

# shellcheck disable=SC2317,SC2329
catch() {
  local exit_code="$${1:-1}"
  test_status_code="$exit_code"
  test_status_message="Testing error"

  finally
}

trap 'catch $? $LINENO' ERR

echo "***************************************************************"
echo "Running Watchmaker Test: $build_label"
echo "***************************************************************"

# everything below this is the TRY
if [[ -f "/etc/redhat-release" ]]; then
  # this will only work for redhat and centos
  cat /etc/os-release
else
  lsb_release -a
fi

ud_path="$userdata_status_file"
parse_userdata_status "$ud_path"

if [[ "$build_type" != "$build_type_builder" && "$userdata_status_code" -eq 0 ]]; then
  # ------------------------------------------------------------ WAM TESTS BEGIN
  if [[ "$build_type" == "$build_type_standalone" ]]; then
    sudo env PATH="$PATH" ./watchmaker --version
  else
    sudo env PATH="$PATH" watchmaker --version
  fi

  # Test sudo is functional
  sudo --non-interactive --list
  # ------------------------------------------------------------ WAM TESTS END
fi

test_status_code=0
test_status_message="Passed"

finally
