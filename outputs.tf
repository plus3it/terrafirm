output "source_builds" {
  value = local.source_builds
}

output "standalone_builds" {
  value = local.standalone_builds
}

output "win_source_builds" {
  value = local.win_source_builds
}

output "win_standalone_builds" {
  value = local.win_standalone_builds
}

output "win_builder_needed" {
  value = local.win_builder_needed
}

output "win_unique_builds" {
  value = local.win_unique_builds
}

output "lx_source_builds" {
  value = local.lx_source_builds
}

output "lx_standalone_builds" {
  value = local.lx_standalone_builds
}

output "lx_builder_needed" {
  value = local.lx_builder_needed
}

output "lx_unique_builds" {
  value = local.lx_unique_builds
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
