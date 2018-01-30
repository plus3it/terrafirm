#!/bin/bash

exec &> ${tfi_lx_userdata_log}

yum -y install bc

#sleep 20
start=`date +%s`

WATCHMAKER_INSTALL_GOES_HERE

end=`date +%s`
runtime=$((end-start))
echo "WAM install took $runtime seconds."

#echo "AKI: ${tfi_cli_access_key_id}"
#echo "SAK: ${tfi_cli_secret_access_key}"
#echo "REG: ${tfi_region}"

#sudo -i

#copy files to S3 using AWS CLI
#pip install --upgrade pip
#pip install awscli --upgrade
#export AWS_ACCESS_KEY_ID="${tfi_cli_access_key_id}"
#export AWS_SECRET_ACCESS_KEY="${tfi_cli_secret_access_key}"
#export AWS_DEFAULT_REGION="${tfi_region}"

export S3_TOP_FOLDER=$(date +'%Y%m%d')
export RAND=$(date +%N | cut-c1-c4) #don't use /dev/urandom here because there's not enough entropy yet! will block on RHEL
export OS_VERSION=$(cat /etc/redhat-release | cut -c1-3)$(cat /etc/redhat-release | sed 's/[^0-9.]*\([0-9.]*\).*/\1/')
export S3_FOLDER=$(date +'%Y%m%d_%H%M%S_')$OS_VERSION"_"$RAND

aws s3 cp /tmp/userdata.log "s3://terrafirm/$${S3_TOP_FOLDER}/$${S3_FOLDER}/userdata.log"
FILES=/var/log/cloud*
for f in $FILES
do
  # wildcard with awscli works fine on 7.4 but not on 6.9 for whatever reason so for-looping it
  aws s3 cp $f "s3://terrafirm/$${S3_TOP_FOLDER}/$${S3_FOLDER}/cloud-init/"
done
aws s3 cp /var/log/watchmaker "s3://terrafirm/$${S3_TOP_FOLDER}/$${S3_FOLDER}/watchmaker/" --recursive

touch /tmp/SETUP_COMPLETE_SIGNAL
