variable "private_key" {}
variable "public_key" {}
variable "ami" {}
variable "term_user" {}
variable "term_passwd" {}
variable "key_pair_name" {}

output "ip" {
  value = "${aws_instance.windows.public_ip}"
}

output "id" {
  value = "${aws_instance.windows.id}"
}
