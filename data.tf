# Synchronize your watches
data "null_data_source" "start_time" {
  inputs = {
    # necessary because if you just call timestamp in a local it re-evaluates it everytime that var is read
    tfi_timestamp = "${timestamp()}"
  }
}

# Subnet for instances
data "aws_subnet" "tfi" {
  id = "${var.tfi_subnet_id == "" ? aws_default_subnet.tfi.id : var.tfi_subnet_id}"
}

# Used to get local ip for security group ingress
data "http" "ip" {
  url = "http://ipv4.icanhazip.com"
}

# userdata for initial configuration powershell script
data "template_file" "win_userdata_specific" {
  template = "${file("windows/userdata.ps1")}"

  vars {
    tfi_git_repo         = "${var.tfi_git_repo}"
    tfi_git_ref          = "${var.tfi_git_ref}"
    tfi_common_args      = "${var.tfi_common_args}"
    tfi_win_args         = "${var.tfi_win_args}"
    tfi_rm_pass          = "${random_string.password.result}"
    tfi_rm_user          = "${var.tfi_rm_user}"
    tfi_s3_bucket        = "${var.tfi_s3_bucket}"
    tfi_build_date       = "${local.date_ymd}"
    tfi_build_hour       = "${local.date_hm}"
    tfi_build_id         = "${local.build_id}"
  }
}

data "template_file" "win_userdata_common" {
  count    = "${local.win_count_all}"  
  template = "${file("windows/userdata_common.ps1")}"

  vars {
    tfi_win_userdata_log = "${var.tfi_win_userdata_log}"
    tfi_s3_bucket        = "${var.tfi_s3_bucket}"
    tfi_build_date       = "${local.date_ymd}"
    tfi_build_hour       = "${local.date_hm}"
    tfi_build_id         = "${local.build_id}"
    tfi_ami_key          = "${element(local.win_key_requests_all, count.index)}"
  }  
}

# userdata for the builder
data "template_file" "win_userdata_builder_specific" {
  template = "${file("windows/builder_userdata.ps1")}"

  vars {
    tfi_git_repo         = "${var.tfi_git_repo}"
    tfi_git_ref          = "${var.tfi_git_ref}"
    tfi_rm_pass          = "${random_string.password.result}"
    tfi_rm_user          = "${var.tfi_rm_user}"
    tfi_s3_bucket        = "${var.tfi_s3_bucket}"
    tfi_build_date       = "${local.date_ymd}"
    tfi_build_hour       = "${local.date_hm}"
    tfi_build_id         = "${local.build_id}"
  }
}

data "template_file" "win_userdata_builder_common" {
  template = "${file("windows/userdata_common.ps1")}"

  vars {
    tfi_win_userdata_log = "${var.tfi_win_userdata_log}"
    tfi_s3_bucket        = "${var.tfi_s3_bucket}"
    tfi_build_date       = "${local.date_ymd}"
    tfi_build_hour       = "${local.date_hm}"
    tfi_build_id         = "${local.build_id}"
    tfi_ami_key          = "${local.win_builder_ami_key}"
  }  
}

# userdata for initial configuration bash script
data "template_file" "lx_userdata" {
  count    = "${local.lx_count_all}"
  template = "${file("linux/userdata.sh")}"

  vars {
    tfi_git_repo        = "${var.tfi_git_repo}"
    tfi_git_ref         = "${var.tfi_git_ref}"
    tfi_common_args     = "${var.tfi_common_args}"
    tfi_lx_args         = "${var.tfi_lx_args}"
    tfi_ssh_user        = "${var.tfi_ssh_user}"
    tfi_lx_userdata_log = "${var.tfi_lx_userdata_log}"
    tfi_s3_bucket       = "${var.tfi_s3_bucket}"
    tfi_build_date      = "${local.date_ymd}"
    tfi_build_hour      = "${local.date_hm}"
    tfi_build_id        = "${local.build_id}"
    tfi_ami_key         = "${element(local.lx_key_requests_all, count.index)}"
  }
}

# userdate for the builder
data "template_file" "lx_builder_userdata" {
  template = "${file("linux/builder_userdata.sh")}"

  vars {
    tfi_git_repo        = "${var.tfi_git_repo}"
    tfi_git_ref         = "${var.tfi_git_ref}"
    tfi_lx_userdata_log = "${var.tfi_lx_userdata_log}"
    tfi_s3_bucket       = "${var.tfi_s3_bucket}"
    tfi_build_date      = "${local.date_ymd}"
    tfi_build_hour      = "${local.date_hm}"
    tfi_build_id        = "${local.build_id}"
    tfi_ami_key         = "${local.lx_builder_ami_key}"
    tfi_docker_slug     = "${var.tfi_docker_slug}"
    tfi_aws_region      = "${var.tfi_aws_region}"
  }
}

#used just to find the ami id matching criteria, which is then used in provisioning resource
data "aws_ami" "centos6" {
  most_recent = true

  filter {
    name   = "virtualization-type"
    values = ["${var.tfi_other_filters["virtualization_type"]}"]
  }

  filter {
    name   = "name"
    values = ["${element(var.tfi_ami_name_filters, 0)}"]
  }

  owners = "${var.tfi_linux_ami_owners}"
}

#used just to find the ami id matching criteria, which is then used in provisioning resource
data "aws_ami" "centos7" {
  most_recent = true

  filter {
    name   = "virtualization-type"
    values = ["${var.tfi_other_filters["virtualization_type"]}"]
  }

  filter {
    name   = "name"
    values = ["${element(var.tfi_ami_name_filters, 1)}"]
  }

  owners = "${var.tfi_linux_ami_owners}"
}

#used just to find the ami id matching criteria, which is then used in provisioning resource
data "aws_ami" "rhel6" {
  most_recent = true

  filter {
    name   = "virtualization-type"
    values = ["${var.tfi_other_filters["virtualization_type"]}"]
  }

  filter {
    name   = "name"
    values = ["${element(var.tfi_ami_name_filters, 2)}"]
  }

  owners = "${var.tfi_linux_ami_owners}"
}

#used just to find the ami id matching criteria, which is then used in provisioning resource
data "aws_ami" "rhel7" {
  most_recent = true

  filter {
    name   = "virtualization-type"
    values = ["${var.tfi_other_filters["virtualization_type"]}"]
  }

  filter {
    name   = "name"
    values = ["${element(var.tfi_ami_name_filters, 3)}"]
  }

  owners = "${var.tfi_linux_ami_owners}"
}

#used just to find the ami id matching criteria, which is then used in provisioning resource
data "aws_ami" "win08" {
  most_recent = true

  filter {
    name   = "virtualization-type"
    values = ["${var.tfi_other_filters["virtualization_type"]}"]
  }

  filter {
    name   = "name"
    values = ["${element(var.tfi_ami_name_filters, 4)}"]
  }

  owners = "${var.tfi_windows_ami_owners}"
}

#used just to find the ami id matching criteria, which is then used in provisioning resource
data "aws_ami" "win12" {
  most_recent = true

  filter {
    name   = "virtualization-type"
    values = ["${var.tfi_other_filters["virtualization_type"]}"]
  }

  filter {
    name   = "name"
    values = ["${element(var.tfi_ami_name_filters, 5)}"]
  }

  owners = "${var.tfi_windows_ami_owners}"
}

#used just to find the ami id matching criteria, which is then used in provisioning resource
data "aws_ami" "win16" {
  most_recent = true

  filter {
    name   = "virtualization-type"
    values = ["${var.tfi_other_filters["virtualization_type"]}"]
  }

  filter {
    name   = "name"
    values = ["${element(var.tfi_ami_name_filters, 6)}"]
  }

  owners = "${var.tfi_windows_ami_owners}"
}

data "aws_ami" "lx_builder" {
  most_recent = true

  filter {
    name   = "virtualization-type"
    values = ["${var.tfi_other_filters["virtualization_type"]}"]
  }

  filter {
    name   = "name"
    values = ["${element(var.tfi_ami_name_filters, 7)}"]
  }

  owners = "${var.tfi_linux_ami_owners}"
}
