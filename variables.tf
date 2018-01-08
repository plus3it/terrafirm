variable "private_key" {}
variable "public_key" {}
variable "term_user" {}
variable "term_passwd" {}
variable "key_pair_name" {}
variable "ssh_user" {}
variable "ssh_user_fedora" {}
variable "cb_ip" {}

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
