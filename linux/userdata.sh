#!/bin/sh

exec &> /tmp/watchmaker_userdata_install.log

WATCHMAKER_INSTALL_GOES_HERE

#sed -i -e "s/^[#]*Port .*$/Port 122/" /etc/ssh/sshd_config
sed -i '5iPort 122' /etc/ssh/sshd_config
service sshd restart
  
#/sbin/service sshd restart
#iptables -I INPUT -p tcp -m tcp --dport 122 -j ACCEPT
#service iptables save
