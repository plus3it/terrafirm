# security and networking

# Subnet for instances
data "aws_subnet" "tfi" {
  id = "${var.tfi_subnet_id == "" ? aws_default_subnet.tfi.id : var.tfi_subnet_id}"
}

# Used to get local ip for security group ingress
data "http" "ip" {
  url = "http://ipv4.icanhazip.com"
}

# used for importing the key pair created using aws cli
resource "aws_key_pair" "auth" {
  key_name   = "${local.resource_name}-key"
  public_key = "${tls_private_key.gen_key.public_key_openssh}"
}

resource "tls_private_key" "gen_key" {
  count     = "1"
  algorithm = "RSA"
  rsa_bits  = "4096"
}

resource "random_string" "password" {
  count            = "${local.win_request_any_count}"
  length           = 18
  special          = true
  override_special = "()~!@#^&*+=|{}[]:;<>,?"
}

resource "aws_default_subnet" "tfi" {
  availability_zone = "${var.tfi_availability_zone}"
}

# Security group to access the instances over WinRM
resource "aws_security_group" "winrm_sg" {
  count       = "${local.win_request_any_count}"
  name        = "${local.resource_name}-winrm"
  description = "Used in terrafirm"
  vpc_id      = "${data.aws_subnet.tfi.vpc_id}"

  tags {
    Name = "${local.resource_name}"
  }

  # SSH access from anywhere
  ingress {
    from_port   = 5985
    to_port     = 5986
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.ip.body)}/32"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security group to access the instances over SSH
resource "aws_security_group" "ssh_sg" {
  count       = "${local.lx_request_any_count}" # only create if any lx instances
  name        = "${local.resource_name}-ssh"
  description = "Used in terrafirm"
  vpc_id      = "${data.aws_subnet.tfi.vpc_id}"

  tags {
    Name = "${local.resource_name}"
  }

  # Non-standard port SSH access
  ingress {
    from_port   = "${local.ssh_port}"
    to_port     = "${local.ssh_port}"
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.ip.body)}/32"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
