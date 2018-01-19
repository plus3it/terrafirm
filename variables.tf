variable "private_key" {}
variable "public_key" {}
variable "term_user" {}
variable "term_passwd" {}
variable "key_pair_name" {}
variable "ssh_user" {}
variable "cb_ip" {}
variable "associate_public_ip_address" {}
variable "win_security_group" {}
variable "lx_security_group" {}
variable "instance_profile" {}
variable "lx_instance_type" {}
variable "win_instance_type" {}

output "iam_thing" {
  value = ["${aws_instance.spels.*.iam_instance_profile}"]
}

output "amicentos6" {
  value = "${data.aws_ami.centos6.id}"
}

output "amicentos7" {
  value = "${data.aws_ami.centos7.id}"
}

output "amirhel6" {
  value = "${data.aws_ami.rhel6.id}"
}

output "amirhel7" {
  value = "${data.aws_ami.rhel7.id}"
}

output "ami2016" {
  value = "${data.aws_ami.windows2016.id}"
}

output "ami2012" {
  value = "${data.aws_ami.windows2012.id}"
}

output "ami2008" {
  value = "${data.aws_ami.windows2008.id}"
}
