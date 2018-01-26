#!/bin/sh

exec &> /tmp/watchmaker_userdata_install.log

sleep 20

WATCHMAKER_INSTALL_GOES_HERE

touch /tmp/SETUP_COMPLETE_SIGNAL
