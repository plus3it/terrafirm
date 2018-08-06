output "build_date_ymd" {
  value = "${local.date_ymd}"
}

output "build_date_hm" {
  value = "${local.date_hm}"
}

output "build_id" {
  value = "${local.build_id}"
}

output "ami_ids" {
  value = "${local.ami_ids}"
}

output "winrm_pass" {
  value = "${random_string.password.*.result}"
}

output "private_key" {
  value = "${tls_private_key.gen_key.private_key_pem}"
}

output "public_key" {
  value = "${tls_private_key.gen_key.public_key_openssh}"
}

output "build_slug" {
  value = "${local.build_slug}"
}
