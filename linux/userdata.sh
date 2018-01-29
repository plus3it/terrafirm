#!/bin/sh

exec &> ${tfi_lx_userdata_log}

yum -y install bc

#sleep 20

WATCHMAKER_INSTALL_GOES_HERE

#copy files to S3 using AWS CLI
pip install awscli --upgrade
export AWS_ACCESS_KEY_ID=${tfi_cli_access_key_id}
export AWS_SECRET_ACCESS_KEY=${tfi_cli_secret_access_key}
export AWS_DEFAULT_REGION=${tfi_region}

touch /tmp/SETUP_COMPLETE_SIGNAL
