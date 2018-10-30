# setup error trap to go to catch function
trap 'catch $? $${LINENO}' ERR

if [[ "$ami_key" == *pkg ]]; then
  # if it ends with 'pkg', test standalone

  standalone_location="s3://$build_slug/${tfi_executable}"
  error_location="s3://$build_slug/$error_signal_file"
  sleep_time=20
  nonexistent_code="nonexistent"
  no_error_code="0"

  write-tfi "Looking for standalone executable at $standalone_location"

  #block until executable exists, an error, or timeout
  while true; do

    # aws s3 ls $standalone_location ==> exit 1, if it doesn't exist!

    # find out what's happening with the builder
    exists=$(aws s3 ls $standalone_location || echo "$nonexistent_code")
    error=$(aws s3 ls $error_location || echo "$no_error_code")

    if [ "$error" != "0" ]; then
      # error signaled by the builder
      write-tfi "Error signaled by the builder"
      write-tfi "Error file found at $error_location"
      catch 1 $${LINENO}
      break
    else
      # no builder errors signaled
      if [ "$exists" = "$nonexistent_code"  ]; then
        # standalone does not exist
        write-tfi "The standalone executable was not found. Trying again in $${sleep_time}s..."
        sleep $sleep_time
      else
        # it exists!
        write-tfi "The standalone executable was found!"
        break
      fi
    fi

  done

  standalone_dest=/home/maintuser
  aws s3 cp $standalone_location $standalone_dest/watchmaker
  write-tfi "Download Watchmaker standalone" $?
  chmod +x $standalone_dest/watchmaker

  stage="Run Watchmaker" && $standalone_dest/watchmaker ${tfi_common_args} ${tfi_lx_args}
  write-tfi "$stage" $?

else
  # test install from source

  # Install git
  retry 5 yum -y install git
  write-tfi "Yum install Git" $?

  install-watchmaker

  # Run watchmaker
  stage="Run Watchmaker" && watchmaker ${tfi_common_args} ${tfi_lx_args}
  write-tfi "$stage" $?

  # ----------  end of wam install  ----------
fi

finally
