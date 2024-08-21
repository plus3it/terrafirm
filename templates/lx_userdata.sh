#!/bin/bash
# shellcheck disable=SC2269

build_os="${build_os}"
build_type="${build_type}"
build_label="${build_label}"
build_type_source="${build_type_source}"
build_type_standalone="${build_type_standalone}"

# shellcheck disable=SC2154
exec &> "${userdata_log}"

build_slug="${build_slug}"
standalone_error_signal_file="${standalone_error_signal_file}"
temp_dir="${temp_dir}"
# shellcheck disable=SC2154
export AWS_DEFAULT_REGION="${aws_region}"
# shellcheck disable=SC2154
debug_mode="${debug}"

echo "------------------------------- $build_label ---------------------"

debug-2s3() {
  ## With as few dependencies as possible, immediately upload the debug and log
  ## files to S3. Calling this multiple times will simply overwrite the
  ## previously uploaded logs.
  local msg="$1"

  debug_file="$temp_dir/debug.log"
  echo "$msg" >> "$debug_file"
  aws s3 cp "$debug_file" "s3://$build_slug/$build_label/" > /dev/null 2>&1 || true
  aws s3 cp "${userdata_log}" "s3://$build_slug/$build_label/" > /dev/null 2>&1 || true
}

check-metadata-availability() {
  local metadata_loopback_az="http://169.254.169.254/latest/meta-data/placement/availability-zone"
  try_cmd 50 curl -sSL $metadata_loopback_az
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

  if [ "$result" = "" ]; then
    out_result=""
  elif [ "$result" = "0" ]; then
    out_result=": Succeeded"
  else
    out_result=": Failed"
  fi

  echo "$(date +%F_%T): $msg $out_result"

  if [ "$debug_mode" != "false" ] ; then
    debug-2s3 "$(date +%F_%T): $msg $out_result"
  fi
}

try_cmd() {
  local n=0
  local try=$1
  local result=1
  local command_output="None"
  [[ $# -le 1 ]] && {
    echo "Usage $0 <number_of_attempts> <Command>"
    exit $result
  }

  shift 1

  if [ "$try" -gt 1 ]; then
    write-tfi "Will try $try time(s) :: $*"
  fi

  if [[ "$SHELLOPTS" == *":errexit:"* ]]; then
    set +e
    local ERREXIT=1
  fi

  until [[ $n -ge $try ]]; do
    sleep $n
    command_output=$("$@" 2>&1)
    result=$?
    write-tfi "$* :: code $result :: output: $command_output" --result $result
    if [[ $result -eq 0 ]]; then
      break
    else
      ((n++))
      write-tfi "Attempt $n, command failed :: $*"
      fail_snippet="Command ($*) failed :: code $result :: output: $command_output"
    fi
  done

  if [[ "$ERREXIT" == "1" ]]; then
    set -e
  fi

  return $result
}  # ----------  end of function try_cmd  ----------

open-ssh() {
  # open firewall on rhel 7/8 and ubuntu, move ssh to non-standard

  # shellcheck disable=SC2154
  local new_lx_port="${port}"

  if [ -f /etc/redhat-release ]; then
    ## CentOS / RedHat / Oracle Linux

    # allow ssh to be on non-standard port (SEL-enforced rule)
    try_cmd 1 setenforce 0

    try_cmd 1 firewall-cmd --add-port="$new_lx_port"/tcp

    try_cmd 1 sed -i -e "5iPort $new_lx_port" /etc/ssh/sshd_config
    try_cmd 1 sed -i -e 's/Port 22/#Port 22/g' /etc/ssh/sshd_config
    try_cmd 1 systemctl restart sshd

    # remount /home so remote-exec works
    try_cmd 1 mount -o remount,exec /home

  else
    ## Not CentOS / RedHat (i.e., Ubuntu)

    # open firewall/put ssh on a new port
    try_cmd 1 ufw allow "$new_lx_port"/tcp
    try_cmd 1 sed -i "s/^[#]*Port .*/Port $new_lx_port/g" /etc/ssh/sshd_config
    try_cmd 1 service ssh restart
  fi
}

publish-artifacts() {
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
  cp "${userdata_log}" "$artifact_dir"
  aws s3 cp "$artifact_dir" "$artifact_dest" --recursive
  write-tfi "Uploaded logs to $artifact_dest" --result $?

  # creates compressed archive to upload to s3
  zip_file="$artifact_base/$${build_slug//\//-}-$build_label.tgz"
  cd "$artifact_dir"
  tar -cvzf "$zip_file" .
  aws s3 cp "$zip_file" "s3://$build_slug/"
  write-tfi "Uploaded artifact zip to S3" --result $?
}

publish-scap-scan() {
  # create a directory with scap scan output
  scan_dir="$temp_dir/terrafirm/scan"
  mkdir -p "$scan_dir"
  cp -R /root/scap/output/* "$scan_dir" || true

  # move scan output to s3
  # shellcheck disable=SC2154
  scan_dest="${scan_slug}/$build_os"
  aws s3 cp "$scan_dir" "$scan_dest" --recursive
  write-tfi "Uploaded scap scan to $scan_dest" --result $?
}

finally() {
  # time it took to install
  end=$(date +%s)
  runtime=$((end-start))
  write-tfi "WAM install took $runtime seconds."

  # shellcheck disable=SC2154
  printf "%s\n" "$${userdata_status[@]}" > "${userdata_status_file}"

  # disable fapolicyd so it can't block aws-cli
  if systemctl is-active --quiet fapolicyd; then
    systemctl stop fapolicyd
  fi

  open-ssh
  publish-artifacts
  # shellcheck disable=SC2154
  if [ "$build_type" == "$build_type_source" ] && [ "${scan_slug}" != "" ]; then
    publish-scap-scan
  fi

  # shellcheck disable=SC2242
  exit "$${userdata_status[0]}"
}

catch() {
  local exit_code="$${1:-1}"
  write-tfi "$0: line $2: exiting with status $1"
  userdata_status=("$exit_code" "Userdata install error: $fail_snippet")
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

# shellcheck disable=SC2317
clone-watchmaker() {
  rm -rf watchmaker
  git clone "$GIT_REPO" --recursive
}

install-watchmaker() {
  # install watchmaker from source

  # shellcheck disable=SC2154
  GIT_REPO="${git_repo}"
  # shellcheck disable=SC2154
  GIT_REF="${git_ref}"
  # shellcheck disable=SC2154
  PYPI_URL="${url_pypi}"

  # Install pip
  try_cmd 2 python3 -m ensurepip --upgrade --default-pip

  # Upgrade pip and setuptools
  try_cmd 2 python3 -m pip install --index-url="$PYPI_URL" --upgrade pip setuptools
  try_cmd 1 python3 -m pip --version

  # Install boto3
  try_cmd 1 python3 -m pip install --index-url="$PYPI_URL" --upgrade boto3

  # Clone watchmaker
  try_cmd 3 clone-watchmaker

  cd watchmaker
  if [ -n "$GIT_REF" ] ; then
    # decide whether to switch to pull request or a branch
    num_re='^[0-9]+$'
    if [[ "$GIT_REF" =~ $num_re ]] ; then
      try_cmd 1 git fetch origin pull/"$GIT_REF"/head:pr-"$GIT_REF"
      try_cmd 1 git checkout pr-"$GIT_REF"
    else
      try_cmd 1 git checkout "$GIT_REF"
    fi
  fi

  # Update submodule refs
  try_cmd 1 git submodule sync
  try_cmd 1 git submodule update --init --recursive --force

  # Install watchmaker
  try_cmd 1 python3 -m pip install --upgrade --index-url "$PYPI_URL" --editable .
  try_cmd 1 watchmaker --version
}

# everything below this is the TRY

# start time of install
start=$(date +%s)

# declare an array to hold the status (number and message)
# shellcheck disable=SC2034
userdata_status=(0 "Passed")

# shellcheck disable=SC1083,SC2288
%{ if build_type == build_type_builder }

# BUILDER INPUT -------------------------------------------
export DEBIAN_FRONTEND=noninteractive
virtualenv_base=/opt/wam
virtualenv_path="$virtualenv_base/venv"
virtualenv_activate_script="$virtualenv_path/bin/activate"
# ---------------------------------------------------------

# shellcheck disable=SC2317
handle_builder_exit() {
  if [ "$1" != "0" ] ; then
    echo "For more information on the error, see the lx_builder/userdata.log file." > "$temp_dir/error.log"
    echo "$0: line $2: exiting with status $1" >> "$temp_dir/error.log"

    artifact_dest="s3://$build_slug/$standalone_error_signal_file"
    write-tfi "Signaling error at $artifact_dest"
    aws s3 cp "$temp_dir/error.log" "$artifact_dest" || true
    write-tfi "Upload error signal" --result $?

    catch "$@"

  else
    finally "$@"
  fi
}

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
  software-properties-common \
  python3-virtualenv \
  python3-venv \
  python3-pip \
  git

# setup error trap to go to signal_error function
set -e
trap 'handle_builder_exit $? $LINENO' EXIT

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
# shellcheck disable=SC2154
export DOCKER_SLUG="${docker_slug}"
try_cmd 1 chmod +x ci/prep_docker.sh && ci/prep_docker.sh

# ----------  begin of wam deploy  -------------------------------------------

STAGING_DIR=.pyinstaller/dist

# only using "latest" so versioned copy is just wasted space
rm -rf "$STAGING_DIR"/0*
write-tfi "Remove versioned standalone (keeping 'latest')" --result $?

# shellcheck disable=SC2154
artifact_dest="s3://$build_slug/${release_prefix}/"
try_cmd 1 aws s3 cp "$STAGING_DIR" "$artifact_dest" --recursive

# ----------  end of wam deploy  ---------------------------------------------

# shellcheck disable=SC1083,SC2288
%{ else }

# setup error trap to go to catch function


check-metadata-availability

set -e
trap 'catch $? $LINENO' EXIT

if [ "$build_type" == "$build_type_standalone" ]; then
  # shellcheck disable=SC2154
  standalone_location="s3://$build_slug/${executable}"
  error_location="s3://$build_slug/$standalone_error_signal_file"
  sleep_time=20
  nonexistent_code="nonexistent"
  no_error_code="0"

  write-tfi "Looking for standalone executable at $standalone_location"

  #block until executable exists, an error, or timeout
  while true; do

    # aws s3 ls $standalone_location ==> exit 1, if it doesn't exist!

    # find out what's happening with the builder
    exists=$(aws s3 ls "$standalone_location" || echo "$nonexistent_code")
    error=$(aws s3 ls "$error_location" || echo "$no_error_code")

    if [ "$error" != "0" ]; then
      # error signaled by the builder
      write-tfi "Error signaled by the builder"
      write-tfi "Error file found at $error_location"
      catch 1 "$LINENO"
    else
      # no builder errors signaled
      if [ "$exists" = "$nonexistent_code"  ]; then
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

  standalone_dest=/home/maintuser
  try_cmd 5 aws s3 cp "$standalone_location" "$standalone_dest/watchmaker"
  chmod +x "$standalone_dest/watchmaker"

  # shellcheck disable=SC2154,SC2086
  try_cmd 1 "$standalone_dest"/watchmaker ${args}

else
  # Install from source

  # Install git
  try_cmd 5 yum -y install git

  install-watchmaker

  # Run watchmaker
  # shellcheck disable=SC2086
  try_cmd 1 watchmaker ${args}

  # ----------  end of wam install  ----------
fi
# shellcheck disable=SC1083,SC2288
%{ endif }

finally
