provider "aws" {}

resource "aws_key_pair" "auth" {
  key_name   = "${var.key_pair_name}"
  public_key = "${var.public_key}"
}

# Security group to access the instances over WinRM
resource "aws_security_group" "terrafirm" {
  name        = "terrafirm_sg"
  description = "Used in terrafirm"

  # SSH access from anywhere
  ingress {
    from_port   = 5985
    to_port     = 5985
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

resource "aws_instance" "windows" {
  ami = "${var.ami}"
  instance_type = "t2.micro"
  key_name = "${aws_key_pair.auth.id}"
  vpc_security_group_ids = ["${aws_security_group.terrafirm.id}"]

  
  timeouts {
    create = "30m"
    delete = "30m"
  }
  
  connection {
    #winrm connection to tier-2 instance
    user     = "${var.ssh_user}"
    timeout   = "3m"
    type     = "winrm"
    https    = true
  }
  
  
  provisioner "remote-exec" {
    #script = "watchmaker_test.bat"
    inline = [
      "Start-Sleep -s 120",
      "watchmaker --version",
    ]
  }
}
