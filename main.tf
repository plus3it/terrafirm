# instance to build win standalone package
resource "aws_instance" "win_builder" {
  count = local.win_need_builder
  ami   = local.ami_ids[local.ami_underlying[local.win_builder_ami_key]]

  associate_public_ip_address = var.tfi_assign_public_ip
  iam_instance_profile        = var.tfi_instance_profile
  instance_type               = local.win_builder_instance_type
  key_name                    = aws_key_pair.auth.id
  subnet_id                   = var.tfi_subnet_id
  user_data                   = <<-HEREDOC
    <powershell>
    ${join("", data.template_file.win_builder_preface.*.rendered)}
    ${join("", data.template_file.win_userdata_common.*.rendered)} ${join("", data.template_file.win_userdata_builder_specific.*.rendered)}
    </powershell>
    HEREDOC
  vpc_security_group_ids      = [join("", aws_security_group.winrm_sg.*.id)]

  tags = {
    Name = "${local.resource_name}-builder-${local.ami_underlying[local.win_builder_ami_key]}"
  }

  timeouts {
    create = "30m"
  }

  connection {
    type     = "winrm"
    host     = self.public_ip
    user     = var.tfi_rm_user
    password = join("", random_string.password.*.result)
    timeout  = "30m"
  }

  provisioner "file" {
    content     = <<-HEREDOC
      ${join("", data.template_file.win_builder_preface.*.rendered)}
      ${join("", data.template_file.win_build_test.*.rendered)}
      HEREDOC
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
  count = local.lx_need_builder
  ami   = local.ami_ids[local.ami_underlying[local.lx_builder_ami_key]]

  associate_public_ip_address = var.tfi_assign_public_ip
  iam_instance_profile        = var.tfi_instance_profile
  instance_type               = local.lx_builder_instance_type
  key_name                    = aws_key_pair.auth.id
  subnet_id                   = var.tfi_subnet_id
  user_data                   = <<-HEREDOC
    ${join("", data.template_file.lx_builder_preface.*.rendered)}
    ${join("", data.template_file.lx_userdata_common.*.rendered)}
    ${join("", data.template_file.lx_userdata_builder_specific.*.rendered)}
    HEREDOC
  vpc_security_group_ids      = [join("", aws_security_group.ssh_sg.*.id)]

  tags = {
    Name = "${local.resource_name}-builder-${local.ami_underlying[local.lx_builder_ami_key]}"
  }

  timeouts {
    create = "30m"
  }

  connection {
    type = "ssh"
    #ssh connection to tier-2 instance
    host        = self.public_ip
    user        = local.lx_builder_user
    private_key = tls_private_key.gen_key.private_key_pem
    port        = local.ssh_port
    timeout     = "30m"
  }

  provisioner "file" {
    content     = <<-HEREDOC
      ${join("", data.template_file.lx_builder_preface.*.rendered)}
      ${join("", data.template_file.lx_build_test.*.rendered)}
      HEREDOC
    destination = "~/builder_test.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x ~/builder_test.sh",
      "~/builder_test.sh",
    ]

    connection {
      host = coalesce(self.public_ip, self.private_ip)
      type = "ssh"
      # this is where terraform puts the above inline script
      script_path = "~/inline.sh"
    }
  }
}

# bread & butter - provision/create windows instance
resource "aws_instance" "win_src" {
  count = local.win_src_count
  ami   = local.ami_ids[element(local.win_src_requests, count.index)]

  associate_public_ip_address = var.tfi_assign_public_ip
  iam_instance_profile        = var.tfi_instance_profile
  instance_type               = var.tfi_win_instance_type
  key_name                    = aws_key_pair.auth.id
  subnet_id                   = var.tfi_subnet_id
  user_data                   = <<-HEREDOC
    <powershell>
    ${element(data.template_file.win_src_script_preface.*.rendered, count.index)}
    ${join("", data.template_file.win_userdata_common.*.rendered)} ${join("", data.template_file.win_userdata_specific.*.rendered)}
    </powershell>
    HEREDOC
  vpc_security_group_ids      = [join("", aws_security_group.winrm_sg.*.id)]

  tags = {
    Name = "${local.resource_name}-${element(local.win_src_requests, count.index)}-from_source"
  }

  timeouts {
    create = "85m"
  }

  connection {
    type     = "winrm"
    host     = self.public_ip
    user     = var.tfi_rm_user
    password = join("", random_string.password.*.result)
    timeout  = "75m"
  }

  provisioner "file" {
    content     = <<-HEREDOC
      ${element(data.template_file.win_src_script_preface.*.rendered, count.index)}
      ${join("", data.template_file.win_test.*.rendered)}
      HEREDOC
    destination = "C:\\scripts\\watchmaker-test-${element(local.win_src_requests, count.index)}.ps1"
  }

  provisioner "remote-exec" {
    inline = [
      "powershell.exe -File C:\\scripts\\watchmaker-test-${element(local.win_src_requests, count.index)}.ps1",
    ]

    connection {
      host = coalesce(self.public_ip, self.private_ip)
      type = "winrm"
      # this is where terraform puts the above inline script
      script_path = "C:\\scripts\\inline-${element(local.win_src_requests, count.index)}-from-source.cmd"
    }
  }
}

# bread & butter - provision/create windows instance
resource "aws_instance" "win_pkg" {
  count = local.win_pkg_count
  ami   = local.ami_ids[local.ami_underlying[element(local.win_pkg_requests, count.index)]]

  associate_public_ip_address = var.tfi_assign_public_ip
  iam_instance_profile        = var.tfi_instance_profile
  instance_type               = var.tfi_win_instance_type
  key_name                    = aws_key_pair.auth.id
  subnet_id                   = var.tfi_subnet_id
  user_data                   = <<-HEREDOC
    <powershell>
    ${element(data.template_file.win_pkg_script_preface.*.rendered, count.index)}
    ${join("", data.template_file.win_userdata_common.*.rendered)} ${join("", data.template_file.win_userdata_specific.*.rendered)}
    </powershell>
    HEREDOC
  vpc_security_group_ids      = [join("", aws_security_group.winrm_sg.*.id)]

  tags = {
    Name = "${local.resource_name}-${element(local.win_pkg_requests, count.index)}-${join("", aws_instance.win_builder.*.id)}(builder id)"
  }

  timeouts {
    create = "85m"
  }

  connection {
    type     = "winrm"
    host     = self.public_ip
    user     = var.tfi_rm_user
    password = join("", random_string.password.*.result)
    timeout  = "75m"
  }

  provisioner "file" {
    content     = <<-HEREDOC
      ${element(data.template_file.win_pkg_script_preface.*.rendered, count.index)}
      ${join("", data.template_file.win_test.*.rendered)}
      HEREDOC
    destination = "C:\\scripts\\watchmaker-test-${element(local.win_pkg_requests, count.index)}.ps1"
  }

  provisioner "remote-exec" {
    inline = [
      "powershell.exe -File C:\\scripts\\watchmaker-test-${element(local.win_pkg_requests, count.index)}.ps1",
    ]

    connection {
      host = coalesce(self.public_ip, self.private_ip)
      type = "winrm"
      # this is where terraform puts the above inline script
      script_path = "C:\\scripts\\inline-${element(local.win_pkg_requests, count.index)}.cmd"
    }
  }
}

# bread & butter - this tells TF to provision/create the actual instance
resource "aws_instance" "lx_src" {
  count = local.lx_src_count
  ami   = local.ami_ids[element(local.lx_src_requests, count.index)]

  associate_public_ip_address = var.tfi_assign_public_ip
  iam_instance_profile        = var.tfi_instance_profile
  instance_type               = var.tfi_lx_instance_type
  key_name                    = aws_key_pair.auth.id
  subnet_id                   = var.tfi_subnet_id
  user_data                   = <<-HEREDOC
    ${element(data.template_file.lx_src_script_preface.*.rendered, count.index)}
    ${join("", data.template_file.lx_userdata_common.*.rendered)}
    ${join("", data.template_file.lx_userdata_specific.*.rendered)}
    HEREDOC
  vpc_security_group_ids      = [join("", aws_security_group.ssh_sg.*.id)]

  tags = {
    Name = "${local.resource_name}-${element(local.lx_src_requests, count.index)}-from_source"
  }

  timeouts {
    create = "50m"
  }

  connection {
    type = "ssh"
    #ssh connection to tier-2 instance
    host        = self.public_ip
    user        = var.tfi_ssh_user
    private_key = tls_private_key.gen_key.private_key_pem
    port        = local.ssh_port
    timeout     = "40m"
  }

  provisioner "file" {
    content     = <<-HEREDOC
      ${element(data.template_file.lx_src_script_preface.*.rendered, count.index)}
      ${join("", data.template_file.lx_test.*.rendered)}
      HEREDOC
    destination = "~/watchmaker-test-${element(local.lx_src_requests, count.index)}.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x ~/watchmaker-test-${element(local.lx_src_requests, count.index)}.sh",
      "~/watchmaker-test-${element(local.lx_src_requests, count.index)}.sh",
    ]

    connection {
      host = coalesce(self.public_ip, self.private_ip)
      type = "ssh"
      # this is where terraform puts the above inline script
      script_path = "~/inline-${element(local.lx_src_requests, count.index)}-from-source.sh"
    }
  }
}

resource "aws_instance" "lx_pkg" {
  count = local.lx_pkg_count
  ami   = local.ami_ids[local.ami_underlying[element(local.lx_pkg_requests, count.index)]]

  associate_public_ip_address = var.tfi_assign_public_ip
  iam_instance_profile        = var.tfi_instance_profile
  instance_type               = var.tfi_lx_instance_type
  key_name                    = aws_key_pair.auth.id
  subnet_id                   = var.tfi_subnet_id
  user_data                   = <<-HEREDOC
    ${element(data.template_file.lx_pkg_script_preface.*.rendered, count.index)}
    ${join("", data.template_file.lx_userdata_common.*.rendered)}
    ${join("", data.template_file.lx_userdata_specific.*.rendered)}
    HEREDOC
  vpc_security_group_ids      = [join("", aws_security_group.ssh_sg.*.id)]

  tags = {
    Name = "${local.resource_name}-${element(local.lx_pkg_requests, count.index)}-${join("", aws_instance.lx_builder.*.id)}(builder id)"
  }

  timeouts {
    create = "50m"
  }

  connection {
    type = "ssh"
    #ssh connection to tier-2 instance
    host        = self.public_ip
    user        = var.tfi_ssh_user
    private_key = tls_private_key.gen_key.private_key_pem
    port        = local.ssh_port
    timeout     = "40m"
  }

  provisioner "file" {
    content     = <<-HEREDOC
      ${element(data.template_file.lx_pkg_script_preface.*.rendered, count.index)}
      ${join("", data.template_file.lx_test.*.rendered)}
      HEREDOC
    destination = "~/watchmaker-test-${element(local.lx_pkg_requests, count.index)}.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x ~/watchmaker-test-${element(local.lx_pkg_requests, count.index)}.sh",
      "~/watchmaker-test-${element(local.lx_pkg_requests, count.index)}.sh",
    ]

    connection {
      host = coalesce(self.public_ip, self.private_ip)
      type = "ssh"
      # this is where terraform puts the above inline script
      script_path = "~/inline-${element(local.lx_pkg_requests, count.index)}.sh"
    }
  }
}
