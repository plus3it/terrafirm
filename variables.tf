variable "availability_zone" {
  default = "us-east-1c"
  type    = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "source_builds" {
  default = ["win12", "win16", "win19", "rhel7", "centos7", "rhel8", "centos8stream", "ol8"]
  type    = list(string)
}

variable "standalone_builds" {
  default = ["win12", "win16", "win19", "rhel7", "centos7", "rhel8", "centos8stream", "ol8"]
  type    = list(string)
}

variable "win_user" {
  default = "Administrator"
  type    = string
}

variable "lx_user" {
  default = "root"
  type    = string
}

variable "instance_profile" {
  default = ""
  type    = string
}

variable "assign_public_ip" {
  default = false
  type    = bool
}

variable "win_instance_type" {
  default = "t2.large"
  type    = string
}

variable "lx_instance_type" {
  default = "t2.medium"
  type    = string
}

variable "git_repo" {
  default = "https://github.com/plus3it/watchmaker.git"
  type    = string
}

variable "git_ref" {
  default = "main"
  type    = string
}

variable "common_args" {
  default = "-n --log-level debug"
  type    = string
}

variable "win_args" {
  default = "--log-dir=C:\\Watchmaker\\Logs"
  type    = string
}

variable "lx_args" {
  default = "--log-dir=/var/log/watchmaker"
  type    = string
}

variable "win_userdata_log" {
  default = "C:\\Temp\\userdata.log"
  type    = string
}

variable "lx_userdata_log" {
  default = "/var/log/userdata.log"
  type    = string
}

variable "s3_bucket" {
  default = "mybucket"
  type    = string
}

variable "scan_s3_url" {
  default = ""
  type    = string

  validation {
    condition     = can(regex("^$|^s3://(.*)$", var.scan_s3_url))
    error_message = "The scan_s3_url value can be blank or must be in the form s3://<bucket-name>/<prefix>."
  }
}

variable "codebuild_id" {
  default = ""
  type    = string
}

variable "docker_slug" {
  default = ""
  type    = string
}

variable "aws_region" {
  default = "us-east-1"
  type    = string
}

variable "debug" {
  default = true
  type    = bool
}
