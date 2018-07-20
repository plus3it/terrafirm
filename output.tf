output "build_date_ymd" {
  value = "${local.date_ymd}"
}

output "build_date_hm" {
  value = "${local.date_hm}"
}

output "build_id" {
  value = "${local.build_id}"
}

output "ami-centos6" {
  value = "${data.aws_ami.centos6.id}"
}

output "ami-centos7" {
  value = "${data.aws_ami.centos7.id}"
}

output "ami-rhel6" {
  value = "${data.aws_ami.rhel6.id}"
}

output "ami-rhel7" {
  value = "${data.aws_ami.rhel7.id}"
}

output "ami-win16" {
  value = "${data.aws_ami.win16.id}"
}

output "ami-win12" {
  value = "${data.aws_ami.win12.id}"
}

output "ami-win08" {
  value = "${data.aws_ami.win08.id}"
}

output "winrm_pass" {
  value = "${random_string.password.result}"
}

output "private_key" {
  value = "${tls_private_key.gen_key.private_key_pem}"
}

output "public_key" {
  value = "${tls_private_key.gen_key.public_key_openssh}"
}
