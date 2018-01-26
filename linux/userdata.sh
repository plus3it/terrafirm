#!/bin/sh

exec &> /tmp/userdata.log

yum -y install bc

#sleep 20

WATCHMAKER_INSTALL_GOES_HERE

touch /tmp/SETUP_COMPLETE_SIGNAL
