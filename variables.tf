variable "private_key" {}
variable "public_key" {}
variable "term_user" {}
variable "term_passwd" {}
variable "key_pair_name" {}

output "ip" {
  value = "${aws_instance.windows.public_ip}"
}

output "id" {
  value = "${aws_instance.windows.id}"
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
