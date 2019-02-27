# very short template that is scaled based on win instances so that no other templates need be scaled
data "template_file" "win_script_preface" {
  count    = "${local.win_request_count}"
  template = "${file("windows/preface.ps1")}"

  vars {
    tfi_ami_key = "${element(local.win_requests, count.index)}"
    tfi_count_index = "${count.index}"
  }
}

# very short template that is scaled based on lx instances so that no other templates need be scaled
data "template_file" "lx_script_preface" {
  count    = "${local.lx_request_count}"
  template = "${file("linux/preface.sh")}"

  vars {
    tfi_ami_key = "${element(local.lx_requests, count.index)}"
    tfi_count_index = "${count.index}"
  }
}

data "template_file" "win_builder_preface" {
  count    = "${local.win_need_builder}"
  template = "${file("windows/preface.ps1")}"

  vars {
    tfi_ami_key = "${local.win_builder_ami_key}"
    tfi_count_index = "builder"
  }
}

data "template_file" "lx_builder_preface" {
  count    = "${local.lx_need_builder}"
  template = "${file("linux/preface.sh")}"

  vars {
    tfi_ami_key = "${local.lx_builder_ami_key}"
    tfi_count_index = "builder"
  }
}

# userdata for initial configuration powershell script
data "template_file" "win_userdata_specific" {
  count    = "${local.win_request_any_count}"
  template = "${file("windows/userdata.ps1")}"

  vars {
    tfi_common_args  = "${var.tfi_common_args}"
    tfi_win_args     = "${var.tfi_win_args}"
    tfi_executable   = "${local.win_executable}"
    tfi_download_dir = "${local.win_download_dir}"
  }
}

# userdata for initial configuration bash script
data "template_file" "lx_userdata_specific" {
  count    = "${local.lx_request_any_count}"
  template = "${file("linux/userdata.sh")}"

  vars {
    tfi_common_args = "${var.tfi_common_args}"
    tfi_lx_args     = "${var.tfi_lx_args}"
    tfi_executable  = "${local.lx_executable}"
  }
}

# userdata for the builder
data "template_file" "win_userdata_builder_specific" {
  count    = "${local.win_need_builder}"
  template = "${file("windows/builder_userdata.ps1")}"

  vars {
    tfi_release_prefix = "${local.release_prefix}"
  }
}

# userdata for the builder
data "template_file" "lx_userdata_builder_specific" {
  count    = "${local.lx_need_builder}"
  template = "${file("linux/builder_userdata.sh")}"

  vars {
    tfi_docker_slug    = "${var.tfi_docker_slug}"
    tfi_release_prefix = "${local.release_prefix}"
  }
}

data "template_file" "win_userdata_common" {
  count    = "${local.win_request_any_count}"
  template = "${file("windows/userdata_common.ps1")}"

  vars {
    tfi_7zip_url             = "${local.win_7zip_url}"
    tfi_bootstrap_url        = "${local.win_bootstrap_url}"
    tfi_build_slug           = "${local.build_slug}"
    tfi_error_signal_file    = "${local.win_error_signal_file}"
    tfi_git_ref              = "${var.tfi_git_ref}"
    tfi_git_repo             = "${var.tfi_git_repo}"
    tfi_git_url              = "${local.win_git_url}"
    tfi_pypi_url             = "${local.pypi_url}"
    tfi_python_url           = "${local.win_python_url}"
    tfi_rm_pass              = "${random_string.password.result}"
    tfi_rm_user              = "${var.tfi_rm_user}"
    tfi_temp_dir             = "${local.win_temp_dir}"
    tfi_userdata_log         = "${var.tfi_win_userdata_log}"
    tfi_userdata_status_file = "${local.win_userdata_status_file}"
    tfi_debug                = "${var.tfi_debug}"
  }
}

# userdate for the builder
data "template_file" "lx_userdata_common" {
  count    = "${local.lx_request_any_count}"
  template = "${file("linux/userdata_common.sh")}"

  vars {
    tfi_aws_region           = "${var.tfi_aws_region}"
    tfi_build_slug           = "${local.build_slug}"
    tfi_error_signal_file    = "${local.lx_error_signal_file}"
    tfi_git_ref              = "${var.tfi_git_ref}"
    tfi_git_repo             = "${var.tfi_git_repo}"
    tfi_pip_bootstrap_url    = "${local.pip_bootstrap_url}"
    tfi_pypi_url             = "${local.pypi_url}"
    tfi_ssh_port             = "${local.ssh_port}"
    tfi_temp_dir             = "${local.lx_temp_dir}"
    tfi_userdata_log         = "${var.tfi_lx_userdata_log}"
    tfi_userdata_status_file = "${local.lx_userdata_status_file}"
    tfi_debug                = "${var.tfi_debug}"
  }
}

data "template_file" "win_test" {
  count    = "${local.win_request_any_count}"
  template = "${file("windows/watchmaker_test.ps1")}"

  vars {
    tfi_download_dir         = "${local.win_download_dir}"
    tfi_userdata_status_file = "${local.win_userdata_status_file}"
  }
}

data "template_file" "lx_test" {
  count    = "${local.lx_request_any_count}"
  template = "${file("linux/watchmaker_test.sh")}"

  vars {
    tfi_userdata_status_file = "${local.lx_userdata_status_file}"
  }
}

data "template_file" "win_build_test" {
  count    = "${local.win_need_builder}"
  template = "${file("windows/builder_test.ps1")}"

  vars {
    tfi_ami_key              = "${local.win_builder_ami_key}"
    tfi_userdata_status_file = "${local.win_userdata_status_file}"
  }
}

data "template_file" "lx_build_test" {
  count    = "${local.lx_need_builder}"
  template = "${file("linux/builder_test.sh")}"

  vars {
    tfi_ami_key              = "${local.lx_builder_ami_key}"
    tfi_userdata_status_file = "${local.lx_userdata_status_file}"
  }
}
