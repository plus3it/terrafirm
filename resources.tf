#used for importing the key pair created using aws cli
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
  length           = 18
  special          = true
  override_special = "()~!@#^&*+=|{}[]:;<>,?"
}

resource "aws_default_subnet" "tfi" {
  availability_zone = "${var.tfi_availability_zone}"
}

# Security group to access the instances over WinRM
resource "aws_security_group" "winrm_sg" {
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
  name        = "${local.resource_name}-ssh"
  description = "Used in terrafirm"
  vpc_id      = "${data.aws_subnet.tfi.vpc_id}"

  tags {
    Name = "${local.resource_name}"
  }

  # Non-standard port SSH access 
  ingress {
    from_port   = 122
    to_port     = 122
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

# bread & butter - this tells TF to provision/create the actual instance
resource "aws_instance" "spels" {
  count                       = "${length(matchkeys(values(local.lx_amis),keys(local.lx_amis),split(",", var.tfi_lx_instances)))}"
  ami                         = "${element(matchkeys(values(local.lx_amis),keys(local.lx_amis),split(",", var.tfi_lx_instances)), count.index)}"
  instance_type               = "${var.tfi_lx_instance_type}"
  iam_instance_profile        = "${var.tfi_instance_profile}"
  key_name                    = "${aws_key_pair.auth.id}"
  vpc_security_group_ids      = ["${aws_security_group.ssh_sg.id}"]
  user_data                   = "${data.template_file.lx_userdata.rendered}"
  associate_public_ip_address = "${var.tfi_assign_public_ip}"
  subnet_id                   = "${var.tfi_subnet_id}"

  tags {
    Name = "${local.resource_name}"
  }

  timeouts {
    create = "30m"
    delete = "30m"
  }

  connection {
    #ssh connection to tier-2 instance
    user        = "${var.tfi_ssh_user}"
    private_key = "${tls_private_key.gen_key.private_key_pem}"
    port        = 122
    timeout     = "20m"
  }

  provisioner "file" {
    source      = "linux/watchmaker_test.sh"
    destination = "~/watchmaker_test.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x ~/watchmaker_test.sh",
      "~/watchmaker_test.sh",
    ]

    connection {
      script_path = "~/inline.sh"
    }
  }
}

# bread & butter - this tells TF to provision/create the actual instance
resource "aws_instance" "windows" {
  count                       = "${length(matchkeys(values(local.win_amis),keys(local.win_amis),split(",", var.tfi_win_instances)))}"
  ami                         = "${element(matchkeys(values(local.win_amis),keys(local.win_amis),split(",", var.tfi_win_instances)), count.index)}"
  instance_type               = "${var.tfi_win_instance_type}"
  key_name                    = "${aws_key_pair.auth.id}"
  iam_instance_profile        = "${var.tfi_instance_profile}"
  vpc_security_group_ids      = ["${aws_security_group.winrm_sg.id}"]
  user_data                   = "${data.template_file.win_userdata.rendered}"
  associate_public_ip_address = "${var.tfi_assign_public_ip}"
  subnet_id                   = "${var.tfi_subnet_id}"

  tags {
    Name = "${local.resource_name}"
  }

  timeouts {
    create = "30m"
    delete = "30m"
  }

  connection {
    type     = "winrm"
    user     = "${var.tfi_rm_user}"
    password = "${random_string.password.result}"
    timeout  = "20m"
  }

  provisioner "file" {
    source      = "windows/watchmaker_test.ps1"
    destination = "C:\\scripts\\watchmaker_test.ps1"
  }

  provisioner "remote-exec" {
    inline = [
      "powershell.exe -File C:\\scripts\\watchmaker_test.ps1",
    ]
  }
}
