
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

output "amiwin16sql16s" {
  value = "${data.aws_ami.win16sql16s.id}"
}

output "amiwin16sql16e" {
  value = "${data.aws_ami.win16sql16e.id}"
}

output "amiwin16sql17s" {
  value = "${data.aws_ami.win16sql17s.id}"
}

output "amiwin16sql17e" {
  value = "${data.aws_ami.win16sql17e.id}"
}
