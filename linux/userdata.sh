#!/bin/sh

exec &> ${tfi_lx_userdata_log}

yum -y install bc

#sleep 20
start=`date +%s`

WATCHMAKER_INSTALL_GOES_HERE

end=`date +%s`
runtime=$((end-start))
echo "WAM install took $runtime seconds."

#copy files to S3 using AWS CLI
pip install awscli --upgrade
export AWS_ACCESS_KEY_ID="${tfi_cli_access_key_id}"
export AWS_SECRET_ACCESS_KEY="${tfi_cli_secret_access_key}"
export AWS_DEFAULT_REGION="${tfi_region}"

RAND=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 4 | head -n 1) ; export RAND
VERSION=$(cat /etc/redhat-release | cut -c1-3)$(cat /etc/redhat-release | sed 's/[^0-9.]*\([0-9.]*\).*/\1/') ; export VERSION
DIRNAME=$(date +'%Y%m%d_%H%M%S_')$VERSION"_"$RAND ; export DIRNAME

aws s3 cp ${tfi_lx_userdata_log} s3://terrafirm/$DIRNAME/userdata_install.log
aws s3 cp /var/log/cloud-init-output.log s3://terrafirm/$DIRNAME/cloud-init-output.log
aws s3 cp /var/log/watchmaker s3://terrafirm/$DIRNAME/watchmaker/ --recursive

touch /tmp/SETUP_COMPLETE_SIGNAL
