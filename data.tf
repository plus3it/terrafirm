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
    tfi_common_args  = "${var.tfi_common_args}"
    tfi_win_args     = "${var.tfi_win_args}"
    tfi_rm_user      = "${var.tfi_rm_user}"
    tfi_s3_bucket    = "${var.tfi_s3_bucket}"
    tfi_build_date   = "${local.date_ymd}"
    tfi_build_hour   = "${local.date_hm}"
    tfi_build_id     = "${local.build_id}"
    tfi_download_dir = "${local.win_download_dir}"
  }
}

data "template_file" "win_userdata_common" {
  count    = "${local.win_count_all_requests}"
  template = "${file("windows/userdata_common.ps1")}"

  vars {
    tfi_rm_pass              = "${random_string.password.result}"
    tfi_git_repo             = "${var.tfi_git_repo}"
    tfi_git_ref              = "${var.tfi_git_ref}"
    tfi_win_userdata_log     = "${var.tfi_win_userdata_log}"
    tfi_s3_bucket            = "${var.tfi_s3_bucket}"
    tfi_build_date           = "${local.date_ymd}"
    tfi_build_hour           = "${local.date_hm}"
    tfi_build_id             = "${local.build_id}"
    tfi_ami_key              = "${element(local.win_keys_all_requests, count.index)}"
    tfi_win_temp_dir         = "${local.win_temp_dir}"
    tfi_userdata_status_file = "${local.win_userdata_status_file}"
    tfi_pypi_url             = "${local.pypi_url}"
    tfi_win_bootstrap_url    = "${local.win_bootstrap_url}"
    tfi_win_python_url       = "${local.win_python_url}"
    tfi_win_git_url          = "${local.win_git_url}"
    tfi_win_7zip_url         = "${local.win_7zip_url}"
  }
}

# userdata for the builder
data "template_file" "win_userdata_builder_specific" {
  template = "${file("windows/builder_userdata.ps1")}"

  vars {
    tfi_rm_user    = "${var.tfi_rm_user}"
    tfi_s3_bucket  = "${var.tfi_s3_bucket}"
    tfi_build_date = "${local.date_ymd}"
    tfi_build_hour = "${local.date_hm}"
    tfi_build_id   = "${local.build_id}"
  }
}

data "template_file" "win_userdata_builder_common" {
  template = "${file("windows/userdata_common.ps1")}"

  vars {
    tfi_rm_pass              = "${random_string.password.result}"
    tfi_git_repo             = "${var.tfi_git_repo}"
    tfi_git_ref              = "${var.tfi_git_ref}"
    tfi_win_userdata_log     = "${var.tfi_win_userdata_log}"
    tfi_s3_bucket            = "${var.tfi_s3_bucket}"
    tfi_build_date           = "${local.date_ymd}"
    tfi_build_hour           = "${local.date_hm}"
    tfi_build_id             = "${local.build_id}"
    tfi_ami_key              = "${local.win_builder_ami_key}"
    tfi_win_temp_dir         = "${local.win_temp_dir}"
    tfi_userdata_status_file = "${local.win_userdata_status_file}"
    tfi_pypi_url             = "${local.pypi_url}"
    tfi_win_bootstrap_url    = "${local.win_bootstrap_url}"
    tfi_win_python_url       = "${local.win_python_url}"
    tfi_win_git_url          = "${local.win_git_url}"
    tfi_win_7zip_url         = "${local.win_7zip_url}"
  }
}

data "template_file" "win_test" {
  count    = "${local.win_count_all_requests}"
  template = "${file("windows/watchmaker_test.ps1")}"

  vars {
    tfi_ami_key              = "${element(local.win_keys_all_requests, count.index)}"
    tfi_download_dir         = "${local.win_download_dir}"
    tfi_userdata_status_file = "${local.win_userdata_status_file}"
  }
}

data "template_file" "win_build_test" {
  template = "${file("windows/builder_test.ps1")}"

  vars {
    tfi_ami_key              = "${local.win_builder_ami_key}"
    tfi_userdata_status_file = "${local.win_userdata_status_file}"
  }
}

# userdata for initial configuration bash script
data "template_file" "lx_userdata_specific" {
  template = "${file("linux/userdata.sh")}"

  vars {
    tfi_common_args = "${var.tfi_common_args}"
    tfi_lx_args     = "${var.tfi_lx_args}"
    tfi_s3_bucket   = "${var.tfi_s3_bucket}"
    tfi_build_date  = "${local.date_ymd}"
    tfi_build_hour  = "${local.date_hm}"
    tfi_build_id    = "${local.build_id}"
  }
}

# userdate for the builder
data "template_file" "lx_userdata_common" {
  count    = "${local.lx_count_all_requests}"
  template = "${file("linux/userdata_common.sh")}"

  vars {
    tfi_git_repo             = "${var.tfi_git_repo}"
    tfi_git_ref              = "${var.tfi_git_ref}"
    tfi_lx_userdata_log      = "${var.tfi_lx_userdata_log}"
    tfi_s3_bucket            = "${var.tfi_s3_bucket}"
    tfi_build_date           = "${local.date_ymd}"
    tfi_build_hour           = "${local.date_hm}"
    tfi_build_id             = "${local.build_id}"
    tfi_ami_key              = "${element(local.lx_keys_all_requests, count.index)}"
    tfi_aws_region           = "${var.tfi_aws_region}"
    tfi_ssh_port             = "${local.ssh_port}"
    tfi_userdata_status_file = "${local.win_userdata_status_file}"
    tfi_pypi_url             = "${local.pypi_url}"
    tfi_pip_bootstrap_url    = "${local.pip_bootstrap_url}"
    tfi_lx_temp_dir          = "${local.lx_temp_dir}"
    tfi_userdata_status_file = "${local.lx_userdata_status_file}"
  }
}

# userdata for initial configuration bash script
data "template_file" "lx_userdata_builder_specific" {
  template = "${file("linux/builder_userdata.sh")}"

  vars {
    tfi_s3_bucket   = "${var.tfi_s3_bucket}"
    tfi_build_date  = "${local.date_ymd}"
    tfi_build_hour  = "${local.date_hm}"
    tfi_build_id    = "${local.build_id}"
    tfi_docker_slug = "${var.tfi_docker_slug}"
    tfi_aws_region  = "${var.tfi_aws_region}"
  }
}

# userdate for the builder
data "template_file" "lx_userdata_builder_common" {
  template = "${file("linux/userdata_common.sh")}"

  vars {
    tfi_git_repo             = "${var.tfi_git_repo}"
    tfi_git_ref              = "${var.tfi_git_ref}"
    tfi_lx_userdata_log      = "${var.tfi_lx_userdata_log}"
    tfi_s3_bucket            = "${var.tfi_s3_bucket}"
    tfi_build_date           = "${local.date_ymd}"
    tfi_build_hour           = "${local.date_hm}"
    tfi_build_id             = "${local.build_id}"
    tfi_ami_key              = "${local.lx_builder_ami_key}"
    tfi_aws_region           = "${var.tfi_aws_region}"
    tfi_ssh_port             = "${local.ssh_port}"
    tfi_userdata_status_file = "${local.win_userdata_status_file}"
    tfi_pypi_url             = "${local.pypi_url}"
    tfi_pip_bootstrap_url    = "${local.pip_bootstrap_url}"
    tfi_lx_temp_dir          = "${local.lx_temp_dir}"
    tfi_userdata_status_file = "${local.lx_userdata_status_file}"
  }
}

data "template_file" "lx_test" {
  count    = "${local.lx_count_all_requests}"
  template = "${file("linux/watchmaker_test.sh")}"

  vars {
    tfi_ami_key              = "${element(local.lx_keys_all_requests, count.index)}"
    tfi_userdata_status_file = "${local.lx_userdata_status_file}"
  }
}

data "template_file" "lx_build_test" {
  template = "${file("linux/builder_test.sh")}"

  vars {
    tfi_ami_key              = "${local.lx_builder_ami_key}"
    tfi_userdata_status_file = "${local.lx_userdata_status_file}"
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
