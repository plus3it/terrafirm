variable "private_key" {}
variable "public_key" {}
variable "term_user" {}
variable "term_passwd" {}
variable "key_pair_name" {}
variable "ssh_user" {}

output "ipcentos6" {
  value = "${aws_instance.centos6.public_ip}"
}

output "idcentos6" {
  value = "${aws_instance.centos6.id}"
}

output "amicentos6" {
  value = "${data.aws_ami.centos6.id}"
}

output "ipcentos7" {
  value = "${aws_instance.centos7.public_ip}"
}

output "idcentos7" {
  value = "${aws_instance.centos7.id}"
}

output "amicentos7" {
  value = "${data.aws_ami.centos7.id}"
}

output "iprhel6" {
  value = "${aws_instance.rhel6.public_ip}"
}

output "idrhel6" {
  value = "${aws_instance.rhel6.id}"
}

output "amirhel6" {
  value = "${data.aws_ami.rhel6.id}"
}

output "iprhel7" {
  value = "${aws_instance.rhel7.public_ip}"
}

output "idrhel7" {
  value = "${aws_instance.rhel7.id}"
}

output "amirhel7" {
  value = "${data.aws_ami.rhel7.id}"
}

output "ip2016" {
  value = "${aws_instance.windows2016.public_ip}"
}

output "id2016" {
  value = "${aws_instance.windows2016.id}"
}

output "ami2016" {
  value = "${data.aws_ami.windows2016.id}"
}

output "ip2012" {
  value = "${aws_instance.windows2012.public_ip}"
}

output "id2012" {
  value = "${aws_instance.windows2012.id}"
}

output "ami2012" {
  value = "${data.aws_ami.windows2012.id}"
}

output "ip2008" {
  value = "${aws_instance.windows2008.public_ip}"
}

output "id2008" {
  value = "${aws_instance.windows2008.id}"
}

output "ami2008" {
  value = "${data.aws_ami.windows2008.id}"
}
