handle_builder_exit() {
  if [ "$1" != "0" ] ; then
    echo "For more information on the error, see the lx_builder/userdata.log file." > "$temp_dir/error.log"
    echo "$0: line $2: exiting with status $1" >> "$temp_dir/error.log"

    artifact_dest="s3://$build_slug/$error_signal_file"
    write-tfi "Signaling error at $artifact_dest"
    aws s3 cp "$temp_dir/error.log" "$artifact_dest" || true
    write-tfi "Upload error signal" $?

    catch "$@"

  else
    finally "$@"
  fi
}

export DEBIAN_FRONTEND=noninteractive

apt-get -y update && apt-get -y install awscli
write-tfi "apt-get update, install awscli" $?

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

echo "ARRAY <ignore> devices=/dev/sda" >> /etc/mdadm/mdadm.conf
write-tfi "Fix no arrays warning" $?

UCF_FORCE_CONFFNEW=1 \
  apt-get -y \
  -o Dpkg::Options::="--force-confdef" \
  -o Dpkg::Options::="--force-confnew" \
  upgrade
write-tfi "apt-get upgrade" $?

# install prerequisites
apt-get -y install \
  python-virtualenv \
  apt-transport-https \
  ca-certificates \
  curl \
  software-properties-common \
  python3 \
  python3-venv \
  python3-pip \
  git
write-tfi "Install packages" $?

# setup error trap to go to signal_error function
set -e

trap 'handle_builder_exit $? $LINENO' EXIT

# start the firewall
ufw enable
ufw allow ssh
write-tfi "Allow ssh" $?

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
  rm -rf "$GB_ENV_STAGING_DIR"/0*
  write-tfi "Remove versioned standalone (keeping 'latest')" $?

  artifact_dest="s3://$build_slug/${tfi_release_prefix}/"
  aws s3 cp "$GB_ENV_STAGING_DIR" "$artifact_dest" --recursive
  write-tfi "Copy standalones to $artifact_dest" $?

fi

# ----------  end of wam deploy  ---------------------------------------------

finally
