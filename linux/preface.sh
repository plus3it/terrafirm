#!/bin/bash

ami_key="${tfi_ami_key}"
count_index="${tfi_count_index}"
index_str="lx-$${count_index}-"
if [ "$${count_index}" = "builder" ]; then
  index_str=""
fi
