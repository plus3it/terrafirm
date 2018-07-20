locals {
  # Name, name tag, log name related locals
  name_prefix   = "terrafirm"
  date_ymd      = "${substr(data.null_data_source.start_time.inputs.tfi_timestamp,0,4)}${substr(data.null_data_source.start_time.inputs.tfi_timestamp,5,2)}${substr(data.null_data_source.start_time.inputs.tfi_timestamp,8,2)}" #equivalent of $(date +'%Y%m%d')
  date_hm       = "${substr(data.null_data_source.start_time.inputs.tfi_timestamp,11,2)}${substr(data.null_data_source.start_time.inputs.tfi_timestamp,14,2)}"                                                                   #equivalent of $(date +'%H%M')
  full_build_id = "${var.tfi_codebuild_id == "" ? format("notcb:%s", uuid()) : var.tfi_codebuild_id}"                                                                                                                            #128-bit rfc 4122 v4 UUID
  build_id      = "${substr(element(split(":",local.full_build_id),1), 0, 8)}${substr(element(split(":",local.full_build_id),1), 9, 4)}"                                                                                         #extract node portion of uuid (last 6 octets) for brevity
  resource_name = "${local.name_prefix}-${local.build_id}"
}

# windows goodness
locals {

  # the one place where win ami key strings (aka "ami keys") are defined
  win_ami_keys_all = "${split(",","win08,win12,win16,win08pkg,win12pkg,win16pkg")}"

  # the build from source test ami key strings tied to ami ids
  win_amis = {
    "${local.win_ami_keys_all[0]}" = "${data.aws_ami.win08.id}"
    "${local.win_ami_keys_all[1]}" = "${data.aws_ami.win12.id}"
    "${local.win_ami_keys_all[2]}" = "${data.aws_ami.win16.id}"
  }

  # the standalone test amis (which mirror build from source)
  win_amis_pkg = {
    "${local.win_ami_keys_all[3]}" = "${lookup(local.win_amis,local.win_ami_keys_all[0])}"
    "${local.win_ami_keys_all[4]}" = "${lookup(local.win_amis,local.win_ami_keys_all[1])}"
    "${local.win_ami_keys_all[5]}" = "${lookup(local.win_amis,local.win_ami_keys_all[2])}"
  }

  # all the amis available (key string to ami id)
  win_amis_all = "${merge(local.win_amis, local.win_amis_pkg)}"

  # what has actually been requested, ami key strings tied to ami ids
  win_ami_requests_all = "${matchkeys(
    values(local.win_amis_all),
    keys(local.win_amis_all),
    split(",", var.tfi_win_instances)
  )}"

  # just the ami key strings, tied to themselves for easily getting key with same mechanism as ami id
  win_key_requests_all = "${matchkeys(
    keys(local.win_amis_all),
    keys(local.win_amis_all),
    split(",", var.tfi_win_instances)
  )}"
  
  # which standalone package tests have actually been requested
  win_ami_requests_pkg = "${matchkeys(
    values(local.win_amis_pkg),
    keys(local.win_amis_pkg),
    split(",", var.tfi_win_instances)
  )}"

  # count of all win tests requested
  win_count_all = "${length(local.win_ami_requests_all)}"

  # only one builder is needed even if there are multiple package test instances
  win_count_builder = "${length(local.win_ami_requests_pkg) == 0 ? 0 : 1}"

  win_builder_ami_key = "win-builder"

}

# linux goodness
locals {
  # the one place where lx ami key strings (aka "ami keys") are defined
  lx_ami_keys_all = "${split(",","centos6,centos7,rhel6,rhel7,centos6pkg,centos7pkg,rhel6pkg,rhel7pkg")}"

  # the build from source test ami key strings tied to ami ids
  lx_amis = {
    "${local.lx_ami_keys_all[0]}" = "${data.aws_ami.centos6.id}"
    "${local.lx_ami_keys_all[1]}" = "${data.aws_ami.centos7.id}"
    "${local.lx_ami_keys_all[2]}" = "${data.aws_ami.rhel6.id}"
    "${local.lx_ami_keys_all[3]}" = "${data.aws_ami.rhel7.id}"
  }

  # the standalone test amis (which mirror build from source)
  lx_amis_pkg = {
    "${local.lx_ami_keys_all[4]}" = "${lookup(local.lx_amis,local.lx_ami_keys_all[0])}"
    "${local.lx_ami_keys_all[5]}" = "${lookup(local.lx_amis,local.lx_ami_keys_all[1])}"
    "${local.lx_ami_keys_all[6]}" = "${lookup(local.lx_amis,local.lx_ami_keys_all[2])}"
    "${local.lx_ami_keys_all[7]}" = "${lookup(local.lx_amis,local.lx_ami_keys_all[3])}"
  }

  # all the amis available (key string to ami id)
  lx_amis_all = "${merge(local.lx_amis, local.lx_amis_pkg)}"

  # what has actually been requested, ami key strings tied to ami ids
  lx_ami_requests_all = "${matchkeys(
    values(local.lx_amis_all),
    keys(local.lx_amis_all),
    split(",", var.tfi_lx_instances)
  )}"

  # just the ami key strings, tied to themselves for easily getting key with same mechanism as ami id
  lx_key_requests_all = "${matchkeys(
    keys(local.lx_amis_all),
    keys(local.lx_amis_all),
    split(",", var.tfi_lx_instances)
  )}"

  # which standalone package tests have actually been requested
  lx_ami_requests_pkg = "${matchkeys(
    values(local.lx_amis_pkg),
    keys(local.lx_amis_pkg),
    split(",", var.tfi_lx_instances)
  )}"

  # count of all lx tests requested
  lx_count_all = "${length(local.lx_ami_requests_all)}"

  # only one builder is needed even if there are multiple package test instances
  lx_count_builder = "${length(local.lx_ami_requests_pkg) == 0 ? 0 : 1}"

  lx_builder_ami_key = "lx-builder"

}
