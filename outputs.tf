output "user_requests" {
  value = local.user_requests
}

output "win_src_requests" {
  value = local.win_src_requests
}

output "win_sa_requests" {
  value = local.win_sa_requests
}

output "win_builder_request" {
  value = local.win_builder_request
}

output "win_all_requests" {
  value = local.win_all_requests
}

output "lx_src_requests" {
  value = local.lx_src_requests
}

output "lx_sa_requests" {
  value = local.lx_sa_requests
}

output "lx_src_expanded" {
  value = toset(local.lx_src_expanded)
}

output "lx_sa_expanded" {
  value = toset(local.lx_sa_expanded)
}

output "lx_builder_request" {
  value = local.lx_builder_request
}

output "lx_all_requests" {
  value = local.lx_all_requests
}

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
