output "builders" {
  value = local.builders
}

output "standalone_builds" {
  value = var.standalone_builds
}

output "source_builds" {
  value = var.source_builds
}

output "unique_builds_needed" {
  value = local.unique_builds_needed
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
  value     = local.platform_info.win.connection_password
  sensitive = true
}

output "private_key" {
  value     = tls_private_key.gen_key.private_key_pem
  sensitive = true
}

output "public_key" {
  value = tls_private_key.gen_key.public_key_openssh
}

output "build_slug" {
  value = local.build_slug
}
