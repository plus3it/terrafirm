locals {
  ami_filter_name                  = "name"
  ami_filter_virtualization_type   = "virtualization-type"
  ami_most_recent                  = true
  ami_owners                       = ["701759196663", "099720109477", "801119661308"]
  ami_virtualization_type          = "hvm"
  aws_region                       = var.aws_region
  bootstrap_url                    = "https://raw.githubusercontent.com/plus3it/watchmaker/develop/docs/files/bootstrap/watchmaker-bootstrap.ps1"
  build_id                         = "${substr(element(split(":", local.full_build_id), 1), 0, 8)}${substr(element(split(":", local.full_build_id), 1), 9, 4)}" #extract node portion of uuid (last 6 octets) for brevity
  build_multiply_format_str        = "%s-%02d"
  build_slug                       = "${var.s3_bucket}/${local.date_ymd}/${local.date_hm}-${local.build_id}"
  build_type_builder               = "builder"
  build_type_source                = "source_build"
  build_type_standalone            = "standalone_build"
  date_hm                          = "${substr(data.null_data_source.start_time.inputs.timestamp, 11, 2)}${substr(data.null_data_source.start_time.inputs.timestamp, 14, 2)}"                                                                 #equivalent of $(date +'%H%M')
  date_ymd                         = "${substr(data.null_data_source.start_time.inputs.timestamp, 0, 4)}${substr(data.null_data_source.start_time.inputs.timestamp, 5, 2)}${substr(data.null_data_source.start_time.inputs.timestamp, 8, 2)}" #equivalent of $(date +'%Y%m%d')
  debug                            = var.debug
  docker_slug                      = var.docker_slug
  format_str_build_label           = "%s-%s"
  full_build_id                    = var.codebuild_id == "" ? format("notcb:%s", uuid()) : var.codebuild_id #128-bit rfc 4122 v4 UUID
  git_ref                          = var.git_ref
  git_repo                         = var.git_repo
  key_pair_name                    = "${local.resource_name}-key"
  local_ip_url                     = "http://ipv4.icanhazip.com"
  lx_args                          = "${var.common_args} ${var.lx_args}"
  lx_builder_os                    = "xenial"
  lx_builder_user                  = "ubuntu"
  lx_connection_type               = "ssh"
  lx_executable                    = "${local.release_prefix}/latest/watchmaker-latest-standalone-linux-x86_64"
  lx_format_str_destination        = "~/watchmaker-test-lx_%s-%s.sh"
  lx_format_str_inline_path        = "~/inline-lx_%s-%s.sh"
  lx_format_str_inline_script      = "chmod +x ~/watchmaker-test-lx_%s-%s.sh\n~/watchmaker-test-lx_%[1]s-%[2]s.sh"
  lx_format_str_instance_name      = "${local.resource_name}-lx_%s-%s"
  lx_format_str_userdata           = "%s"
  lx_standalone_error_signal_file  = "${local.release_prefix}/lx_standalone_error_signal.log"
  lx_temp_dir                      = "/tmp"
  lx_test_template                 = "templates/lx_test.sh"
  lx_timeout_connection            = "40m"
  lx_timeout_create                = "50m"
  lx_userdata_log                  = var.lx_userdata_log
  lx_userdata_status_file          = "${local.lx_temp_dir}/userdata_status"
  lx_userdata_template             = "templates/lx_userdata.sh"
  name_prefix                      = "terrafirm"
  private_key_algorithm            = "RSA"
  private_key_rsa_bits             = "4096"
  pypi_url                         = "https://pypi.org/simple"
  release_prefix                   = "release"
  resource_name                    = "${local.name_prefix}-${local.build_id}"
  rm_user                          = var.rm_user
  security_group_description       = "Used by Terrafirm (${local.resource_name})"
  ssh_port                         = 122
  win_7zip_url                     = "https://www.7-zip.org/a/7z1900-x64.exe"
  win_args                         = "${var.common_args} ${var.win_args}"
  win_builder_os                   = "win12"
  win_connection_type              = "winrm"
  win_download_dir                 = "C:\\Users\\Administrator\\Downloads"
  win_executable                   = "${local.release_prefix}/latest/watchmaker-latest-standalone-windows-amd64.exe"
  win_format_str_destination       = "C:\\scripts\\watchmaker-test-win_%s-%s.ps1"
  win_format_str_inline_path       = "C:\\scripts\\inline-win_%s-%s.cmd"
  win_format_str_inline_script     = "powershell.exe -File C:\\scripts\\watchmaker-test-win_%s-%s.ps1"
  win_format_str_instance_name     = "${local.resource_name}-win_%s-%s"
  win_format_str_userdata          = "<powershell>%s</powershell>"
  win_git_url                      = "https://github.com/git-for-windows/git/releases/download/v2.26.2.windows.1/Git-2.26.2-64-bit.exe"
  win_password_length              = 18
  win_password_override_special    = "()~!@#^*+=|{}[]:;,?"
  win_password_special             = true
  win_python_url                   = "https://www.python.org/ftp/python/3.7.7/python-3.7.7-amd64.exe"
  win_standalone_error_signal_file = "${local.release_prefix}/win_standalone_error_signal.log"
  win_temp_dir                     = "C:\\Temp"
  win_test_template                = "templates/win_test.ps1"
  win_timeout_connection           = "75m"
  win_timeout_create               = "85m"
  win_userdata_log                 = var.win_userdata_log
  win_userdata_status_file         = "${local.win_temp_dir}\\userdata_status"
  win_userdata_template            = "templates/win_userdata.ps1"

  security_group_ingress = {
    winrm = {
      from_port = 5985
      to_port   = 5986
      protocol  = "tcp"
    }
    ssh = {
      from_port = local.ssh_port
      to_port   = local.ssh_port
      protocol  = "tcp"
    }
  }

  win_platform_info = {
    builder                  = local.win_builder_os
    connection_password      = random_string.password.result
    connection_port          = null
    connection_timeout       = local.win_timeout_connection
    connection_type          = local.win_connection_type
    connection_user          = local.rm_user
    create_timeout           = local.win_timeout_create
    format_str_destination   = local.win_format_str_destination
    format_str_inline_path   = local.win_format_str_inline_path
    format_str_inline_script = local.win_format_str_inline_script
    format_str_instance_name = local.win_format_str_instance_name
    format_str_userdata      = local.win_format_str_userdata
    instance_type            = var.win_instance_type
    private_key              = null
    test_template            = local.win_test_template
    userdata_template        = local.win_userdata_template
  }

  lx_platform_info = {
    builder                  = local.lx_builder_os
    connection_password      = null
    connection_port          = local.ssh_port
    connection_timeout       = local.lx_timeout_connection
    connection_type          = local.lx_connection_type
    connection_user          = local.lx_builder_user
    create_timeout           = local.lx_timeout_create
    format_str_destination   = local.lx_format_str_destination
    format_str_inline_path   = local.lx_format_str_inline_path
    format_str_inline_script = local.lx_format_str_inline_script
    format_str_instance_name = local.lx_format_str_instance_name
    format_str_userdata      = local.lx_format_str_userdata
    instance_type            = var.lx_instance_type
    private_key              = tls_private_key.gen_key.private_key_pem
    test_template            = local.lx_test_template
    userdata_template        = local.lx_userdata_template
  }

  build_info = {
    centos6 = {
      ami_regex  = "spel-minimal-centos-6-hvm-\\d{4}\\.\\d{2}\\.\\d{1}\\.x86_64-gp2"
      ami_search = "spel-minimal-centos-6-hvm-*.x86_64-gp2"
      platform   = local.lx_platform_info
    }

    centos7 = {
      ami_regex  = "spel-minimal-centos-7-hvm-\\d{4}\\.\\d{2}\\.\\d{1}\\.x86_64-gp2"
      ami_search = "spel-minimal-centos-7-hvm-*.x86_64-gp2"
      platform   = local.lx_platform_info
    }

    rhel6 = {
      ami_regex  = "spel-minimal-rhel-6-hvm-\\d{4}\\.\\d{2}\\.\\d{1}\\.x86_64-gp2"
      ami_search = "spel-minimal-rhel-6-hvm-*.x86_64-gp2"
      platform   = local.lx_platform_info
    }

    rhel7 = {
      ami_regex  = "spel-minimal-rhel-7-hvm-\\d{4}\\.\\d{2}\\.\\d{1}\\.x86_64-gp2"
      ami_search = "spel-minimal-rhel-7-hvm-*.x86_64-gp2"
      platform   = local.lx_platform_info
    }

    win12 = {
      ami_regex  = null
      ami_search = "Windows_Server-2012-R2_RTM-English-64Bit-Base*"
      platform   = local.win_platform_info
    }

    win16 = {
      ami_regex  = null
      ami_search = "Windows_Server-2016-English-Full-Base*"
      platform   = local.win_platform_info
    }

    win19 = {
      ami_regex  = null
      ami_search = "Windows_Server-2019-English-Full-Base*"
      platform   = local.win_platform_info
    }

    xenial = {
      ami_regex  = null
      ami_search = "ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server*"
      platform   = local.lx_platform_info
    }
  }

  template_vars = {
    aws_region                       = local.aws_region
    bootstrap_url                    = local.bootstrap_url
    build_slug                       = local.build_slug
    build_type_builder               = local.build_type_builder
    build_type_standalone            = local.build_type_standalone
    debug                            = local.debug
    docker_slug                      = local.docker_slug
    git_ref                          = local.git_ref
    git_repo                         = local.git_repo
    lx_args                          = local.lx_args
    lx_executable                    = local.lx_executable
    lx_standalone_error_signal_file  = local.lx_standalone_error_signal_file
    lx_temp_dir                      = local.lx_temp_dir
    lx_userdata_log                  = local.lx_userdata_log
    lx_userdata_status_file          = local.lx_userdata_status_file
    pypi_url                         = local.pypi_url
    release_prefix                   = local.release_prefix
    rm_user                          = local.rm_user
    ssh_port                         = local.ssh_port
    win_7zip_url                     = local.win_7zip_url
    win_args                         = local.win_args
    win_download_dir                 = local.win_download_dir
    win_executable                   = local.win_executable
    win_git_url                      = local.win_git_url
    win_python_url                   = local.win_python_url
    win_standalone_error_signal_file = local.win_standalone_error_signal_file
    win_temp_dir                     = local.win_temp_dir
    win_userdata_log                 = local.win_userdata_log
    win_userdata_status_file         = local.win_userdata_status_file
  }

  standalone_builds    = toset(var.standalone_builds)
  source_builds        = toset(var.source_builds)
  builders             = toset([for s in local.standalone_builds : local.build_info[s].platform.builder])
  unique_builds_needed = setunion(local.standalone_builds, local.source_builds, local.builders)
}

data "null_data_source" "start_time" {
  inputs = {
    # necessary because if you just call timestamp in a local it re-evaluates it everytime that var is read
    timestamp = timestamp()
  }
}

data "aws_ami" "amis" {
  for_each    = local.unique_builds_needed
  most_recent = local.ami_most_recent

  name_regex = local.build_info[each.key].ami_regex

  filter {
    name   = local.ami_filter_virtualization_type
    values = [local.ami_virtualization_type]
  }

  filter {
    name   = local.ami_filter_name
    values = [local.build_info[each.key].ami_search]
  }

  owners = local.ami_owners
}

data "aws_subnet" "tfi" {
  id = var.subnet_id == "" ? aws_default_subnet.tfi.id : var.subnet_id
}

data "http" "ip" {
  url = local.local_ip_url
}

resource "aws_key_pair" "auth" {
  key_name   = local.key_pair_name
  public_key = tls_private_key.gen_key.public_key_openssh
}

resource "tls_private_key" "gen_key" {
  algorithm = local.private_key_algorithm
  rsa_bits  = local.private_key_rsa_bits
}

resource "random_string" "password" {
  length           = local.win_password_length
  special          = local.win_password_special
  override_special = local.win_password_override_special
}

resource "aws_default_subnet" "tfi" {
  availability_zone = var.availability_zone
}

resource "aws_security_group" "builds" {
  name        = local.resource_name
  description = local.security_group_description
  vpc_id      = data.aws_subnet.tfi.vpc_id

  tags = {
    Name = local.resource_name
  }

  dynamic "ingress" {
    for_each = local.security_group_ingress
    content {
      from_port   = ingress.value["from_port"]
      to_port     = ingress.value["to_port"]
      protocol    = ingress.value["protocol"]
      cidr_blocks = ["${chomp(data.http.ip.body)}/32"]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "builder" {
  for_each                    = local.builders
  ami                         = data.aws_ami.amis[each.key].id
  associate_public_ip_address = var.assign_public_ip
  iam_instance_profile        = var.instance_profile
  key_name                    = aws_key_pair.auth.id
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.builds.id]
  instance_type               = local.build_info[each.key].platform.instance_type

  user_data = format(
    local.build_info[each.key].platform.format_str_userdata,
    templatefile(
      local.build_info[each.key].platform.userdata_template,
      merge(
        local.template_vars,
        {
          build_os    = each.key
          build_type  = local.build_type_builder
          build_label = format(local.format_str_build_label, local.build_type_builder, each.key)
          rm_pass     = random_string.password.result
        }
      )
    )
  )

  tags = {
    Name = format(
      local.build_info[each.key].platform.format_str_instance_name,
      local.build_type_builder,
      each.key
    )
  }

  timeouts {
    create = local.build_info[each.key].platform.create_timeout
  }

  connection {
    host        = self.public_ip
    password    = local.build_info[each.key].platform.connection_password
    port        = local.build_info[each.key].platform.connection_port
    private_key = local.build_info[each.key].platform.private_key
    timeout     = local.build_info[each.key].platform.connection_timeout
    type        = local.build_info[each.key].platform.connection_type
    user        = local.build_info[each.key].platform.connection_user
  }

  provisioner "file" {
    content = templatefile(
      local.build_info[each.key].platform.test_template,
      merge(
        local.template_vars,
        {
          build_os    = each.key
          build_type  = local.build_type_builder
          build_label = format(local.format_str_build_label, local.build_type_builder, each.key)
        }
      )
    )
    destination = format(
      local.build_info[each.key].platform.format_str_destination,
      local.build_type_builder,
      each.key
    )
  }

  provisioner "remote-exec" {
    inline = [
      format(
        local.build_info[each.key].platform.format_str_inline_script,
        local.build_type_builder,
        each.key
      ),
    ]

    connection {
      host = coalesce(self.public_ip, self.private_ip)
      type = local.build_info[each.key].platform.connection_type
      script_path = format(
        local.build_info[each.key].platform.format_str_inline_path,
        local.build_type_builder,
        each.key
      )
    }
  }
}

resource "aws_instance" "standalone_build" {
  for_each                    = local.standalone_builds
  ami                         = data.aws_ami.amis[each.key].id
  associate_public_ip_address = var.assign_public_ip
  iam_instance_profile        = var.instance_profile
  key_name                    = aws_key_pair.auth.id
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.builds.id]
  instance_type               = local.build_info[each.key].platform.instance_type

  user_data = format(
    local.build_info[each.key].platform.format_str_userdata,
    templatefile(
      local.build_info[each.key].platform.userdata_template,
      merge(
        local.template_vars,
        {
          build_os    = each.key
          build_type  = local.build_type_standalone
          build_label = format(local.format_str_build_label, local.build_type_standalone, each.key)
          rm_pass     = random_string.password.result
        }
      )
    )
  )

  tags = {
    Name = format(
      local.build_info[each.key].platform.format_str_instance_name,
      local.build_type_standalone,
      each.key
    )

    BuilderID = aws_instance.builder[local.build_info[each.key].platform.builder].id
  }

  timeouts {
    create = local.build_info[each.key].platform.create_timeout
  }

  connection {
    type        = local.build_info[each.key].platform.connection_type
    host        = self.public_ip
    user        = local.build_info[each.key].platform.connection_user
    private_key = local.build_info[each.key].platform.private_key
    port        = local.build_info[each.key].platform.connection_port
    timeout     = local.build_info[each.key].platform.connection_timeout
    password    = local.build_info[each.key].platform.connection_password
  }

  provisioner "file" {
    content = templatefile(
      local.build_info[each.key].platform.test_template,
      merge(
        local.template_vars,
        {
          build_os    = each.key
          build_type  = local.build_type_standalone
          build_label = format(local.format_str_build_label, local.build_type_standalone, each.key)
        }
      )
    )
    destination = format(
      local.build_info[each.key].platform.format_str_destination,
      local.build_type_standalone,
      each.key
    )
  }

  provisioner "remote-exec" {
    inline = [
      format(
        local.build_info[each.key].platform.format_str_inline_script,
        local.build_type_standalone,
        each.key
      ),
    ]

    connection {
      host = coalesce(self.public_ip, self.private_ip)
      type = local.build_info[each.key].platform.connection_type
      script_path = format(
        local.build_info[each.key].platform.format_str_inline_path,
        local.build_type_standalone,
        each.key
      )
    }
  }
}

resource "aws_instance" "source_build" {
  for_each                    = local.source_builds
  ami                         = data.aws_ami.amis[each.key].id
  associate_public_ip_address = var.assign_public_ip
  iam_instance_profile        = var.instance_profile
  key_name                    = aws_key_pair.auth.id
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.builds.id]
  instance_type               = local.build_info[each.key].platform.instance_type

  user_data = format(
    local.build_info[each.key].platform.format_str_userdata,
    templatefile(
      local.build_info[each.key].platform.userdata_template,
      merge(
        local.template_vars,
        {
          build_os    = each.key
          build_type  = local.build_type_source
          build_label = format(local.format_str_build_label, local.build_type_source, each.key)
          rm_pass     = random_string.password.result
        }
      )
    )
  )

  tags = {
    Name = format(
      local.build_info[each.key].platform.format_str_instance_name,
      local.build_type_source,
      each.key
    )
  }

  timeouts {
    create = local.build_info[each.key].platform.create_timeout
  }

  connection {
    type        = local.build_info[each.key].platform.connection_type
    host        = self.public_ip
    user        = local.build_info[each.key].platform.connection_user
    private_key = local.build_info[each.key].platform.private_key
    port        = local.build_info[each.key].platform.connection_port
    timeout     = local.build_info[each.key].platform.connection_timeout
    password    = local.build_info[each.key].platform.connection_password
  }

  provisioner "file" {
    content = templatefile(
      local.build_info[each.key].platform.test_template,
      merge(
        local.template_vars,
        {
          build_os    = each.key
          build_type  = local.build_type_source
          build_label = format(local.format_str_build_label, local.build_type_source, each.key)
        }
      )
    )
    destination = format(
      local.build_info[each.key].platform.format_str_destination,
      local.build_type_source,
      each.key
    )
  }

  provisioner "remote-exec" {
    inline = [
      format(
        local.build_info[each.key].platform.format_str_inline_script,
        local.build_type_source,
        each.key
      ),
    ]

    connection {
      host = coalesce(self.public_ip, self.private_ip)
      type = local.build_info[each.key].platform.connection_type
      script_path = format(
        local.build_info[each.key].platform.format_str_inline_path,
        local.build_type_source,
        each.key
      )
    }
  }
}
