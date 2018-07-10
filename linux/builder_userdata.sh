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
  # THIS IS THE BUILDER SCRIPT - WHICH LOOKS LIKE OTHERS BUT EXECUTES ON
  # UBUNTU ###################################################################

  local exit_code="$${1:-0}"

  echo "Finally: "

  # everything to happen whether install succeeds or fails

  # write the status to a file for reading by test script
  printf "%s\n" "$${userdata_status[@]}" > /tmp/userdata_status

  # move logs to s3
  artifact_dest="s3://${tfi_s3_bucket}/${tfi_build_date}/${tfi_build_hour}_${tfi_build_id}/${tfi_ami_key}/"
  echo "Writing logs to $${artifact_dest}"
  aws s3 cp "${tfi_lx_userdata_log}" "$${artifact_dest}" --region "${tfi_aws_region}"

  # open firewall/put ssh on a new port
  ufw allow 122/tcp
  sed -i 's/Port 22/Port 122/g' /etc/ssh/sshd_config
  service ssh restart

  exit "$${exit_code}"
}

catch() {
  local this_script="$0"
  local exit_code="$${1:-1}"
  local err_lineno="$2"
  echo "$0: line $2: exiting with status $${exit_code}"

  error_signal_file="error.log"
  echo "For more information on the error, see the lx_builder/userdata.log file." > $error_signal_file
  echo "$0: line $2: exiting with status $${exit_code}" >> $error_signal_file

  artifact_dest="s3://${tfi_s3_bucket}/${tfi_build_date}/${tfi_build_hour}_${tfi_build_id}/release/"
  echo "Signaling error at $${artifact_dest}"
  aws s3 cp $error_signal_file "$${artifact_dest}" --region "${tfi_aws_region}"

  userdata_status=($exit_code "Userdata install error at stage $stage")

  finally $@
}

# setup error trap to go to catch function
trap 'catch $? $${LINENO}' ERR

# to resolve the issue with "sudo: unable to resolve host"
# https://forums.aws.amazon.com/message.jspa?messageID=495274
host_ip=$(hostname)
if [[ $host_ip =~ ^[a-z]*-[0-9]{1,3}-[0-9]{1,3}-[0-9]{1,3}-[0-9]{1,3}$ ]]; then
  # hostname is ip
  ip=$${host_ip#*-}
  ip=$${ip//-/.}
  echo "$ip $host_ip" >> /etc/hosts
else
  echo "127.0.1.1 $host_ip" >> /etc/hosts
fi

# start the firewall
ufw enable
ufw allow ssh

apt-get -y update
apt-get -y upgrade

# install prerequisites
apt-get -y install \
  awscli \
  python-virtualenv \
  apt-transport-https \
  ca-certificates \
  curl \
  software-properties-common \
  python3 \
  git

basedir=/opt/wam
mkdir -p $basedir/venv
cd $basedir
virtualenv --python=/usr/bin/python3 venv
source venv/bin/activate

# everything below this is the TRY

# start time of install
start=`date +%s`

# declare an array to hold the status (number and message)
userdata_status=(0 "Success")

# regular install
# ----------  begin of wam build  --------------------------------------------
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

stage="s3 upload"

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
stage="install_wam" && pip install --index-url "$PYPI_URL" --editable .

echo $PWD
ls -hal

# Launch docker and build watchmaker
export DOCKER_SLUG="${tfi_docker_slug}"
chmod +x ci/prep_docker.sh && ci/prep_docker.sh

# ----------  begin of wam deploy  -------------------------------------------

source .gravitybee/gravitybee-environs.sh

if [ -n "$GB_ENV_STAGING_DIR" ] ; then

  # only using "latest" so versioned copy is just wasted space
  rm -rf $GB_ENV_STAGING_DIR/0*

  artifact_dest="s3://${tfi_s3_bucket}/${tfi_build_date}/${tfi_build_hour}_${tfi_build_id}/release/"
  echo "Copying standalones to $${artifact_dest}"
  aws s3 cp $GB_ENV_STAGING_DIR "$${artifact_dest}" --recursive --region "${tfi_aws_region}"

fi

# ----------  end of wam deploy  ---------------------------------------------

# time it took to install
end=`date +%s`
runtime=$((end-start))
echo "WAM install took $runtime seconds."

finally
