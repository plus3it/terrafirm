signal_error() {
  error_signal_file="error.log"
  echo "For more information on the error, see the lx_builder/userdata.log file." > $error_signal_file
  echo "$0: line $2: exiting with status $${exit_code}" >> $error_signal_file

  artifact_dest="s3://${tfi_s3_bucket}/${tfi_build_date}/${tfi_build_hour}_${tfi_build_id}/release/"
  write-tfi "Signaling error at $${artifact_dest}"
  aws s3 cp $error_signal_file "$${artifact_dest}" --region "${tfi_aws_region}"
  write-tfi "Upload error signal" $?

  catch $@
}

# setup error trap to go to signal_error function
trap 'signal_error $? $${LINENO}' ERR

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
write-tfi "Fix host resolution" $?

# start the firewall
ufw enable
ufw allow ssh
write-tfi "Allow ssh" $?

apt-get -y update
apt-get -y upgrade
write-tfi "apt-get upgrade" $?

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
write-tfi "Install packages" $?

# virtualenv
basedir=/opt/wam
mkdir -p $basedir/venv
cd $basedir
virtualenv --python=/usr/bin/python3 venv
write-tfi "Create virtualenv" $?
source venv/bin/activate

install-watchmaker

# Launch docker and build watchmaker
export DOCKER_SLUG="${tfi_docker_slug}"
chmod +x ci/prep_docker.sh && ci/prep_docker.sh
write-tfi "Build standalone within docker" $?

# ----------  begin of wam deploy  -------------------------------------------

source .gravitybee/gravitybee-environs.sh

if [ -n "$GB_ENV_STAGING_DIR" ] ; then

  # only using "latest" so versioned copy is just wasted space
  rm -rf $GB_ENV_STAGING_DIR/0*
  write-tfi "Remove versioned standalone (keeping 'latest')" $?

  artifact_dest="s3://${tfi_s3_bucket}/${tfi_build_date}/${tfi_build_hour}_${tfi_build_id}/release/"
  aws s3 cp $GB_ENV_STAGING_DIR "$${artifact_dest}" --recursive --region "${tfi_aws_region}"
  write-tfi "Copy standalones to $${artifact_dest}" $?

fi

# ----------  end of wam deploy  ---------------------------------------------

finally
