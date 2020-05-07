output "build_date_ymd" {
  value = local.date_ymd
}

output "build_date_hm" {
  value = local.date_hm
}

output "build_id" {
  value = local.build_id
}

output "winrm_pass" {
  value = join("", random_string.password.*.result)
}

output "private_key" {
  value = tls_private_key.gen_key.private_key_pem
}

output "public_key" {
  value = tls_private_key.gen_key.public_key_openssh
}

output "build_slug" {
  value = local.build_slug
}

output "ami_ids" {
  value = local.ami_ids
}

output "user_requests" {
  value = local.user_requests
}

output "win_src_requests" {
  value = local.win_src_requests
}

output "lx_src_requests" {
  value = local.lx_src_requests
}

output "win_pkg_requests" {
  value = local.win_pkg_requests
}

output "lx_pkg_requests" {
  value = local.lx_pkg_requests
}

output "win_src_count" {
  value = local.win_src_count
}

output "lx_src_count" {
  value = local.lx_src_count
}

output "win_pkg_count" {
  value = local.win_pkg_count
}

output "lx_pkg_count" {
  value = local.lx_pkg_count
}

output "win_any" {
  value = local.win_any
}

output "lx_any" {
  value = local.lx_any
}

output "win_need_builder" {
  value = local.win_need_builder
}

output "lx_need_builder" {
  value = local.lx_need_builder
}

output "win_builder_list" {
  value = local.win_builder_list
}

output "lx_builder_list" {
  value = local.lx_builder_list
}

output "amis_to_search" {
  value = local.amis_to_search
}

output "ami_filters_to_search" {
  value = local.ami_filters_to_search
}

output "ami_regexes_to_search" {
  value = local.ami_regexes_to_search
}

output "ami_underlying" {
  value = local.ami_underlying
}
