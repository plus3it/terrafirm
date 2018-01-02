provider "aws" {}

resource "aws_key_pair" "auth" {
  key_name   = "${var.key_pair_name}"
  public_key = "${var.public_key}"
}

#resource "template_file" "userdata" {
#  filename = "userdata.ps1"
#}

# Security group to access the instances over WinRM
resource "aws_security_group" "terrafirm" {
  name        = "terrafirm_sg"
  description = "Used in terrafirm"

  # SSH access from anywhere
  ingress {
    from_port   = 5985
    to_port     = 5986
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
  user_data = "${file("userdata2.ps1")}"
  #user_data = "${template_file.userdata.rendered}"
  
  timeouts {
    create = "30m"
    delete = "30m"
  }
  
  connection {
    #winrm connection to tier-2 instance
    type     = "winrm"
    user     = "${var.term_user}"
    password = "${var.term_passwd}"
    timeout   = "10m"
    #https    = true
  }
  
  provisioner "local-exec" {
    command = "sleep 120"
  }
  
  #provisioner "file" {
  #  source = "watchmaker_test.ps1"
  #  destination = "C:/scripts"
  #}
  
  provisioner "remote-exec" {
    #script = "watchmaker_test.ps1"
    inline = [
      "hostname",
      "powershell.exe -ExecutionPolicy Bypass -File watchmaker_test.ps1",
    ]
  }
}
