#!/bin/bash
# shellcheck disable=SC2269

aws_region="${aws_region}"
build_label="${build_label}"
build_os="${build_os}"
build_slug="${build_slug}"
build_type="${build_type}"
build_type_source="${build_type_source}"
build_type_standalone="${build_type_standalone}"
debug="${debug}"
docker_slug="${docker_slug}"
executable="${executable}"
git_ref="${git_ref}"
git_repo="${git_repo}"
github_artifact_repo_name="${github_artifact_repo_name}"
github_artifact_repo_owner="${github_artifact_repo_owner}"
github_artifact_run_id="${github_artifact_run_id}"
github_artifact_token_ssm_parameter="${github_artifact_token_ssm_parameter}"
firehose_delivery_stream_name="${firehose_delivery_stream_name}"
port="${port}"
release_prefix="${release_prefix}"
scan_slug="${scan_slug}"
source_source="${source_source}"
standalone_builder="${standalone_builder}"
standalone_error_signal_file="${standalone_error_signal_file}"
standalone_source="${standalone_source}"
temp_dir="${temp_dir}"
url_pypi="${url_pypi}"
userdata_log="${userdata_log}"
userdata_status_file="${userdata_status_file}"
userdata_log_s3_prefix="s3://$build_slug/$build_label"

# Split args once and pass as a safe argv array where needed.
read -r -a args <<< "${args}"

# Default failure snippet for failures that occur outside try_cmd wrappers.
fail_snippet="Unspecified command failure"

exec &> "$userdata_log"

export AWS_DEFAULT_REGION="$aws_region"

echo "------------------------------- $build_label ---------------------"

debug-2s3() {
  ## Keep an incremental local debug log. Final artifact upload handles S3
  ## persistence, which avoids network calls on every log write.
  local msg="$1"

  local debug_file="$temp_dir/debug.log"
  echo "$msg" >> "$debug_file"
}

check-metadata-availability() {
  local metadata_loopback_token="http://169.254.169.254/latest/api/token"
  try_cmd 50 curl -fsSL -X PUT -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" $metadata_loopback_token || {
    write-tfi "Metadata endpoint is not available"
    catch 1 "$LINENO"
  }
}

configure-kinesis-agent() {
  local config_path="/etc/aws-kinesis/agent.json"
  local src_dir="/tmp/aws-kinesis-agent-src"
  local original_pwd=""

  if [[ -z "$firehose_delivery_stream_name" ]]; then
    write-tfi "Kinesis Agent setup skipped: firehose delivery stream name was not provided"
    return 0
  fi

  if command -v dnf > /dev/null 2>&1; then
    try_cmd 3 dnf -y install initscripts || {
      write-tfi "Initscripts install failed via dnf"
      return 0
    }
    try_cmd 3 dnf -y install aws-kinesis-agent || {
      write-tfi "Kinesis Agent install failed via dnf"
      return 0
    }
  elif command -v apt-get > /dev/null 2>&1; then
    try_cmd 3 apt-get -y update || true
    try_cmd 3 apt-get -y install curl tar openjdk-11-jdk-headless || {
      write-tfi "Kinesis Agent install failed: unable to install prerequisites via apt-get"
      return 0
    }

    try_cmd 3 curl -fsSL https://github.com/awslabs/amazon-kinesis-agent/archive/refs/heads/master.tar.gz -o /tmp/aws-kinesis-agent-src.tar.gz || {
      write-tfi "Kinesis Agent install failed: unable to download source archive"
      return 0
    }

    try_cmd 1 rm -rf "$src_dir" || {
      write-tfi "Kinesis Agent install failed: unable to clean source directory"
      return 0
    }

    try_cmd 1 mkdir -p "$src_dir" || {
      write-tfi "Kinesis Agent install failed: unable to prepare source directory"
      return 0
    }

    try_cmd 1 tar -xzf /tmp/aws-kinesis-agent-src.tar.gz --strip-components=1 -C "$src_dir" || {
      write-tfi "Kinesis Agent install failed: unable to extract source archive"
      return 0
    }

    original_pwd=$(pwd)
    cd "$src_dir" || {
      write-tfi "Kinesis Agent install failed: unable to enter source directory"
      return 0
    }

    try_cmd 1 bash ./setup --install || {
      cd "$original_pwd" > /dev/null 2>&1 || true
      write-tfi "Kinesis Agent install failed via setup script"
      return 0
    }

    cd "$original_pwd" > /dev/null 2>&1 || true
  else
    write-tfi "Kinesis Agent setup skipped: package manager not available"
    return 0
  fi

  chmod 644 "$userdata_log" > /dev/null 2>&1 || true

  cat > "$config_path" << EOF
{
  "cloudwatch.emitMetrics": true,
  "firehose.endpoint": "firehose.$aws_region.amazonaws.com",
  "maxConnections": 1,
  "maxSendingThreads": 1,
  "flows": [
    {
      "filePattern": "$userdata_log",
      "deliveryStream": "$firehose_delivery_stream_name",
      "initialPosition": "START_OF_FILE",
      "maxBufferAgeMillis": 1000,
      "maxBufferSizeRecords": 1
    }
  ]
}
EOF

  if command -v systemctl > /dev/null 2>&1; then
    try_cmd 1 systemctl stop aws-kinesis-agent > /dev/null 2>&1 || true
    try_cmd 1 systemctl start aws-kinesis-agent > /dev/null 2>&1 || {
      if pgrep -f "com.amazon.kinesis.streaming.agent.Agent" > /dev/null 2>&1; then
        write-tfi "Kinesis Agent service reported start failure, but agent process is running"
      else
        write-tfi "Kinesis Agent start failed"
      fi
      try_cmd 1 systemctl status aws-kinesis-agent --no-pager -l || true
      [[ -f /var/log/aws-kinesis-agent/aws-kinesis-agent.log ]] && tail -n 80 /var/log/aws-kinesis-agent/aws-kinesis-agent.log || true
      return 0
    }
  elif command -v service > /dev/null 2>&1; then
    try_cmd 1 service aws-kinesis-agent stop > /dev/null 2>&1 || true
    try_cmd 1 service aws-kinesis-agent start > /dev/null 2>&1 || {
      if pgrep -f "com.amazon.kinesis.streaming.agent.Agent" > /dev/null 2>&1; then
        write-tfi "Kinesis Agent service reported start failure, but agent process is running"
      else
        write-tfi "Kinesis Agent start failed"
      fi
      try_cmd 1 service aws-kinesis-agent status || true
      [[ -f /var/log/aws-kinesis-agent/aws-kinesis-agent.log ]] && tail -n 80 /var/log/aws-kinesis-agent/aws-kinesis-agent.log || true
      return 0
    }
  else
    write-tfi "Kinesis Agent installed and configured; restart command not found"
    return 0
  fi

  write-tfi "Kinesis Agent configured for stream $firehose_delivery_stream_name"
  return 0
}

write-tfi() {
  local msg=""
  local result=""

  while [[ "$#" -gt 0 ]]
  do
    case $1 in
      --result)
        result="$2"
        shift
        ;;
      *)
        msg="$msg $1"
        ;;
    esac
    shift
  done
  msg="$(echo -e "$msg" | sed -e 's/^[[:space:]]*//')"

  if [[ "$result" == "" ]]; then
    out_result=""
  elif [[ "$result" == "0" ]]; then
    out_result=": Succeeded"
  else
    out_result=": Failed"
  fi

  echo "$(date +%F_%T): $msg $out_result"

  if [[ "$debug" != "false" ]]; then
    debug-2s3 "$(date +%F_%T): $msg $out_result"
  fi
}

try_cmd() {
  local n=0
  local try=$1
  local result=1
  local ERREXIT=0
  [[ $# -le 1 ]] && {
    echo "Usage $0 <number_of_attempts> <Command>"
    exit $result
  }

  shift 1

  if [[ "$try" -gt 1 ]]; then
    write-tfi "Will try $try time(s) :: $*"
  fi

  if [[ "$SHELLOPTS" == *":errexit:"* ]]; then
    set +e
    ERREXIT=1
  fi

  until [[ $n -ge $try ]]; do
    sleep $n
    write-tfi "Running command :: $*"
    "$@"
    result=$?
    write-tfi "$* :: code $result :: output streamed to $userdata_log" --result "$result"
    if [[ $result -eq 0 ]]; then
      break
    else
      ((n++))
      write-tfi "Attempt $n, command failed :: $*"
      fail_snippet="Command ($*) failed :: code $result :: see $userdata_log for output"
    fi
  done

  if [[ "$ERREXIT" == "1" ]]; then
    set -e
  fi

  return $result
}  # ----------  end of function try_cmd  ----------

# shellcheck disable=SC2329
open-ssh() {
  # open firewall on rhel-like distros and ubuntu, move ssh to non-standard

  local new_lx_port="$port"

  if [[ -f /etc/redhat-release ]] || { [[ -r /etc/os-release ]] && grep -qE '^(ID|ID_LIKE)=(".*(amzn|rhel|fedora).*"|.*(amzn|rhel|fedora).*)$' /etc/os-release; }; then
    ## CentOS / RedHat / Oracle Linux / Amazon Linux 2023

    # allow ssh to be on non-standard port (SEL-enforced rule)
    try_cmd 1 setenforce 0

    # remount /home so remote-exec works
    try_cmd 1 mount -o remount,exec /home

    # ensure default zone is drop and an active zone
    try_cmd 1 firewall-cmd --set-default-zone=drop
    try_cmd 1 firewall-cmd --zone=drop --change-interface=eth0
    try_cmd 1 firewall-cmd --add-port="$new_lx_port"/tcp

    try_cmd 1 sed -i -e "5iPort $new_lx_port" /etc/ssh/sshd_config
    try_cmd 1 sed -i -e 's/Port 22/#Port 22/g' /etc/ssh/sshd_config
    try_cmd 1 systemctl restart sshd

  else
    ## Not CentOS / RedHat / Amazon Linux 2023 (i.e., Ubuntu)

    # open firewall/put ssh on a new port
    try_cmd 1 ufw allow "$new_lx_port"/tcp
    try_cmd 1 sed -i "s/^[#]*Port .*/Port $new_lx_port/g" /etc/ssh/sshd_config
    try_cmd 1 service ssh restart
  fi
}

# shellcheck disable=SC2329
publish-artifacts() {
  local logs_rc=0
  local zip_rc=0
  local rc=0

  # stage, zip, upload artifacts to s3

  # create a directory with all the build artifacts
  artifact_base="$temp_dir/terrafirm"
  artifact_dir="$artifact_base/build-artifacts"
  mkdir -p "$artifact_dir/scap_output"
  mkdir -p "$artifact_dir/cloud/scripts"
  mkdir -p "$artifact_dir/audit"
  mkdir -p "$artifact_dir/messages"
  cp -R /var/log/watchmaker/ "$artifact_dir" || true
  cp -R /root/scap/output/* "$artifact_dir/scap_output/" || true
  cp -R /var/log/cloud*log "$artifact_dir/cloud/" || true
  cp -R /var/lib/cloud/instance/scripts/* "$artifact_dir/cloud/scripts/" || true
  cp -R /var/log/audit/*log "$artifact_dir/audit/" || true
  cp -R /var/log/messages "$artifact_dir/messages/" || true

  # move logs to s3
  artifact_dest="s3://$build_slug/$build_label"
  cp "$userdata_log" "$artifact_dir"
  try_cmd 3 aws s3 cp "$artifact_dir" "$artifact_dest" --recursive
  logs_rc=$?
  write-tfi "Uploaded logs to $artifact_dest" --result "$logs_rc"
  if [[ "$logs_rc" -ne 0 ]]; then
    rc="$logs_rc"
  fi

  # creates compressed archive to upload to s3
  zip_file="$artifact_base/$${build_slug//\//-}-$build_label.tgz"
  cd "$artifact_dir"
  try_cmd 2 tar -cvzf "$zip_file" .
  zip_rc=$?
  if [[ "$zip_rc" -eq 0 ]]; then
    try_cmd 3 aws s3 cp "$zip_file" "s3://$build_slug/"
    zip_rc=$?
  fi
  if [[ "$zip_rc" -eq 0 ]]; then
    write-tfi "Uploaded artifact zip to S3" --result "$zip_rc"
  else
    write-tfi "Failed to upload artifact zip to S3" --result "$zip_rc"
  fi
  if [[ "$rc" -eq 0 && "$zip_rc" -ne 0 ]]; then
    rc="$zip_rc"
  fi

  return "$rc"
}

github-artifact-name() {
  if [[ "$standalone_builder" == "pyapp" ]]; then
    echo "standalone-pyapp-dists-linux"
    return
  fi
  echo "standalone-dists-linux"
}

get-github-token() {
  if [[ -z "$github_artifact_token_ssm_parameter" ]]; then
    write-tfi "github_artifact_token_ssm_parameter must be set when standalone_source is github_actions_artifact"
    return 1
  fi

  aws ssm get-parameter \
    --name "$github_artifact_token_ssm_parameter" \
    --with-decryption \
    --query 'Parameter.Value' \
    --output text
}

install-standalone-from-github-artifact() {
  local artifact_name
  local token
  local artifact_json
  local artifact_url
  local artifact_zip
  local extract_dir
  local executable_path

  if [[ -z "$github_artifact_run_id" ]]; then
    write-tfi "github_artifact_run_id must be set when standalone_source is github_actions_artifact" >&2
    return 1
  fi

  artifact_name=$(github-artifact-name)
  token=$(get-github-token) || return 1

  write-tfi "Querying GitHub artifact metadata for $artifact_name from run $github_artifact_run_id" >&2
  artifact_json=$(curl -fsSL \
    -H "Authorization: Bearer $token" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/repos/$github_artifact_repo_owner/$github_artifact_repo_name/actions/runs/$github_artifact_run_id/artifacts") || return 1

  artifact_url=$(echo "$artifact_json" | jq -r ".artifacts[] | select(.name == \"$artifact_name\") | .archive_download_url")

  if [[ -z "$artifact_url" ]]; then
    write-tfi "GitHub artifact $artifact_name was not found for run $github_artifact_run_id" >&2
    return 1
  fi

  artifact_zip="$temp_dir/$artifact_name.zip"
  extract_dir="$temp_dir/$artifact_name"
  rm -f "$artifact_zip"
  rm -rf "$extract_dir"
  mkdir -p "$extract_dir"

  write-tfi "Downloading GitHub artifact $artifact_name" >&2
  curl -fsSL \
    -H "Authorization: Bearer $token" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "$artifact_url" -o "$artifact_zip" || return 1

  write-tfi "Extracting GitHub artifact $artifact_name" >&2
  unzip -q "$artifact_zip" -d "$extract_dir" || return 1

  executable_path=$(find "$extract_dir" -type f -name 'watchmaker-*-standalone-linux-x86_64' | head -n 1)

  if [[ -z "$executable_path" ]]; then
    write-tfi "No standalone executable found in GitHub artifact $artifact_name" >&2
    return 1
  fi

  echo "$executable_path"
}

install-source-wheel-from-github-artifact() {
  local artifact_name
  local token
  local artifact_json
  local artifact_url
  local artifact_zip
  local extract_dir
  local wheel_path

  if [[ -z "$github_artifact_run_id" ]]; then
    write-tfi "github_artifact_run_id must be set when source_source is github_actions_artifact" >&2
    return 1
  fi

  artifact_name="dists"
  token=$(get-github-token) || return 1

  write-tfi "Querying GitHub artifact metadata for $artifact_name from run $github_artifact_run_id" >&2
  artifact_json=$(curl -fsSL \
    -H "Authorization: Bearer $token" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/repos/$github_artifact_repo_owner/$github_artifact_repo_name/actions/runs/$github_artifact_run_id/artifacts") || return 1

  artifact_url=$(echo "$artifact_json" | jq -r ".artifacts[] | select(.name == \"$artifact_name\") | .archive_download_url")

  if [[ -z "$artifact_url" ]]; then
    write-tfi "GitHub artifact $artifact_name was not found for run $github_artifact_run_id" >&2
    return 1
  fi

  artifact_zip="$temp_dir/$artifact_name.zip"
  extract_dir="$temp_dir/$artifact_name"
  rm -f "$artifact_zip"
  rm -rf "$extract_dir"
  mkdir -p "$extract_dir"

  write-tfi "Downloading GitHub artifact $artifact_name" >&2
  curl -fsSL \
    -H "Authorization: Bearer $token" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "$artifact_url" -o "$artifact_zip" || return 1

  write-tfi "Extracting GitHub artifact $artifact_name" >&2
  unzip -q "$artifact_zip" -d "$extract_dir" || return 1

  wheel_path=$(find "$extract_dir" -type f -name 'watchmaker-*-py3-none-any.whl' | head -n 1)

  if [[ -z "$wheel_path" ]]; then
    write-tfi "No wheel distribution found in GitHub artifact $artifact_name" >&2
    return 1
  fi

  echo "$wheel_path"
}

# shellcheck disable=SC2329
publish-scap-scan() {
  local rc=0

  # create a directory with scap scan output
  scan_dir="$temp_dir/terrafirm/scan"
  mkdir -p "$scan_dir"
  cp -R /root/scap/output/* "$scan_dir" || true

  # move scan output to s3
  scan_dest="$scan_slug/$build_os"
  try_cmd 3 aws s3 cp "$scan_dir" "$scan_dest" --recursive
  rc=$?
  if [[ "$rc" -eq 0 ]]; then
    write-tfi "Uploaded scap scan to $scan_dest" --result "$rc"
  else
    write-tfi "Failed to upload scap scan to $scan_dest" --result "$rc"
  fi
  return "$rc"
}

# shellcheck disable=SC2329
write-userdata-status() {
  local code="$1"
  local message="$2"
  local rc=0

  jq -cn \
    --argjson code "$code" \
    --arg message "$message" \
    --arg log_path "$userdata_log" \
    --arg s3_prefix "$userdata_log_s3_prefix" \
    --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{code:$code, message:$message, timestamp:$timestamp, log_path:$log_path, s3_prefix:$s3_prefix}' \
    > "$userdata_status_file"
  rc=$?

  write-tfi "Write userdata status file" --result "$rc"
  return "$rc"
}

# shellcheck disable=SC2329
write-current-userdata-status() {
  write-userdata-status "$userdata_status_code" "$userdata_status_message"
}

invoke-post-step() {
  local name="$1"
  local fail_build="$2"
  local errexit_enabled=0
  local rc=0
  shift 2

  if [[ "$SHELLOPTS" == *":errexit:"* ]]; then
    set +e
    errexit_enabled=1
  fi

  "$@"
  rc=$?

  if [[ "$errexit_enabled" == "1" ]]; then
    set -e
  fi

  if [[ "$rc" -eq 0 ]]; then
    write-tfi "Post-step [$name] succeeded" --result 0
    return 0
  fi

  write-tfi "Post-step [$name] failed with exit code $rc" --result "$rc"
  if [[ "$fail_build" == "true" && "$userdata_status_code" == "0" ]]; then
    userdata_status_code="$rc"
    userdata_status_message="Post-step '$name' failed"
  fi
  return 0
}

finally() {
  # Prevent EXIT trap re-entry when finally exits explicitly.
  trap - EXIT

  # time it took to install
  end=$(date +%s)
  runtime=$((end-start))
  write-tfi "WAM install took $runtime seconds."

  # disable fapolicyd so it can't block aws-cli
  if systemctl is-active --quiet fapolicyd; then
    systemctl stop fapolicyd
  fi

  # Write userdata status before opening firewall
  invoke-post-step "Write-UserdataStatus" true write-current-userdata-status
  invoke-post-step "Open-SSH" true open-ssh

  invoke-post-step "Publish-Artifacts" false publish-artifacts
  if [[ "$build_type" == "$build_type_source" && "$scan_slug" != "" ]]; then
    invoke-post-step "Publish-SCAP-Scan" false publish-scap-scan
  fi

  # shellcheck disable=SC2242
  exit "$userdata_status_code"
}

catch() {
  local exit_code="$${1:-1}"
  write-tfi "$0: line $2: exiting with status $1"
  userdata_status_code="$exit_code"
  userdata_status_message="Userdata install error: $fail_snippet"
  finally
}

install-docker() {
  echo "Install new docker..."
  # https://docs.docker.com/install/linux/docker-ce/ubuntu/
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
  apt-key fingerprint 0EBFCD88

  add-apt-repository \
    "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) \
    stable"
  apt-get update
  apt-get -y install docker-ce docker-ce-cli containerd.io
}

# shellcheck disable=SC2317,SC2329
clone-watchmaker() {
  rm -rf watchmaker
  git clone "$GIT_REPO" --recursive
}

install-watchmaker-prereqs() {
  PYPI_URL="$url_pypi"

  # Install pip
  try_cmd 2 python3 -m ensurepip --upgrade --default-pip

  # Upgrade pip
  try_cmd 2 python3 -m pip install --index-url="$PYPI_URL" --upgrade pip
  try_cmd 1 python3 -m pip --version

  # Install boto3
  try_cmd 1 python3 -m pip install --index-url="$PYPI_URL" --upgrade boto3
}

install-watchmaker() {
  # install watchmaker from source

  GIT_REPO="$git_repo"
  GIT_REF="$git_ref"
  PYPI_URL="$url_pypi"

  install-watchmaker-prereqs

  install-watchmaker-from-git
}

install-watchmaker-from-git() {
  GIT_REPO="$git_repo"
  GIT_REF="$git_ref"

  # Clone watchmaker
  try_cmd 3 clone-watchmaker

  cd watchmaker
  if [[ -n "$GIT_REF" ]]; then
    # decide whether to switch to pull request or a branch
    num_re='^[0-9]+$'
    if [[ "$GIT_REF" =~ $num_re ]] ; then
      try_cmd 1 git fetch origin +refs/pull/"$GIT_REF"/merge:"$GIT_REF"
    elif [[ "$GIT_REF" =~ ^refs/pull/.* ]] ; then
      try_cmd 1 git fetch origin +"$GIT_REF":"$GIT_REF"
    fi
    try_cmd 1 git checkout "$GIT_REF"
  fi

  # Update submodule refs
  try_cmd 1 git submodule sync
  try_cmd 1 git submodule update --init --recursive --force

  # Install watchmaker
  try_cmd 1 python3 -m pip install --upgrade --index-url "$PYPI_URL" --editable .
  try_cmd 1 watchmaker --version
}

install-watchmaker-from-github-artifact() {
  local wheel_path

  install-watchmaker-prereqs
  wheel_path=$(install-source-wheel-from-github-artifact) || return 1
  try_cmd 1 python3 -m pip install --upgrade --index-url "$url_pypi" "$wheel_path"
  try_cmd 1 watchmaker --version
}

# everything below this is the TRY

# start time of install
start=$(date +%s)

# hold userdata status details for final reporting and status file output
userdata_status_code=0
userdata_status_message="Success"

configure-kinesis-agent

# shellcheck disable=SC1083,SC2288
%{ if build_type == build_type_builder }

# BUILDER INPUT -------------------------------------------
export DEBIAN_FRONTEND=noninteractive
virtualenv_base=/opt/wam
virtualenv_path="$virtualenv_base/venv"
virtualenv_activate_script="$virtualenv_path/bin/activate"
# ---------------------------------------------------------

# shellcheck disable=SC2317,SC2329
handle_builder_exit() {
  if [[ "$1" != "0" ]]; then
    echo "For more information on the error, see the lx_builder/userdata.log file." > "$temp_dir/error.log"
    echo "$0: line $2: exiting with status $1" >> "$temp_dir/error.log"

    artifact_dest="s3://$build_slug/$standalone_error_signal_file"
    write-tfi "Signaling error at $artifact_dest"
    if aws s3 cp "$temp_dir/error.log" "$artifact_dest"; then
      write-tfi "Uploaded error signal" --result 0
    else
      write-tfi "Failed to upload error signal" --result $?
    fi

    catch "$@"

  else
    finally "$@"
  fi
}

# setup error trap to go to signal_error function
set -eu -o pipefail
trap 'handle_builder_exit $? $LINENO' EXIT

try_cmd 3 apt-get -y update && apt-get -y install awscli

# to resolve the issue with "sudo: unable to resolve host"
# https://forums.aws.amazon.com/message.jspa?messageID=495274
host_ip=$(hostname)
if [[ $host_ip =~ ^[a-z]*-[0-9]{1,3}-[0-9]{1,3}-[0-9]{1,3}-[0-9]{1,3}$ ]]; then
  # hostname is ip
  ip="$${host_ip#*-}"
  ip="$${ip//-/.}"
  try_cmd 1 echo "$ip $host_ip" >> /etc/hosts
else
  try_cmd 1 echo "127.0.1.1 $host_ip" >> /etc/hosts
fi

try_cmd 1 echo "ARRAY <ignore> devices=/dev/sda" >> /etc/mdadm/mdadm.conf

export DEBIAN_FRONTEND=noninteractive
try_cmd 1 apt-get -y \
  -o Dpkg::Options::="--force-confdef" \
  -o Dpkg::Options::="--force-confnew" \
  upgrade

# install prerequisites
try_cmd 3 apt-get -y install \
  apt-transport-https \
  ca-certificates \
  curl \
  gnupg-agent \
  jq \
  software-properties-common \
  python3-virtualenv \
  python3-venv \
  python3-pip \
  git

# start the firewall
try_cmd 1 ufw enable
try_cmd 1 ufw allow ssh

# virtualenv
mkdir -p "$virtualenv_path"
cd "$virtualenv_base"
try_cmd 1 virtualenv --python=/usr/bin/python3 "$virtualenv_path"
# shellcheck disable=SC1090
source "$virtualenv_activate_script"

install-watchmaker

install-docker

# Launch docker and build watchmaker
export DOCKER_SLUG="$docker_slug"

# shellcheck disable=SC1083,SC2288
%{ if standalone_builder == "pyapp" }
write-tfi "Using PyApp build..."
try_cmd 1 chmod +x ci/prep_docker_pyapp.sh && ci/prep_docker_pyapp.sh
STAGING_DIR=.pyapp/dist
# shellcheck disable=SC1083,SC2288
%{ else }
write-tfi "Using PyInstaller build..."
try_cmd 1 chmod +x ci/prep_docker.sh && ci/prep_docker.sh
STAGING_DIR=.pyinstaller/dist
# shellcheck disable=SC1083,SC2288
%{ endif }

# ----------  begin of wam deploy  -------------------------------------------

rm -rf "$STAGING_DIR/latest"
mv "$STAGING_DIR/"* "$STAGING_DIR/latest"
mv "$STAGING_DIR/latest/"watchmaker-*-standalone-linux-x86_64 "$STAGING_DIR/latest/watchmaker-latest-standalone-linux-x86_64"

artifact_dest="s3://$build_slug/$release_prefix/"
try_cmd 1 aws s3 cp "$STAGING_DIR" "$artifact_dest" --recursive

# ----------  end of wam deploy  ---------------------------------------------

# shellcheck disable=SC1083,SC2288
%{ else }

# setup error trap to go to catch function

check-metadata-availability

set -eu -o pipefail
trap 'catch $? $LINENO' EXIT

try_cmd 5 dnf -y install jq

if [[ "$build_type" == "$build_type_standalone" ]]; then
  standalone_dest=/home/maintuser

  if [[ "$standalone_source" == "github_actions_artifact" ]]; then
    executable_path=$(install-standalone-from-github-artifact) || catch 1 "$LINENO"
    cp "$executable_path" "$standalone_dest/watchmaker"
  else
    standalone_location="s3://$build_slug/$executable"
    error_location="s3://$build_slug/$standalone_error_signal_file"
    sleep_time=20
    max_wait_seconds=600
    wait_start=$(date +%s)
    nonexistent_code="nonexistent"
    no_error_code="no_error"

    write-tfi "Looking for standalone executable at $standalone_location"
    write-tfi "Looking for error signal at $error_location"
    write-tfi "Waiting up to $max_wait_seconds second(s) for standalone artifact readiness"

    #block until executable exists, an error, or timeout
    while true; do

      now=$(date +%s)
      elapsed=$((now - wait_start))
      if [[ $elapsed -ge $max_wait_seconds ]]; then
        fail_snippet="Timed out waiting for standalone executable after $max_wait_seconds second(s): $standalone_location"
        write-tfi "$fail_snippet"
        catch 1 "$LINENO"
      fi

      # aws s3 ls $standalone_location ==> exit 1, if it doesn't exist!

      # find out what's happening with the builder
      exists=$(aws s3 ls "$standalone_location" || echo "$nonexistent_code")
      error=$(aws s3 ls "$error_location" || echo "$no_error_code")

      if [[ "$error" != "$no_error_code" ]]; then
        # error signaled by the builder
        write-tfi "Error signaled by the builder"
        write-tfi "Error file found at $error_location"
        catch 1 "$LINENO"
      else
        # no builder errors signaled
        if [[ "$exists" == "$nonexistent_code" ]]; then
          # standalone does not exist
          write-tfi "The standalone executable was not found. Trying again in $sleep_time s..."
          sleep "$sleep_time"
        else
          # it exists!
          write-tfi "The standalone executable was found!"
          break
        fi
      fi

    done

    try_cmd 5 aws s3 cp "$standalone_location" "$standalone_dest/watchmaker"
  fi

  chmod +x "$standalone_dest/watchmaker"

  try_cmd 1 "$standalone_dest"/watchmaker "$${args[@]}"

else
  # Install from source

  # Prefer newer python3 version if available
  # shellcheck disable=SC2034
  python_versions=("3.14" "3.13" "3.12" "3.11" "3.10" "3.9" "3.8")
  found_python=false

  # shellcheck disable=SC2034,SC2066
  for version in "$${python_versions[@]}"; do
      if alternatives --display python3 | grep "python$${version}" > /dev/null 2>&1; then
          echo "Setting python3 to python$${version}"
          alternatives --set python3 "$(command -v "python$${version}")"
          found_python=true
          break
      fi
  done

  if [[ "$found_python" == false ]]; then
      echo "No appropriate alternative python3 found, using default python3 version"
  fi

  python3 --version

  if [[ "$source_source" == "github_actions_artifact" ]]; then
    install-watchmaker-from-github-artifact
  else
    try_cmd 5 dnf -y install git
    install-watchmaker
  fi

  # Run watchmaker
  try_cmd 1 watchmaker "$${args[@]}"

  # ----------  end of wam install  ----------
fi
# shellcheck disable=SC1083,SC2288
%{ endif }

finally
