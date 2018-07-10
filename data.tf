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

# Template for initial configuration bash script
data "template_file" "win_userdata" {
  count    = "${length(matchkeys(values(local.win_amis),keys(local.win_amis),split(",", var.tfi_win_instances)))}"
  template = "${file("windows/userdata.ps1")}"

  vars {
    tfi_git_repo         = "${var.tfi_git_repo}"
    tfi_git_ref          = "${var.tfi_git_ref}"
    tfi_common_args      = "${var.tfi_common_args}"
    tfi_win_args         = "${var.tfi_win_args}"
    tfi_rm_pass          = "${random_string.password.result}"
    tfi_rm_user          = "${var.tfi_rm_user}"
    tfi_win_userdata_log = "${var.tfi_win_userdata_log}"
    tfi_s3_bucket        = "${var.tfi_s3_bucket}"
    tfi_build_date       = "${local.date_ymd}"
    tfi_build_hour       = "${local.date_hm}"
    tfi_build_id         = "${local.build_id}"
    tfi_ami_key          = "${element(matchkeys(keys(local.win_amis),keys(local.win_amis),split(",", var.tfi_win_instances)), count.index)}"
  }
}

# Template for initial configuration bash script
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
    tfi_ami_key         = "lx_builder"
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
data "aws_ami" "windows2008" {
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
data "aws_ami" "windows2012" {
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
data "aws_ami" "windows2016" {
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

data "aws_ami" "win16sql16s" {
  most_recent = true

  filter {
    name   = "virtualization-type"
    values = ["${var.tfi_other_filters["virtualization_type"]}"]
  }

  filter {
    name   = "name"
    values = ["${element(var.tfi_ami_name_filters, 7)}"]
  }

  owners = "${var.tfi_windows_ami_owners}"
}

data "aws_ami" "win16sql16e" {
  most_recent = true

  filter {
    name   = "virtualization-type"
    values = ["${var.tfi_other_filters["virtualization_type"]}"]
  }

  filter {
    name   = "name"
    values = ["${element(var.tfi_ami_name_filters, 8)}"]
  }

  owners = "${var.tfi_windows_ami_owners}"
}

data "aws_ami" "win16sql17s" {
  most_recent = true

  filter {
    name   = "virtualization-type"
    values = ["${var.tfi_other_filters["virtualization_type"]}"]
  }

  filter {
    name   = "name"
    values = ["${element(var.tfi_ami_name_filters, 9)}"]
  }

  owners = "${var.tfi_windows_ami_owners}"
}

data "aws_ami" "win16sql17e" {
  most_recent = true

  filter {
    name   = "virtualization-type"
    values = ["${var.tfi_other_filters["virtualization_type"]}"]
  }

  filter {
    name   = "name"
    values = ["${element(var.tfi_ami_name_filters, 10)}"]
  }

  owners = "${var.tfi_windows_ami_owners}"
}

data "aws_ami" "trusty" {
  most_recent = true

  filter {
    name   = "virtualization-type"
    values = ["${var.tfi_other_filters["virtualization_type"]}"]
  }

  filter {
    name   = "name"
    values = ["${element(var.tfi_ami_name_filters, 11)}"]
  }

  owners = "${var.tfi_linux_ami_owners}"
}
