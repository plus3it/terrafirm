#!/bin/sh

exec &> /tmp/watchmaker_userdata_install.log

iptables -A INPUT -p tcp --destination-port 122 -j DROP
service iptables save

WATCHMAKER_INSTALL_GOES_HERE

iptables -A INPUT -p tcp --destination-port 122 -j ACCEPT
service iptables save
