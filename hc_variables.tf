#owners of canonical centos, rhel, linux amis
variable "tfi_linux_ami_owners" {
  default = ["701759196663", "self", "125523088429", "099720109477"]
}

#owners of canonical windows amis (basically Amazon)
variable "tfi_windows_ami_owners" {
  default = ["801119661308", "amazon"]
}

#these are just strings that are used by aws_ami data resources to find amis 
variable "tfi_ami_name_filters" {
  default = [
    "spel-minimal-centos-6*",
    "spel-minimal-centos-7*",
    "spel-minimal-rhel-6*",
    "spel-minimal-rhel-7*",
    "Windows_Server-2008-R2_SP1-English-64Bit-Base*",
    "Windows_Server-2012-R2_RTM-English-64Bit-Base*",
    "Windows_Server-2016-English-Full-Base*",
    "Windows_Server-2016-English-Full-SQL_2016_SP1_Standard-*",
    "Windows_Server-2016-English-Full-SQL_2016_SP1_Enterprise-*",
    "Windows_Server-2016-English-Full-SQL_2017_Standard-*",
    "Windows_Server-2016-English-Full-SQL_2017_Enterprise-*",
    "ubuntu/images/hvm-ssd/ubuntu-trusty-14.04-amd64-server*",
  ]
}

variable "tfi_other_filters" {
  type = "map"

  default = {
    virtualization_type = "hvm"
  }
}
