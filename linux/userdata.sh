#!/bin/sh

exec &> /tmp/watchmaker_userdata_install.log

/sbin/iptables -A INPUT -p tcp --destination-port 2222 -j DROP
/sbin/service iptables save

WATCHMAKER_INSTALL_GOES_HERE

sed -i '5iPort 2222' /etc/ssh/sshd_config
/sbin/service sshd restart
/sbin/iptables -A INPUT -p tcp --destination-port 2222 -j ACCEPT
/sbin/service iptables save
