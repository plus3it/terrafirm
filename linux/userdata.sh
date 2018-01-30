#!/bin/bash

exec &> ${tfi_lx_userdata_log}

yum -y install bc

#sleep 20
start=`date +%s`

WATCHMAKER_INSTALL_GOES_HERE

end=`date +%s`
runtime=$((end-start))
echo "WAM install took $runtime seconds."

export S3_TOP_FOLDER=$(date +'%Y%m%d')
export RAND=$(date +%N | cut -b 1-4) #using nanoseconds, don't use /dev/urandom here because there's not enough entropy yet! will block on RHEL
export OS_VERSION=$(cat /etc/redhat-release | cut -c1-3)$(cat /etc/redhat-release | sed 's/[^0-9.]*\([0-9]\.[0-9]\).*/\1/')
export S3_FOLDER=$(date +'%Y%m%d_%H%M%S_')$OS_VERSION"_"$RAND

aws s3 cp ${tfi_lx_userdata_log} "s3://terrafirm/$${S3_TOP_FOLDER}/$${S3_FOLDER}/userdata.log"
aws s3 cp /var/log "s3://terrafirm/$${S3_TOP_FOLDER}/$${S3_FOLDER}/cloud-init/" --recursive --exclude "*" --include "cloud*log"
aws s3 cp /var/log/watchmaker "s3://terrafirm/$${S3_TOP_FOLDER}/$${S3_FOLDER}/watchmaker/" --recursive

touch /tmp/SETUP_COMPLETE_SIGNAL
