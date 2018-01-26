#!/bin/sh

exec &> /tmp/watchmaker_userdata_install.log

sleep 30

WATCHMAKER_INSTALL_GOES_HERE

touch /tmp/SETUP_COMPLETE_SIGNAL
