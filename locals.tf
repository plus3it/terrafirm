locals {
  # Name, name tag, log name related locals
  name_prefix   = "terrafirm"
  date_ymd      = "${substr(data.null_data_source.start_time.inputs.tfi_timestamp,0,4)}${substr(data.null_data_source.start_time.inputs.tfi_timestamp,5,2)}${substr(data.null_data_source.start_time.inputs.tfi_timestamp,8,2)}" #equivalent of $(date +'%Y%m%d')
  date_hm       = "${substr(data.null_data_source.start_time.inputs.tfi_timestamp,11,2)}${substr(data.null_data_source.start_time.inputs.tfi_timestamp,14,2)}"                                                                   #equivalent of $(date +'%H%M')
  full_build_id = "${var.tfi_codebuild_id == "" ? format("notcb:%s", uuid()) : var.tfi_codebuild_id}"                                                                                                                            #128-bit rfc 4122 v4 UUID
  build_id      = "${substr(element(split(":",local.full_build_id),1), 0, 8)}${substr(element(split(":",local.full_build_id),1), 9, 4)}"                                                                                         #extract node portion of uuid (last 6 octets) for brevity
  resource_name = "${local.name_prefix}-${local.build_id}"
}

# magic values
locals {
  pypi_url          = "https://pypi.org/simple"
  pip_bootstrap_url = "https://bootstrap.pypa.io/2.6/get-pip.py"

  win_bootstrap_url        = "https://raw.githubusercontent.com/plus3it/watchmaker/develop/docs/files/bootstrap/watchmaker-bootstrap.ps1"
  win_python_url           = "https://www.python.org/ftp/python/3.6.6/python-3.6.6-amd64.exe"
  win_git_url              = "https://github.com/git-for-windows/git/releases/download/v2.18.0.windows.1/Git-2.18.0-64-bit.exe"
  win_download_dir         = "C:\\Users\\Administrator\\Downloads"
  win_temp_dir             = "C:\\Temp"
  win_userdata_status_file = "${local.win_temp_dir}\\userdata_status"
  win_7zip_url             = "https://www.7-zip.org/a/7z1805-x64.exe"

  lx_temp_dir             = "/tmp"
  lx_userdata_status_file = "${local.lx_temp_dir}/userdata_status"
  lx_builder_user         = "ubuntu"
}

# windows goodness
locals {
  # the one place where win ami key strings (aka "ami keys") are defined
  win_amis_all_keys = "${split(",","win08,win12,win16,win08pkg,win12pkg,win16pkg")}"

  # the build from source test ami key strings tied to ami ids
  win_amis = {
    "${local.win_amis_all_keys[0]}" = "${data.aws_ami.win08.id}"
    "${local.win_amis_all_keys[1]}" = "${data.aws_ami.win12.id}"
    "${local.win_amis_all_keys[2]}" = "${data.aws_ami.win16.id}"
  }

  # the standalone test amis (which mirror build from source)
  win_amis_pkg = {
    "${local.win_amis_all_keys[3]}" = "${lookup(local.win_amis,local.win_amis_all_keys[0])}"
    "${local.win_amis_all_keys[4]}" = "${lookup(local.win_amis,local.win_amis_all_keys[1])}"
    "${local.win_amis_all_keys[5]}" = "${lookup(local.win_amis,local.win_amis_all_keys[2])}"
  }

  # all the amis available (key string to ami id)
  win_amis_all = "${merge(local.win_amis, local.win_amis_pkg)}"

  # what has actually been requested, ami key strings tied to ami ids
  win_amis_all_requests = "${matchkeys(
    values(local.win_amis_all),
    keys(local.win_amis_all),
    split(",", var.tfi_win_instances)
  )}"

  # just the ami key strings, tied to themselves for easily getting key with same mechanism as ami id
  win_keys_all_requests = "${matchkeys(
    keys(local.win_amis_all),
    keys(local.win_amis_all),
    split(",", var.tfi_win_instances)
  )}"

  # which standalone package tests have actually been requested
  win_amis_pkg_requests = "${matchkeys(
    values(local.win_amis_pkg),
    keys(local.win_amis_pkg),
    split(",", var.tfi_win_instances)
  )}"

  # count of all win tests requested
  win_count_all_requests = "${length(local.win_amis_all_requests)}"

  # only one builder is needed even if there are multiple package test instances
  win_count_builder = "${length(local.win_amis_pkg_requests) == 0 ? 0 : 1}"

  win_builder_ami_key = "win-builder"
}

# linux goodness
locals {
  ssh_port = 122

  # the one place where lx ami key strings (aka "ami keys") are defined
  lx_amis_all_keys = "${split(",","centos6,centos7,rhel6,rhel7,centos6pkg,centos7pkg,rhel6pkg,rhel7pkg")}"

  # the build from source test ami key strings tied to ami ids
  lx_amis = {
    "${local.lx_amis_all_keys[0]}" = "${data.aws_ami.centos6.id}"
    "${local.lx_amis_all_keys[1]}" = "${data.aws_ami.centos7.id}"
    "${local.lx_amis_all_keys[2]}" = "${data.aws_ami.rhel6.id}"
    "${local.lx_amis_all_keys[3]}" = "${data.aws_ami.rhel7.id}"
  }

  # the standalone test amis (which mirror build from source)
  lx_amis_pkg = {
    "${local.lx_amis_all_keys[4]}" = "${lookup(local.lx_amis,local.lx_amis_all_keys[0])}"
    "${local.lx_amis_all_keys[5]}" = "${lookup(local.lx_amis,local.lx_amis_all_keys[1])}"
    "${local.lx_amis_all_keys[6]}" = "${lookup(local.lx_amis,local.lx_amis_all_keys[2])}"
    "${local.lx_amis_all_keys[7]}" = "${lookup(local.lx_amis,local.lx_amis_all_keys[3])}"
  }

  # all the amis available (key string to ami id)
  lx_amis_all = "${merge(local.lx_amis, local.lx_amis_pkg)}"

  # what has actually been requested, ami key strings tied to ami ids
  lx_amis_all_requests = "${matchkeys(
    values(local.lx_amis_all),
    keys(local.lx_amis_all),
    split(",", var.tfi_lx_instances)
  )}"

  # just the ami key strings, tied to themselves for easily getting key with same mechanism as ami id
  lx_keys_all_requests = "${matchkeys(
    keys(local.lx_amis_all),
    keys(local.lx_amis_all),
    split(",", var.tfi_lx_instances)
  )}"

  # which standalone package tests have actually been requested
  lx_amis_pkg_requests = "${matchkeys(
    values(local.lx_amis_pkg),
    keys(local.lx_amis_pkg),
    split(",", var.tfi_lx_instances)
  )}"

  # count of all lx tests requested
  lx_count_all_requests = "${length(local.lx_amis_all_requests)}"

  # only one builder is needed even if there are multiple package test instances
  lx_count_builder = "${length(local.lx_amis_pkg_requests) == 0 ? 0 : 1}"

  lx_builder_ami_key = "lx-builder"
}
