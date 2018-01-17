#!/bin/sh

exec &> /tmp/watchmaker_userdata_install.log

WATCHMAKER_INSTALL_GOES_HERE

#sed -i '5iPort 2222' /etc/ssh/sshd_config

  # Change ssh port. Set packer to connect to port 122; this way packer waits
  # until this script is complete.
sed -i -e "s/^[#]*Port .*$/Port 122/" /etc/ssh/sshd_config
service sshd restart
  
#/sbin/service sshd restart
/sbin/iptables -A INPUT -p tcp --destination-port 122 -j ACCEPT
/sbin/service iptables save
