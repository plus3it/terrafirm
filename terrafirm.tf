provider "aws" {}

resource "aws_key_pair" "auth" {
  key_name   = "${var.key_pair_name}"
  public_key = "${var.public_key}"
}

# Security group to access the instances over SSH
resource "aws_security_group" "terrafirm" {
  name        = "terrafirm_sg"
  description = "Used in terrafirm"

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "centos" {
  ami = "${var.ami}"
  #ami = "ami-658ce61f" #spel-minimal-centos-6.9-hvm-2017.12.1.x86_64-gp2
  #ami = "ami-55ef662f"  #amazon linux 2017.09.1
  instance_type = "t2.micro"
  key_name = "${aws_key_pair.auth.id}"
  vpc_security_group_ids = ["${aws_security_group.terrafirm.id}"]
  #subnet_id = "${aws_subnet.default.id}"
  user_data = <<USERDATA
#!/bin/sh
PIP_URL=https://bootstrap.pypa.io/get-pip.py
PYPI_URL=https://pypi.org/simple

# Install pip
curl "$PIP_URL" | python - --index-url="$PYPI_URL" wheel==0.29.0

# Install watchmaker
pip install --index-url="$PYPI_URL" --upgrade pip setuptools watchmaker

# Run watchmaker
/usr/local/bin/watchmaker -n --log-level debug --log-dir=/var/log/watchmaker
USERDATA
  
  timeouts {
    create = "30m"
    delete = "30m"
  }
  
  connection {
    #ssh connection to tier-2 instance
    user     = "${var.ssh_user}"
    private_key = "${var.private_key}"
    timeout   = "3m"
  }
  
  
  provisioner "remote-exec" {
    script = "watchmaker.sh"
    #inline = [
    #  "sleep 120",
    #  "/usr/bin/watchmaker --version",
    #]
  }
}
