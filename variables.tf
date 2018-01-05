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
