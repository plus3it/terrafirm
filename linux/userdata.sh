#!/bin/bash

exec &> ${tfi_lx_userdata_log}

retry()
{
    local n=0
    local try=$1
    local cmd="$${*: 2}"
    local result=1
    [[ $# -le 1 ]] && {
        echo "Usage $0 <number_of_retry_attempts> <Command>"
        exit $result
    }

    echo "Will try $try time(s) :: $cmd"

    if [[ "$${SHELLOPTS}" == *":errexit:"* ]]
    then
        set +e
        local ERREXIT=1
    fi

    until [[ $n -ge $try ]]
    do
        sleep $n
        $cmd
        result=$?
        if [[ $result -eq 0 ]]
        then
            break
        else
            ((n++))
            echo "Attempt $n, command failed :: $cmd"
        fi
    done

    if [[ "$${ERREXIT}" == "1" ]]
    then
        set -e
    fi

    return $result
}  # ----------  end of function retry  ----------

finally() {
  local exit_code="$${1:-0}"

  echo "Finally: "

  # everything to happen whether install succeeds or fails
  
  # write the status to a file for reading by test script
  printf "%s\n" "$${userdata_status[@]}" > /tmp/userdata_status
  
  # allow ssh to be on non-standard port (SEL-enforced rule)
  setenforce 0

  # open firewall (iptables for rhel/centos 6, firewalld for 7
  systemctl status firewalld &> /dev/null
  if [ $? -eq 0 ] ; then
    echo "Configuring firewalld..."
    firewall-cmd --zone=public --permanent --add-port=122/tcp
    firewall-cmd --reload
  else
    echo "Configuring iptables..."
    iptables -A INPUT -p tcp --dport 122 -j ACCEPT #open port 122
    iptables save
    iptables restart
  fi

  sed -i -e '5iPort 122' /etc/ssh/sshd_config
  sed -i -e 's/Port 22/#Port 22/g' /etc/ssh/sshd_config
  cat /etc/ssh/sshd_config
  service sshd restart

  # get OS version as key prefix
  s3_keyfix=$(cat /etc/redhat-release | cut -c1-3)$(cat /etc/redhat-release | sed 's/[^0-9.]*\([0-9]\.[0-9]\).*/\1/')

  # move logs to s3
  aws s3 cp ${tfi_lx_userdata_log} "s3://${tfi_s3_bucket}/${tfi_build_date}/${tfi_build_id}/$${s3_keyfix}/userdata.log" || true
  aws s3 cp /var/log "s3://${tfi_s3_bucket}/${tfi_build_date}/${tfi_build_id}/$${s3_keyfix}/cloud/" --recursive --exclude "*" --include "cloud*log" || true
  aws s3 cp /var/log/watchmaker "s3://${tfi_s3_bucket}/${tfi_build_date}/${tfi_build_id}/$${s3_keyfix}/watchmaker/" --recursive || true
  
  exit "$${exit_code}"
}

catch() {
  local this_script="$0"
  local exit_code="$${1:-1}"
  local err_lineno="$2"
  echo "$0: line $2: exiting with status $${exit_code}"

  userdata_status=($exit_code "Userdata install error at stage $stage")

  finally $@
}

# setup error trap to go to catch function
trap 'catch $? $${LINENO}' ERR

# everything below this is the TRY

# start time of install
start=`date +%s`

# declare an array to hold the status (number and message)
userdata_status=(0 "Success")

WATCHMAKER_INSTALL_GOES_HERE

# time it took to install
end=`date +%s`
runtime=$((end-start))
echo "WAM install took $runtime seconds."

finally