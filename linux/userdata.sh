#!/bin/sh

exec &> /tmp/watchmaker_userdata_install.log

WATCHMAKER_INSTALL_GOES_HERE


# Signal completion of userdata
touch /tmp/SETUP_COMPLETE_SIGNAL
