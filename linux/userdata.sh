#!/bin/sh

exec &> /tmp/watchmaker_userdata_install.log

/sbin/iptables -A INPUT -p tcp --destination-port 122 -j DROP
/sbin/service iptables save

WATCHMAKER_INSTALL_GOES_HERE

/sbin/iptables -A INPUT -p tcp --destination-port 122 -j ACCEPT
/sbin/service iptables save
