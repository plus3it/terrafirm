#!/bin/bash

wait_seconds=90 #waits 10 seconds per so x*10 seconds; 90 = 900s = 15m

until test $((wait_seconds--)) -eq 0 -o -n "$DEC_PASSWORD" ; do #waits for timeout or password to not be empty
  PASSWORD_DATA="$(aws ec2 get-password-data --instance-id $AWS_INSTANCE_ID --priv-launch-key private_key)" ; export PASSWORD_DATA
  DEC_PASSWORD="$(echo $PASSWORD_DATA | ./jq.dms -r '."PasswordData"')" ; export DEC_PASSWORD
  sleep 10
done
