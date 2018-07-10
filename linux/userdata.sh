#!/bin/bash

exec &> ${tfi_lx_userdata_log}

retry()
{
    local n=0
    local try=$1
    local cmd="$${*: 2}"
    local result=1
    [[ $# -le 1 ]] && {
        echo "Usage $0 <number_of_retry_attempts> <Command>"
        exit $result
    }

    echo "Will try $try time(s) :: $cmd"

    if [[ "$${SHELLOPTS}" == *":errexit:"* ]]
    then
        set +e
        local ERREXIT=1
    fi

    until [[ $n -ge $try ]]
    do
        sleep $n
        $cmd
        result=$?
        if [[ $result -eq 0 ]]
        then
            break
        else
            ((n++))
            echo "Attempt $n, command failed :: $cmd"
        fi
    done

    if [[ "$${ERREXIT}" == "1" ]]
    then
        set -e
    fi

    return $result
}  # ----------  end of function retry  ----------

finally() {
  local exit_code="$${1:-0}"

  echo "Finally: "

  # everything to happen whether install succeeds or fails

  # write the status to a file for reading by test script
  printf "%s\n" "$${userdata_status[@]}" > /tmp/userdata_status

  # allow ssh to be on non-standard port (SEL-enforced rule)
  setenforce 0

  # open firewall (iptables for rhel/centos 6, firewalld for 7
  systemctl status firewalld &> /dev/null
  if [ $? -eq 0 ] ; then
    echo "Configuring firewalld..."
    firewall-cmd --zone=public --permanent --add-port=122/tcp
    firewall-cmd --reload
  else
    echo "Configuring iptables..."
    iptables -A INPUT -p tcp --dport 122 -j ACCEPT #open port 122
    service iptables save
    service iptables restart
  fi

  sed -i -e '5iPort 122' /etc/ssh/sshd_config
  sed -i -e 's/Port 22/#Port 22/g' /etc/ssh/sshd_config
  service sshd restart

  # create a directory with all the build artifacts
  artifact_base="/tmp/terrafirm"
  artifact_dir="$${artifact_base}/build-artifacts"
  mkdir -p "$${artifact_dir}/scap_output"
  mkdir -p "$${artifact_dir}/cloud/scripts"
  cp -R /var/log/watchmaker/ "$${artifact_dir}"
  cp -R /root/scap/output/* "$${artifact_dir}/scap_output/"
  cp -R /var/log/cloud*log "$${artifact_dir}/cloud/"
  cp -R /var/lib/cloud/instance/scripts/* "$${artifact_dir}/cloud/scripts/"

  # move logs to s3
  artifact_dest="s3://${tfi_s3_bucket}/${tfi_build_date}/${tfi_build_hour}_${tfi_build_id}/${tfi_ami_key}"
  echo "Writing logs to $${artifact_dest}"
  cp "${tfi_lx_userdata_log}" "$${artifact_dir}"
  aws s3 cp "$${artifact_dir}" "$${artifact_dest}" --recursive || true

  # creates compressed archive to upload to s3
  zip_file="$${artifact_base}/${tfi_build_date}-${tfi_build_id}-${tfi_ami_key}.tgz"
  cd "$${artifact_dir}"
  tar -cvzf "$${zip_file}" .
  aws s3 cp "$${zip_file}" "s3://${tfi_s3_bucket}/${tfi_build_date}/${tfi_build_hour}_${tfi_build_id}/" || true

  exit "$${exit_code}"
}

catch() {
  local this_script="$0"
  local exit_code="$${1:-1}"
  local err_lineno="$2"
  echo "$0: line $2: exiting with status $${exit_code}"

  userdata_status=($exit_code "Userdata install error at stage $stage")

  finally $@
}

# setup error trap to go to catch function
trap 'catch $? $${LINENO}' ERR

ami_key=${tfi_ami_key}
echo "AMI KEY: ------------------------------- $ami_key ---------------------"

# everything below this is the TRY

# start time of install
start=`date +%s`

# declare an array to hold the status (number and message)
userdata_status=(0 "Success")

if [[ "$ami_key" == *pkg ]]; then
  # if it ends with 'pkg', test standalone

  standalone_location="s3://${tfi_s3_bucket}/${tfi_build_date}/${tfi_build_hour}_${tfi_build_id}/release/latest/watchmaker-latest-standalone-linux-x86_64"
  error_location="s3://${tfi_s3_bucket}/${tfi_build_date}/${tfi_build_hour}_${tfi_build_id}/release/error.log"
  sleep_time=20
  nonexistent_code="nonexistent"
  no_error_code="0"

  echo "Looking for standalone executable at $standalone_location"

  #block until executable exists, an error, or timeout
  while true; do

    # aws s3 ls $standalone_location ==> exit 1, if it doesn't exist!

    # find out what's happening with the builder
    exists=$(aws s3 ls $standalone_location || echo "$nonexistent_code")
    error=$(aws s3 ls $error_location || echo "$no_error_code")

    if [ "$error" != "0" ]; then
      # error signaled by the builder
      echo "Error signaled by the builder"
      echo "Error file found at $error_location"
      catch 1 $${LINENO}
      break
    else 
      # no builder errors signaled
      if [ "$exists" = "$nonexistent_code"  ]; then
        # standalone does not exist
        echo "The standalone executable was not found. Trying again in $${sleep_time}s..."
        sleep $sleep_time
      else
        # it exists!
        echo "The standalone executable was found!"
        break
      fi
    fi

  done

  standalone_dest=/home/maintuser
  aws s3 cp $standalone_location $standalone_dest/watchmaker
  chmod +x $standalone_dest/watchmaker

  export LC_ALL=en_US.UTF-8
  export LANG=en_US.UTF-8
  stage="run wam" && $standalone_dest/watchmaker ${tfi_common_args} ${tfi_lx_args}

else

  # regular install
  # ----------  begin of wam install  ----------
  GIT_REPO="${tfi_git_repo}"
  GIT_REF="${tfi_git_ref}"

  PIP_URL=https://bootstrap.pypa.io/2.6/get-pip.py
  PYPI_URL=https://pypi.org/simple

  # Install pip
  stage="install python/git" \
    && curl "$PIP_URL" | python - --index-url="$PYPI_URL" 'wheel<0.30.0;python_version<"2.7"' 'wheel;python_version>="2.7"'

  # Upgrade pip and setuptools
  stage="upgrade pip/setuptools" \
    && pip install --index-url="$PYPI_URL" --upgrade 'pip<10' 'setuptools<37;python_version<"2.7"' 'setuptools;python_version>="2.7"'

  # Install boto3
  stage="install boto3" \
    && pip install --index-url="$PYPI_URL" --upgrade boto3

  # Install git
  retry 5 yum -y install git

  # Clone watchmaker
  stage="git" && git clone "$GIT_REPO" --recursive
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
  stage="update submodules" && git submodule update

  # Install watchmaker
  stage="install wam" && pip install --index-url "$PYPI_URL" --editable .

  # Run watchmaker
  stage="run wam" && watchmaker ${tfi_common_args} ${tfi_lx_args}
  # ----------  end of wam install  ----------
fi

# time it took to install
end=`date +%s`
runtime=$((end-start))
echo "WAM install took $runtime seconds."

finally
