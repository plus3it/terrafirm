locals {
  # Name, name tag, log name related locals
  name_prefix   = "terrafirm"
  date_ymd      = "${substr(data.null_data_source.start_time.inputs.tfi_timestamp,0,4)}${substr(data.null_data_source.start_time.inputs.tfi_timestamp,5,2)}${substr(data.null_data_source.start_time.inputs.tfi_timestamp,8,2)}" #equivalent of $(date +'%Y%m%d')
  date_hm       = "${substr(data.null_data_source.start_time.inputs.tfi_timestamp,11,2)}${substr(data.null_data_source.start_time.inputs.tfi_timestamp,14,2)}"                                                                   #equivalent of $(date +'%H%M')
  full_build_id = "${var.tfi_codebuild_id == "" ? format("notcb:%s", uuid()) : var.tfi_codebuild_id}"                                                                                                                            #128-bit rfc 4122 v4 UUID
  build_id      = "${substr(element(split(":",local.full_build_id),1), 0, 8)}${substr(element(split(":",local.full_build_id),1), 9, 4)}"                                                                                         #extract node portion of uuid (last 6 octets) for brevity
  resource_name = "${local.name_prefix}-${local.build_id}"

  default_subnet = "${aws_default_subnet.tfi.id}"
}

# place to put the ami id strings
locals {
  lx_amis = {
    "centos6" = "${data.aws_ami.centos6.id}"
    "centos7" = "${data.aws_ami.centos7.id}"
    "rhel6"   = "${data.aws_ami.rhel6.id}"
    "rhel7"   = "${data.aws_ami.rhel7.id}"
  }

  win_amis = {
    "win08"       = "${data.aws_ami.windows2008.id}"
    "win12"       = "${data.aws_ami.windows2012.id}"
    "win16"       = "${data.aws_ami.windows2016.id}"
    "win16sql16s" = "${data.aws_ami.win16sql16s.id}"
    "win16sql16e" = "${data.aws_ami.win16sql16e.id}"
    "win16sql17s" = "${data.aws_ami.win16sql17s.id}"
    "win16sql17e" = "${data.aws_ami.win16sql17e.id}"
  }
}
