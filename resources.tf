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

# instance to build win standalone package
resource "aws_instance" "win_builder" {
  count                       = "${local.win_count_builder}"
  ami                         = "${data.aws_ami.win08.id}"
  instance_type               = "${local.win_builder_instance_type}"
  key_name                    = "${aws_key_pair.auth.id}"
  iam_instance_profile        = "${var.tfi_instance_profile}"
  vpc_security_group_ids      = ["${aws_security_group.winrm_sg.id}"]
  user_data                   = "<powershell>${data.template_file.win_userdata_builder_common.rendered} ${data.template_file.win_userdata_builder_specific.rendered}</powershell>"
  associate_public_ip_address = "${var.tfi_assign_public_ip}"
  subnet_id                   = "${var.tfi_subnet_id}"

  tags {
    Name = "${local.resource_name}-builder"
  }

  timeouts {
    create = "30m"
  }

  connection {
    type     = "winrm"
    user     = "${var.tfi_rm_user}"
    password = "${random_string.password.result}"
    timeout  = "30m"
  }

  provisioner "file" {
    content     = "${data.template_file.win_build_test.rendered}"
    destination = "C:\\scripts\\builder_test.ps1"
  }

  provisioner "remote-exec" {
    inline = [
      "powershell.exe -File C:\\scripts\\builder_test.ps1",
    ]
  }
}

# bread & butter - provision/create windows instance
resource "aws_instance" "win" {
  count                       = "${local.win_count_all_requests}"
  ami                         = "${element(local.win_amis_all_requests, count.index)}"
  instance_type               = "${var.tfi_win_instance_type}"
  key_name                    = "${aws_key_pair.auth.id}"
  iam_instance_profile        = "${var.tfi_instance_profile}"
  vpc_security_group_ids      = ["${aws_security_group.winrm_sg.id}"]
  user_data                   = "<powershell>${element(data.template_file.win_userdata_common.*.rendered, count.index)} ${data.template_file.win_userdata_specific.rendered}</powershell>"
  associate_public_ip_address = "${var.tfi_assign_public_ip}"
  subnet_id                   = "${var.tfi_subnet_id}"

  tags {
    Name = "${local.resource_name}"
  }

  timeouts {
    create = "50m"
  }

  connection {
    type     = "winrm"
    user     = "${var.tfi_rm_user}"
    password = "${random_string.password.result}"
    timeout  = "40m"
  }

  provisioner "file" {
    content     = "${element(data.template_file.win_test.*.rendered, count.index)}"
    destination = "C:\\scripts\\watchmaker_test.ps1"
  }

  provisioner "remote-exec" {
    inline = [
      "powershell.exe -File C:\\scripts\\watchmaker_test.ps1",
    ]
  }
}

# instance to build lx standalone package
resource "aws_instance" "lx_builder" {
  count = "${local.lx_count_builder}"
  ami   = "${data.aws_ami.lx_builder.id}"

  #instance_type               = "${var.tfi_lx_instance_type}"
  instance_type               = "${local.lx_builder_instance_type}"
  iam_instance_profile        = "${var.tfi_instance_profile}"
  key_name                    = "${aws_key_pair.auth.id}"
  vpc_security_group_ids      = ["${aws_security_group.ssh_sg.id}"]
  user_data                   = "${data.template_file.lx_builder_userdata.rendered}"
  user_data                   = "${data.template_file.lx_userdata_builder_common.rendered} ${data.template_file.lx_userdata_builder_specific.rendered}"
  associate_public_ip_address = "${var.tfi_assign_public_ip}"
  subnet_id                   = "${var.tfi_subnet_id}"

  tags {
    Name = "${local.resource_name}-builder"
  }

  timeouts {
    create = "30m"
  }

  connection {
    #ssh connection to tier-2 instance
    user        = "${local.lx_builder_user}"
    private_key = "${tls_private_key.gen_key.private_key_pem}"
    port        = "${local.ssh_port}"
    timeout     = "30m"
  }

  provisioner "file" {
    content     = "${data.template_file.lx_build_test.rendered}"
    destination = "~/builder_test.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x ~/builder_test.sh",
      "~/builder_test.sh",
    ]

    connection {
      # this is where terraform puts the above inline script
      script_path = "~/inline.sh"
    }
  }
}

# bread & butter - this tells TF to provision/create the actual instance
resource "aws_instance" "lx" {
  count                       = "${local.lx_count_all_requests}"
  ami                         = "${element(local.lx_amis_all_requests, count.index)}"
  instance_type               = "${var.tfi_lx_instance_type}"
  iam_instance_profile        = "${var.tfi_instance_profile}"
  key_name                    = "${aws_key_pair.auth.id}"
  vpc_security_group_ids      = ["${aws_security_group.ssh_sg.id}"]
  user_data                   = "${element(data.template_file.lx_userdata.*.rendered, count.index)}"
  user_data                   = "${element(data.template_file.lx_userdata_common.*.rendered, count.index)} ${data.template_file.lx_userdata_specific.rendered}"
  associate_public_ip_address = "${var.tfi_assign_public_ip}"
  subnet_id                   = "${var.tfi_subnet_id}"

  tags {
    Name = "${local.resource_name}"
  }

  timeouts {
    create = "50m"
  }

  connection {
    #ssh connection to tier-2 instance
    user        = "${var.tfi_ssh_user}"
    private_key = "${tls_private_key.gen_key.private_key_pem}"
    port        = "${local.ssh_port}"
    timeout     = "40m"
  }

  provisioner "file" {
    content     = "${element(data.template_file.lx_test.*.rendered, count.index)}"
    destination = "~/watchmaker_test.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x ~/watchmaker_test.sh",
      "~/watchmaker_test.sh",
    ]

    connection {
      # this is where terraform puts the above inline script
      script_path = "~/inline.sh"
    }
  }
}
