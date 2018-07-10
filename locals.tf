locals {
  # Name, name tag, log name related locals
  name_prefix   = "terrafirm"
  date_ymd      = "${substr(data.null_data_source.start_time.inputs.tfi_timestamp,0,4)}${substr(data.null_data_source.start_time.inputs.tfi_timestamp,5,2)}${substr(data.null_data_source.start_time.inputs.tfi_timestamp,8,2)}" #equivalent of $(date +'%Y%m%d')
  date_hm       = "${substr(data.null_data_source.start_time.inputs.tfi_timestamp,11,2)}${substr(data.null_data_source.start_time.inputs.tfi_timestamp,14,2)}"                                                                   #equivalent of $(date +'%H%M')
  full_build_id = "${var.tfi_codebuild_id == "" ? format("notcb:%s", uuid()) : var.tfi_codebuild_id}"                                                                                                                            #128-bit rfc 4122 v4 UUID
  build_id      = "${substr(element(split(":",local.full_build_id),1), 0, 8)}${substr(element(split(":",local.full_build_id),1), 9, 4)}"                                                                                         #extract node portion of uuid (last 6 octets) for brevity
  resource_name = "${local.name_prefix}-${local.build_id}"
}

# place to put the ami id strings
locals {
  #lx_amis = {  #  "centos6"    = "${data.aws_ami.centos6.id}"  #  "centos7"    = "${data.aws_ami.centos7.id}"  #  "rhel6"      = "${data.aws_ami.rhel6.id}"  #  "rhel7"      = "${data.aws_ami.rhel7.id}"  #  "centos6pkg" = "${data.aws_ami.centos6.id}"  #  "centos7pkg" = "${data.aws_ami.centos7.id}"  #  "rhel6pkg"   = "${data.aws_ami.rhel6.id}"  #  "rhel7pkg"   = "${data.aws_ami.rhel7.id}"  #}

  win_amis = {
    "win08"       = "${data.aws_ami.windows2008.id}"
    "win12"       = "${data.aws_ami.windows2012.id}"
    "win16"       = "${data.aws_ami.windows2016.id}"
    "win16sql16s" = "${data.aws_ami.win16sql16s.id}"
    "win16sql16e" = "${data.aws_ami.win16sql16e.id}"
    "win16sql17s" = "${data.aws_ami.win16sql17s.id}"
    "win16sql17e" = "${data.aws_ami.win16sql17e.id}"
    "win08pkg"    = "${data.aws_ami.windows2008.id}"
    "win12pkg"    = "${data.aws_ami.windows2012.id}"
    "win16pkg"    = "${data.aws_ami.windows2016.id}"
  }
}

# linux goodness
locals {
  #the one place where linux ami key strings are defined
  lx_ami_keys_all = "${split(",","centos6,centos7,rhel6,rhel7,centos6pkg,centos7pkg,rhel6pkg,rhel7pkg")}"

  lx_amis = {
    "${local.lx_ami_keys_all[0]}" = "${data.aws_ami.centos6.id}"
    "${local.lx_ami_keys_all[1]}" = "${data.aws_ami.centos7.id}"
    "${local.lx_ami_keys_all[2]}" = "${data.aws_ami.rhel6.id}"
    "${local.lx_ami_keys_all[3]}" = "${data.aws_ami.rhel7.id}"
  }

  lx_amis_pkg = {
    "${local.lx_ami_keys_all[4]}" = "${lookup(local.lx_amis,local.lx_ami_keys_all[0])}"
    "${local.lx_ami_keys_all[5]}" = "${lookup(local.lx_amis,local.lx_ami_keys_all[1])}"
    "${local.lx_ami_keys_all[6]}" = "${lookup(local.lx_amis,local.lx_ami_keys_all[2])}"
    "${local.lx_ami_keys_all[7]}" = "${lookup(local.lx_amis,local.lx_ami_keys_all[3])}"
  }

  lx_amis_all = "${merge(local.lx_amis, local.lx_amis_pkg)}"

  lx_ami_requests_all = "${matchkeys(
    values(local.lx_amis_all),
    keys(local.lx_amis_all),
    split(",", var.tfi_lx_instances)
  )}"

  lx_key_requests_all = "${matchkeys(
    keys(local.lx_amis_all),
    keys(local.lx_amis_all),
    split(",", var.tfi_lx_instances)
  )}"

  lx_ami_requests_pkg = "${matchkeys(
    values(local.lx_amis_pkg),
    keys(local.lx_amis_pkg),
    split(",", var.tfi_lx_instances)
  )}"

  lx_count_all = "${length(local.lx_ami_requests_all)}"

  # only one builder is needed even if there are multiple package test instances
  lx_count_pkg = "${length(local.lx_ami_requests_pkg) == 0 ? 0 : 1}"

  lx_ami_builder_pkg = "${lookup(local.lx_amis,local.lx_ami_keys_all[1])}"
}
