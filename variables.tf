variable "tfi_az" {
  default = "us-east-1c"
}

variable "tfi_subnet_id" {
  default = ""
}

variable "tfi_instances" {
  default = []
  type    = list(string)
}

variable "tfi_instance_multiplier" {
  default = "1"
}

variable "tfi_rm_user" {
  default = "Administrator"
}

variable "tfi_ssh_user" {
  default = "root"
}

variable "tfi_instance_profile" {
  default = ""
}

variable "tfi_assign_public_ip" {
  default = "false"
}

variable "tfi_win_instance_type" {
  default = "t2.large"
}

variable "tfi_lx_instance_type" {
  default = "t2.medium"
}

variable "tfi_git_repo" {
  default = "https://github.com/plus3it/watchmaker.git"
}

variable "tfi_git_ref" {
  default = "develop"
}

variable "tfi_common_args" {
  default = "-n --log-level debug"
}

variable "tfi_win_args" {
  default = "--log-dir=C:\\Watchmaker\\Logs"
}

variable "tfi_lx_args" {
  default = "--log-dir=/var/log/watchmaker"
}

variable "tfi_win_userdata_log" {
  default = "C:\\Temp\\userdata.log"
}

variable "tfi_lx_userdata_log" {
  default = "/var/log/userdata.log"
}

variable "tfi_s3_bucket" {
  default = "mybucket"
}

variable "tfi_codebuild_id" {
  default = ""
}

variable "tfi_docker_slug" {
  default = ""
}

variable "tfi_aws_region" {
  default = "us-east-1"
}

variable "tfi_debug" {
  default = "1"
}


