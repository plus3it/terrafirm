# instance to build win standalone package
resource "aws_instance" "win_builder" {
  count = "${local.win_need_builder}"
  ami   = "${lookup(local.ami_ids, lookup(local.ami_underlying, local.win_builder_ami_key))}"

  associate_public_ip_address = "${var.tfi_assign_public_ip}"
  iam_instance_profile        = "${var.tfi_instance_profile}"
  instance_type               = "${local.win_builder_instance_type}"
  key_name                    = "${aws_key_pair.auth.id}"
  subnet_id                   = "${var.tfi_subnet_id}"
  user_data                   = "<powershell>${join("", data.template_file.win_builder_preface.*.rendered)}\n${join("", data.template_file.win_userdata_common.*.rendered)} ${join("", data.template_file.win_userdata_builder_specific.*.rendered)}</powershell>"
  vpc_security_group_ids      = ["${join("", aws_security_group.winrm_sg.*.id)}"]

  tags = {
    Name = "${local.resource_name}-builder"
  }

  timeouts {
    create = "30m"
  }

  connection {
    type     = "winrm"
    user     = "${var.tfi_rm_user}"
    password = "${join("", random_string.password.*.result)}"
    timeout  = "30m"
  }

  provisioner "file" {
    content     = "${join("", data.template_file.win_builder_preface.*.rendered)}\n${join(data.template_file.win_build_test.*.rendered)}"
    destination = "C:\\scripts\\builder_test.ps1"
  }

  provisioner "remote-exec" {
    inline = [
      "powershell.exe -File C:\\scripts\\builder_test.ps1",
    ]
  }
}

# instance to build lx standalone package
resource "aws_instance" "lx_builder" {
  count = "${local.lx_need_builder}"
  ami   = "${lookup(local.ami_ids, lookup(local.ami_underlying, local.lx_builder_ami_key))}"

  associate_public_ip_address = "${var.tfi_assign_public_ip}"
  iam_instance_profile        = "${var.tfi_instance_profile}"
  instance_type               = "${local.lx_builder_instance_type}"
  key_name                    = "${aws_key_pair.auth.id}"
  subnet_id                   = "${var.tfi_subnet_id}"
  user_data                   = "${join("", data.template_file.lx_builder_preface.*.rendered)}\n${join("", data.template_file.lx_userdata_common.*.rendered)}\n${join("", data.template_file.lx_userdata_builder_specific.*.rendered)}"
  vpc_security_group_ids      = ["${join("", aws_security_group.ssh_sg.*.id)}"]

  tags = {
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
    content     = "${join("", data.template_file.lx_builder_preface.*.rendered)}\n${join("", data.template_file.lx_build_test.*.rendered)}"
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

# bread & butter - provision/create windows instance
resource "aws_instance" "win" {
  count = "${local.win_request_count}"
  ami   = "${lookup(local.ami_ids, lookup(local.ami_underlying, element(local.win_requests, count.index)))}"

  associate_public_ip_address = "${var.tfi_assign_public_ip}"
  iam_instance_profile        = "${var.tfi_instance_profile}"
  instance_type               = "${var.tfi_win_instance_type}"
  key_name                    = "${aws_key_pair.auth.id}"
  subnet_id                   = "${var.tfi_subnet_id}"
  user_data                   = "<powershell>${element(data.template_file.win_script_preface.*.rendered, count.index)}\n${join("", data.template_file.win_userdata_common.*.rendered)} ${join("", data.template_file.win_userdata_specific.*.rendered)}</powershell>"
  vpc_security_group_ids      = ["${join("", aws_security_group.winrm_sg.*.id)}"]

  tags = {
    Name = "${local.resource_name}"
  }

  timeouts {
    create = "50m"
  }

  connection {
    type     = "winrm"
    user     = "${var.tfi_rm_user}"
    password = "${join("", random_string.password.*.result)}"
    timeout  = "40m"
  }

  provisioner "file" {
    content     = "${element(data.template_file.win_script_preface.*.rendered, count.index)}\n${join("", data.template_file.win_test.*.rendered)}"
    destination = "C:\\scripts\\watchmaker_test.ps1"
  }

  provisioner "remote-exec" {
    inline = [
      "powershell.exe -File C:\\scripts\\watchmaker_test.ps1",
    ]
  }
}

# bread & butter - this tells TF to provision/create the actual instance
resource "aws_instance" "lx" {
  count = "${local.lx_request_count}"
  ami   = "${lookup(local.ami_ids, lookup(local.ami_underlying, element(local.lx_requests, count.index)))}"

  associate_public_ip_address = "${var.tfi_assign_public_ip}"
  iam_instance_profile        = "${var.tfi_instance_profile}"
  instance_type               = "${var.tfi_lx_instance_type}"
  key_name                    = "${aws_key_pair.auth.id}"
  subnet_id                   = "${var.tfi_subnet_id}"
  user_data                   = "${element(data.template_file.lx_script_preface.*.rendered, count.index)}\n${join("", data.template_file.lx_userdata_common.*.rendered)}\n${join("", data.template_file.lx_userdata_specific.*.rendered)}"
  vpc_security_group_ids      = ["${join("", aws_security_group.ssh_sg.*.id)}"]

  tags = {
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
    content     = "${element(data.template_file.lx_script_preface.*.rendered, count.index)}\n${join("", data.template_file.lx_test.*.rendered)}"
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
