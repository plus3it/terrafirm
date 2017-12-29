#!/bin/bash

#create a private key file
echo "${SSH_KEY}" > private_key
chmod 600 private_key
echo "Created key file"

#get encrypted password from AWS/Windows instance
#loop/sleep until the instance is ready, i.e., can provide a password
wait_seconds=90 #waits 10 seconds per so x*10 seconds; 90 = 900s = 15m

until test $((wait_seconds--)) -eq 0 -o -n "$ENC_PASSWORD" ; do #waits for timeout or password to not be empty
  PASSWORD_DATA="$(aws ec2 get-password-data --instance-id "$AWS_INSTANCE_ID")"
  ENC_PASSWORD="$(echo "$PASSWORD_DATA" | ./jq.dms -r '."PasswordData"')"
  sleep 10
done
echo "Got encrypted password from AWS"

#Windows or AWS or someone is padding encrypted password with a Windows newline
#Get rid of this newline for decryption to work
if [ "${ENC_PASSWORD:0:4}" = "\r\n" ]; then
  ENC_PASSWORD="${ENC_PASSWORD:4}"
fi

if [ "${ENC_PASSWORD:(-4)}" = "\r\n" ]; then
  ENC_PASSWORD="${ENC_PASSWORD:0:${#ENC_PASSWORD}-4}"
fi
echo "Fixed encrypted password"

#Decrypt the password with the private key
echo "${ENC_PASSWORD}" > encryptedpassword
echo "++++++++"
cat private_key
echo "------------"
base64 -d -i encryptedpassword | openssl rsautl -decrypt -inkey private_key -out decryptedpassword
echo "Decrypted password"

DEC_PASSWORD="$(cat decryptedpassword)" ; export DEC_PASSWORD

#Get rid of temp files
rm encryptedpassword
rm decryptedpassword
rm private_key
