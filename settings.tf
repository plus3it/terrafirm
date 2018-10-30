# various settings used by the instances
locals {
  lx_builder_instance_type  = "${length(local.lx_pkg_requests) > 2 ? "t2.xlarge" : "t2.medium"}"
  lx_builder_user           = "ubuntu"
  lx_error_signal_file      = "${local.release_prefix}/lx_error.log"
  lx_executable             = "${local.release_prefix}/latest/watchmaker-latest-standalone-linux-x86_64"
  lx_temp_dir               = "/tmp"
  lx_userdata_status_file   = "${local.lx_temp_dir}/userdata_status"
  pip_bootstrap_url         = "https://bootstrap.pypa.io/get-pip.py"
  pypi_url                  = "https://pypi.org/simple"
  release_prefix            = "release"
  ssh_port                  = 122
  win_7zip_url              = "https://www.7-zip.org/a/7z1805-x64.exe"
  win_bootstrap_url         = "https://raw.githubusercontent.com/plus3it/watchmaker/develop/docs/files/bootstrap/watchmaker-bootstrap.ps1"
  win_builder_instance_type = "${length(local.win_pkg_requests) > 2 ? "t2.large" : var.tfi_win_instance_type}"
  win_download_dir          = "C:\\Users\\Administrator\\Downloads"
  win_error_signal_file     = "${local.release_prefix}/win_error.log"
  win_executable            = "${local.release_prefix}/latest/watchmaker-latest-standalone-windows-amd64.exe"
  win_git_url               = "https://github.com/git-for-windows/git/releases/download/v2.18.0.windows.1/Git-2.18.0-64-bit.exe"
  win_python_url            = "https://www.python.org/ftp/python/3.6.6/python-3.6.6-amd64.exe"
  win_temp_dir              = "C:\\Temp"
  win_userdata_status_file  = "${local.win_temp_dir}\\userdata_status"
}

# build settings
locals {
  name_prefix   = "terrafirm"
  date_ymd      = "${substr(data.null_data_source.start_time.inputs.tfi_timestamp,0,4)}${substr(data.null_data_source.start_time.inputs.tfi_timestamp,5,2)}${substr(data.null_data_source.start_time.inputs.tfi_timestamp,8,2)}" #equivalent of $(date +'%Y%m%d')
  date_hm       = "${substr(data.null_data_source.start_time.inputs.tfi_timestamp,11,2)}${substr(data.null_data_source.start_time.inputs.tfi_timestamp,14,2)}"                                                                   #equivalent of $(date +'%H%M')
  full_build_id = "${var.tfi_codebuild_id == "" ? format("notcb:%s", uuid()) : var.tfi_codebuild_id}"                                                                                                                            #128-bit rfc 4122 v4 UUID
  build_id      = "${substr(element(split(":",local.full_build_id),1), 0, 8)}${substr(element(split(":",local.full_build_id),1), 9, 4)}"                                                                                         #extract node portion of uuid (last 6 octets) for brevity
  resource_name = "${local.name_prefix}-${local.build_id}"
  build_slug    = "${var.tfi_s3_bucket}/${local.date_ymd}/${local.date_hm}-${local.build_id}"
}

# Synchronize your watches
data "null_data_source" "start_time" {
  inputs = {
    # necessary because if you just call timestamp in a local it re-evaluates it everytime that var is read
    tfi_timestamp = "${timestamp()}"
  }
}
