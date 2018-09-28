
exec &> ${tfi_userdata_log}

build_slug="${tfi_build_slug}"
error_signal_file="${tfi_error_signal_file}"
temp_dir="${tfi_temp_dir}"

# strangely necessary on ubuntu
if [ ! -f /etc/redhat-release ]; then
  region_flag="--region ${tfi_aws_region}"
fi

echo "AMI KEY: ------------------------------- $${index_str}$${ami_key} ---------------------"

write-tfi() {
  local msg=$1
  local success=$2

  if [ "$${success}" = "" ]; then
    out_result="" # needed to distinguish between null and false
  elif [ "$${success}" = "0" ]; then
    out_result=": Succeeded"
  else
    out_result=": Failed"
  fi

  echo "$(date +%F_%T): $msg $out_result"
}

debug-2s3() {
  ## With as few dependencies as possible, immediately upload the debug and log
  ## files to S3. Calling this multiple times will simply overwrite the
  ## previously uploaded logs.
  local msg=$1

  debug_file="$temp_dir/debug.log"
  echo "$msg" >> $debug_file
  aws s3 cp $debug_file "s3://$build_slug/$${index_str}$${ami_key}/" $region_flag || true
  aws s3 cp ${tfi_userdata_log} "s3://$build_slug/$${index_str}$${ami_key}/" $region_flag || true
}

retry() {
    local n=0
    local try=$1
    local cmd="$${*: 2}"
    local result=1
    [[ $# -le 1 ]] && {
        echo "Usage $0 <number_of_retry_attempts> <Command>"
        exit $result
    }

    write-tfi "Will try $try time(s) :: $cmd"

    if [[ "$${SHELLOPTS}" == *":errexit:"* ]]; then
        set +e
        local ERREXIT=1
    fi

    until [[ $n -ge $try ]]; do
        sleep $n
        $cmd
        result=$?
        if [[ $result -eq 0 ]]; then
            break
        else
            ((n++))
            write-tfi "Attempt $n, command failed :: $cmd"
        fi
    done

    if [[ "$${ERREXIT}" == "1" ]]; then
        set -e
    fi

    return $result
}  # ----------  end of function retry  ----------

open-ssh() {
  # open firewall on rhel 6/7 and ubuntu, move ssh to non-standard

  local new_ssh_port=${tfi_ssh_port}

  if [ -f /etc/redhat-release ]; then
    ## CentOS / RedHat

    # allow ssh to be on non-standard port (SEL-enforced rule)
    setenforce 0

    # open firewall (iptables for rhel/centos 6, firewalld for 7
    systemctl status firewalld &> /dev/null
    if [ $? -eq 0 ] ; then
      firewall-cmd --zone=public --permanent --add-port=$new_ssh_port/tcp
      firewall-cmd --reload
      write-tfi "Configure firewalld" $?
    else
      iptables -A INPUT -p tcp --dport $new_ssh_port -j ACCEPT #open port $new_ssh_port
      service iptables save
      service iptables restart
      write-tfi "Configure iptables" $?
    fi

    sed -i -e "5iPort $new_ssh_port" /etc/ssh/sshd_config
    sed -i -e 's/Port 22/#Port 22/g' /etc/ssh/sshd_config
    service sshd restart
    write-tfi "Configure sshd" $?

  else
    ## Not CentOS / RedHat (i.e., Ubuntu)

    # open firewall/put ssh on a new port
    ufw allow $new_ssh_port/tcp
    write-tfi "Configure ufw" $?
    sed -i "s/Port 22/Port $new_ssh_port/g" /etc/ssh/sshd_config
    service ssh restart
    write-tfi "Configure ssh" $?
  fi
}

publish-artifacts() {
  # stage, zip, upload artifacts to s3

  # create a directory with all the build artifacts
  artifact_base="$temp_dir/terrafirm"
  artifact_dir="$${artifact_base}/build-artifacts"
  mkdir -p "$${artifact_dir}/scap_output"
  mkdir -p "$${artifact_dir}/cloud/scripts"
  cp -R /var/log/watchmaker/ "$${artifact_dir}" || true
  cp -R /root/scap/output/* "$${artifact_dir}/scap_output/" || true
  cp -R /var/log/cloud*log "$${artifact_dir}/cloud/" || true
  cp -R /var/lib/cloud/instance/scripts/* "$${artifact_dir}/cloud/scripts/" || true

  # move logs to s3
  artifact_dest="s3://$build_slug/$${index_str}$${ami_key}"
  cp "${tfi_userdata_log}" "$${artifact_dir}"
  aws s3 cp "$${artifact_dir}" "$${artifact_dest}" --recursive $region_flag || true
  write-tfi "Uploaded logs to $${artifact_dest}" $?

  # creates compressed archive to upload to s3
  zip_file="$${artifact_base}/$${build_slug//\//-}-$${index_str}$${ami_key}.tgz"
  cd "$${artifact_dir}"
  tar -cvzf "$${zip_file}" .
  aws s3 cp "$${zip_file}" "s3://$build_slug/" $region_flag || true
  write-tfi "Uploaded artifact zip to S3" $?
}

finally() {
  # everything to happen whether install succeeds or fails

  local exit_code="$${1:-0}"

  # time it took to install
  end=`date +%s`
  runtime=$((end-start))
  write-tfi "WAM install took $runtime seconds."

  write-tfi "Finally: "

  # write the status to a file for reading by test script
  printf "%s\n" "$${userdata_status[@]}" > ${tfi_userdata_status_file}

  open-ssh

  publish-artifacts

  exit "$${exit_code}"
}

catch() {
  # what to do in case of an error

  local this_script="$0"
  local exit_code="$${1:-1}"
  local err_lineno="$2"
  write-tfi "$0: line $2: exiting with status $${exit_code}"

  userdata_status=($exit_code "Userdata install error at stage $stage")

  finally $@
}

install-watchmaker() {
  # install watchmaker from source

  GIT_REPO="${tfi_git_repo}"
  GIT_REF="${tfi_git_ref}"

  PIP_URL=${tfi_pip_bootstrap_url}
  PYPI_URL=${tfi_pypi_url}

  # Install pip
  stage="Install Python/Git" \
    && curl "$PIP_URL" | python - --index-url="$PYPI_URL" 'wheel<0.30.0;python_version<"2.7"' 'wheel;python_version>="2.7"'
  write-tfi "$stage" $?

  # Upgrade pip and setuptools
  stage="Upgrade pip/setuptools" \
    && pip install --index-url="$PYPI_URL" --upgrade 'pip<10' 'setuptools<37;python_version<"2.7"' 'setuptools;python_version>="2.7"'
  write-tfi "$stage" $?

  # Install boto3
  stage="Install boto3" \
    && pip install --index-url="$PYPI_URL" --upgrade boto3
  write-tfi "$stage" $?

  # Clone watchmaker
  stage="Clone repository" && git clone "$GIT_REPO" --recursive
  write-tfi "$stage" $?
  cd watchmaker
  if [ -n "$GIT_REF" ] ; then
    # decide whether to switch to pull request or a branch
    num_re='^[0-9]+$'
    if [[ "$GIT_REF" =~ $num_re ]] ; then
      stage="git pr (Repo: $GIT_REPO, PR: $GIT_REF)"
      git fetch origin pull/$GIT_REF/head:pr-$GIT_REF
      git checkout pr-$GIT_REF
    else
      stage="git ref (Repo: $GIT_REPO, Ref: $GIT_REF)"
      git checkout $GIT_REF
    fi
  fi

  # Update submodule refs
  stage="Update submodules" && git submodule update
  write-tfi "$stage" $?

  # Install watchmaker
  stage="Install Watchmaker" && pip install --upgrade --index-url "$PYPI_URL" --editable .
  write-tfi "$stage" $?
}

# everything below this is the TRY

# start time of install
start=`date +%s`

# declare an array to hold the status (number and message)
userdata_status=(0 "Success")
