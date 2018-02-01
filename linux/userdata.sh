#!/bin/bash

exec &> ${tfi_lx_userdata_log}

start=`date +%s`

WATCHMAKER_INSTALL_GOES_HERE

end=`date +%s`
runtime=$((end-start))
echo "WAM install took $runtime seconds."

setenforce 0

# open firewall (iptables for rhel/centos 6, firewalld for 7
if rpm -q iptables ; then # does system have iptables?
  echo "Configuring iptables..."
  iptables -A INPUT -p tcp --dport 122 -j ACCEPT #open port 122
  iptables save
  iptables restart
else
  echo "Configuring firewalld..."
  firewall-cmd --zone=public --permanent --add-port=122/tcp
  firewall-cmd --reload
fi
sed -i -e '5iPort 122' /etc/ssh/sshd_config
service sshd restart

export S3_TOP_KEYFIX=$(echo ${tfi_build_id} | cut -d'_' -f 1)
export BUILD_ID=$(echo ${tfi_build_id} | cut -d'_' -f 2)"_"$(echo ${tfi_build_id} | cut -d'_' -f 3)
export OS_VERSION=$(cat /etc/redhat-release | cut -c1-3)$(cat /etc/redhat-release | sed 's/[^0-9.]*\([0-9]\.[0-9]\).*/\1/')
#export S3_KEYFIX=$(date +'%H%M%S_')$OS_VERSION
export S3_KEYFIX=$OS_VERSION

aws s3 cp ${tfi_lx_userdata_log} "s3://${tfi_s3_bucket}/$${S3_TOP_KEYFIX}/$${BUILD_ID}/$${S3_KEYFIX}/userdata.log" || true
aws s3 cp /var/log "s3://${tfi_s3_bucket}/$${S3_TOP_KEYFIX}/$${BUILD_ID}/$${S3_KEYFIX}/cloud-init/" --recursive --exclude "*" --include "cloud*log" || true
aws s3 cp /var/log/watchmaker "s3://${tfi_s3_bucket}/$${S3_TOP_KEYFIX}/$${BUILD_ID}/$${S3_KEYFIX}/watchmaker/" --recursive || true

touch /tmp/SETUP_COMPLETE_SIGNAL
