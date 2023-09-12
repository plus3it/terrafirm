locals {
  ami_filter_name                  = "name"
  ami_filter_virtualization_type   = "virtualization-type"
  ami_most_recent                  = true
  ami_owners                       = ["174003430611", "216406534498", "701759196663", "099720109477", "801119661308", "039368651566", "513442679011", "077303321853"]
  ami_virtualization_type          = "hvm"
  aws_region                       = var.aws_region
  build_id                         = "${substr(element(split(":", local.full_build_id), 1), 0, 8)}${substr(element(split(":", local.full_build_id), 1), 9, 4)}" #extract node portion of uuid (last 6 octets) for brevity
  build_slug                       = "${var.s3_bucket}/${local.date_ymd}/${local.date_hm}-${local.build_id}"
  build_type_builder               = "builder"
  build_type_source                = "source_build"
  build_type_standalone            = "standalone_build"
  date_hm                          = "${substr(local.timestamp, 11, 2)}${substr(local.timestamp, 14, 2)}"                               #equivalent of $(date +'%H%M')
  date_ymd                         = "${substr(local.timestamp, 0, 4)}${substr(local.timestamp, 5, 2)}${substr(local.timestamp, 8, 2)}" #equivalent of $(date +'%Y%m%d')
  debug                            = var.debug
  docker_slug                      = var.docker_slug
  format_str_build_label           = "%s-%s"
  full_build_id                    = var.codebuild_id == "" ? format("notcb:%s", uuid()) : var.codebuild_id #128-bit rfc 4122 v4 UUID
  git_ref                          = var.git_ref
  git_repo                         = var.git_repo
  key_pair_name                    = "${local.resource_name}-key"
  lx_args                          = "${var.common_args} ${var.lx_args}"
  lx_builder_os                    = "focal"
  lx_connection_type               = "ssh"
  lx_executable                    = "${local.release_prefix}/latest/watchmaker-latest-standalone-linux-x86_64"
  lx_format_str_destination        = "/home/%s/watchmaker-test-%s-%s.sh"
  lx_format_str_inline_path        = "/home/%s/inline-%s-%s.sh"
  lx_format_str_inline_script      = "chmod +x /home/%s/watchmaker-test-%s-%s.sh\n/home/%[1]s/watchmaker-test-%[2]s-%[3]s.sh"
  lx_format_str_instance_name      = "${local.resource_name}-%s-%s"
  lx_format_str_userdata           = "%s"
  lx_port                          = 122
  lx_standalone_error_signal_file  = "${local.release_prefix}/lx_standalone_error_signal.log"
  lx_temp_dir                      = "/tmp"
  lx_test_template                 = "templates/lx_test.sh"
  lx_timeout_connection            = "40m"
  lx_timeout_create                = "50m"
  lx_user                          = var.lx_user
  lx_user_builder                  = "ubuntu"
  lx_userdata_log                  = var.lx_userdata_log
  lx_userdata_status_file          = "${local.lx_temp_dir}/userdata_status"
  lx_userdata_template             = "templates/lx_userdata.sh"
  name_prefix                      = "terrafirm"
  private_key_algorithm            = "RSA"
  private_key_rsa_bits             = "4096"
  release_prefix                   = "release"
  resource_name                    = "${local.name_prefix}-${local.build_id}"
  scan_slug                        = var.scan_s3_url
  security_group_description       = "Used by Terrafirm (${local.resource_name})"
  timestamp                        = timestamp()
  url_bootstrap                    = "https://raw.githubusercontent.com/plus3it/watchmaker/main/docs/files/bootstrap/watchmaker-bootstrap.ps1"
  url_local_ip                     = "http://ipv4.icanhazip.com"
  url_pypi                         = "https://pypi.org/simple"
  win_args                         = "${var.common_args} ${var.win_args}"
  win_builder_os                   = "win12"
  win_connection_type              = "winrm"
  win_download_dir                 = "C:\\Users\\Administrator\\Downloads"
  win_executable                   = "${local.release_prefix}/latest/watchmaker-latest-standalone-windows-amd64.exe"
  win_format_str_destination       = "C:\\scripts\\watchmaker-test-%s-%s-%s.ps1"
  win_format_str_inline_path       = "C:\\scripts\\inline-%s-%s-%s.cmd"
  win_format_str_inline_script     = "powershell.exe -File C:\\scripts\\watchmaker-test-%s-%s-%s.ps1"
  win_format_str_instance_name     = "${local.resource_name}-%s-%s"
  win_format_str_userdata          = "<powershell>%s</powershell>"
  win_password_length              = 18
  win_password_override_special    = "()~!@#^*+=|{}[]:;,?"
  win_password_special             = true
  win_standalone_error_signal_file = "${local.release_prefix}/win_standalone_error_signal.log"
  win_temp_dir                     = "C:\\Temp"
  win_test_template                = "templates/win_test.ps1"
  win_timeout_connection           = "75m"
  win_timeout_create               = "85m"
  win_url_7zip                     = "https://www.7-zip.org/a/7z1900-x64.exe"
  win_url_git                      = "https://github.com/git-for-windows/git/releases/download/v2.33.1.windows.1/Git-2.33.1-64-bit.exe"
  win_url_python                   = "https://www.python.org/ftp/python/3.8.10/python-3.8.10-amd64.exe"
  win_user                         = var.win_user
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
      from_port = local.lx_port
      to_port   = local.lx_port
      protocol  = "tcp"
    }
  }

  platform_info = {
    win = {
      builder                  = local.win_builder_os
      connection_key           = null
      connection_password      = random_string.password.result
      connection_port          = null
      connection_timeout       = local.win_timeout_connection
      connection_type          = local.win_connection_type
      connection_user          = local.win_user
      connection_user_builder  = local.win_user
      create_timeout           = local.win_timeout_create
      format_str_destination   = local.win_format_str_destination
      format_str_inline_path   = local.win_format_str_inline_path
      format_str_inline_script = local.win_format_str_inline_script
      format_str_instance_name = local.win_format_str_instance_name
      format_str_userdata      = local.win_format_str_userdata
      instance_type            = var.win_instance_type
      key                      = "win"
      test_template            = local.win_test_template
      userdata_template        = local.win_userdata_template
    }

    lx = {
      builder                  = local.lx_builder_os
      connection_key           = tls_private_key.gen_key.private_key_pem
      connection_password      = null
      connection_port          = local.lx_port
      connection_timeout       = local.lx_timeout_connection
      connection_type          = local.lx_connection_type
      connection_user          = local.lx_user
      connection_user_builder  = local.lx_user_builder
      create_timeout           = local.lx_timeout_create
      format_str_destination   = local.lx_format_str_destination
      format_str_inline_path   = local.lx_format_str_inline_path
      format_str_inline_script = local.lx_format_str_inline_script
      format_str_instance_name = local.lx_format_str_instance_name
      format_str_userdata      = local.lx_format_str_userdata
      instance_type            = var.lx_instance_type
      key                      = "lx"
      test_template            = local.lx_test_template
      userdata_template        = local.lx_userdata_template
    }
  }

  build_info = {
    centos8stream = {
      ami_regex  = "spel-minimal-centos-8stream-hvm-\\d{4}\\.\\d{2}\\.\\d{1}\\.x86_64-gp2"
      ami_search = "spel-minimal-centos-8stream-hvm-*.x86_64-gp2"
      platform   = local.platform_info.lx
    }

    ol8 = {
      ami_regex  = "spel-minimal-ol-8-hvm-\\d{4}\\.\\d{2}\\.\\d{1}\\.x86_64-gp2"
      ami_search = "spel-minimal-ol-8-hvm-*.x86_64-gp2"
      platform   = local.platform_info.lx
    }

    rhel8 = {
      ami_regex  = "spel-minimal-rhel-8-hvm-\\d{4}\\.\\d{2}\\.\\d{1}\\.x86_64-gp2"
      ami_search = "spel-minimal-rhel-8-hvm-*.x86_64-gp2"
      platform   = local.platform_info.lx
    }

    centos7 = {
      ami_regex  = "spel-minimal-centos-7-hvm-\\d{4}\\.\\d{2}\\.\\d{1}\\.x86_64-gp2"
      ami_search = "spel-minimal-centos-7-hvm-*.x86_64-gp2"
      platform   = local.platform_info.lx
    }

    rhel7 = {
      ami_regex  = "spel-minimal-rhel-7-hvm-\\d{4}\\.\\d{2}\\.\\d{1}\\.x86_64-gp2"
      ami_search = "spel-minimal-rhel-7-hvm-*.x86_64-gp2"
      platform   = local.platform_info.lx
    }

    win12 = {
      ami_regex  = null
      ami_search = "Windows_Server-2012-R2_RTM-English-64Bit-Base*"
      platform   = local.platform_info.win
    }

    win16 = {
      ami_regex  = null
      ami_search = "Windows_Server-2016-English-Full-Base*"
      platform   = local.platform_info.win
    }

    win19 = {
      ami_regex  = null
      ami_search = "Windows_Server-2019-English-Full-Base*"
      platform   = local.platform_info.win
    }

    focal = {
      ami_regex  = null
      ami_search = "ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server*"
      platform   = local.platform_info.lx
    }
  }

  template_vars = {
    base = {
      aws_region            = local.aws_region
      build_slug            = local.build_slug
      build_type_builder    = local.build_type_builder
      build_type_source     = local.build_type_source
      build_type_standalone = local.build_type_standalone
      debug                 = local.debug
      docker_slug           = local.docker_slug
      git_ref               = local.git_ref
      git_repo              = local.git_repo
      release_prefix        = local.release_prefix
      scan_slug             = local.scan_slug
      url_bootstrap         = local.url_bootstrap
      url_pypi              = local.url_pypi
    }

    lx = {
      args                         = local.lx_args
      executable                   = local.lx_executable
      port                         = local.lx_port
      standalone_error_signal_file = local.lx_standalone_error_signal_file
      temp_dir                     = local.lx_temp_dir
      userdata_log                 = local.lx_userdata_log
      userdata_status_file         = local.lx_userdata_status_file
    }

    win = {
      args                         = local.win_args
      download_dir                 = local.win_download_dir
      executable                   = local.win_executable
      standalone_error_signal_file = local.win_standalone_error_signal_file
      temp_dir                     = local.win_temp_dir
      url_7zip                     = local.win_url_7zip
      url_git                      = local.win_url_git
      url_python                   = local.win_url_python
      user                         = local.win_user
      userdata_log                 = local.win_userdata_log
      userdata_status_file         = local.win_userdata_status_file
    }
  }

  standalone_builds    = toset(var.standalone_builds)
  source_builds        = toset(var.source_builds)
  builders             = toset([for s in local.standalone_builds : local.build_info[s].platform.builder])
  unique_builds_needed = setunion(local.standalone_builds, local.source_builds, local.builders)
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
  id = var.subnet_ids[0]
}

data "aws_vpc" "tfi" {
  id = data.aws_subnet.tfi.vpc_id
}

data "http" "ip" {
  url = local.url_local_ip
}

resource "random_shuffle" "subnet_ids" {
  input = var.subnet_ids
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

resource "aws_security_group" "builds" {
  name        = local.resource_name
  description = local.security_group_description
  vpc_id      = data.aws_vpc.tfi.id

  tags = {
    Name = local.resource_name
  }

  dynamic "ingress" {
    for_each = local.security_group_ingress
    content {
      from_port = ingress.value["from_port"]
      to_port   = ingress.value["to_port"]
      protocol  = ingress.value["protocol"]
      cidr_blocks = [
        "${chomp(data.http.ip.response_body)}/32",
        data.aws_vpc.tfi.cidr_block,
      ]
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
  for_each = local.builders

  ami                         = data.aws_ami.amis[each.key].id
  associate_public_ip_address = var.assign_public_ip
  iam_instance_profile        = var.instance_profile
  key_name                    = aws_key_pair.auth.id
  subnet_id                   = element(random_shuffle.subnet_ids.result, index(sort(local.unique_builds_needed), each.key))
  vpc_security_group_ids      = [aws_security_group.builds.id]
  instance_type               = local.build_info[each.key].platform.instance_type

  user_data = format(
    local.build_info[each.key].platform.format_str_userdata,
    templatefile(
      local.build_info[each.key].platform.userdata_template,
      merge(
        local.template_vars.base,
        local.template_vars[local.build_info[each.key].platform.key],
        {
          build_os    = each.key
          build_type  = local.build_type_builder
          build_label = format(local.format_str_build_label, local.build_type_builder, each.key)
          password    = local.build_info[each.key].platform.connection_password
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
    type        = local.build_info[each.key].platform.connection_type
    host        = coalesce(self.public_ip, self.private_ip)
    user        = local.build_info[each.key].platform.connection_user_builder
    password    = local.build_info[each.key].platform.connection_password
    timeout     = local.build_info[each.key].platform.connection_timeout
    port        = local.build_info[each.key].platform.connection_port
    private_key = local.build_info[each.key].platform.connection_key
  }

  provisioner "file" {
    content = templatefile(
      local.build_info[each.key].platform.test_template,
      merge(
        local.template_vars.base,
        local.template_vars[local.build_info[each.key].platform.key],
        {
          build_os    = each.key
          build_type  = local.build_type_builder
          build_label = format(local.format_str_build_label, local.build_type_builder, each.key)
        }
      )
    )
    destination = format(
      local.build_info[each.key].platform.format_str_destination,
      local.build_info[each.key].platform.connection_user_builder,
      local.build_type_builder,
      each.key
    )
  }

  provisioner "remote-exec" {
    inline = [
      format(
        local.build_info[each.key].platform.format_str_inline_script,
        local.build_info[each.key].platform.connection_user_builder,
        local.build_type_builder,
        each.key
      ),
    ]

    connection {
      host = coalesce(self.public_ip, self.private_ip)
      type = local.build_info[each.key].platform.connection_type
      script_path = format(
        local.build_info[each.key].platform.format_str_inline_path,
        local.build_info[each.key].platform.connection_user_builder,
        local.build_type_builder,
        each.key
      )
    }
  }
}

resource "aws_instance" "standalone_build" {
  for_each = local.standalone_builds

  ami                         = data.aws_ami.amis[each.key].id
  associate_public_ip_address = var.assign_public_ip
  iam_instance_profile        = var.instance_profile
  key_name                    = aws_key_pair.auth.id
  subnet_id                   = element(random_shuffle.subnet_ids.result, index(sort(local.unique_builds_needed), each.key))
  vpc_security_group_ids      = [aws_security_group.builds.id]
  instance_type               = local.build_info[each.key].platform.instance_type

  user_data = format(
    local.build_info[each.key].platform.format_str_userdata,
    templatefile(
      local.build_info[each.key].platform.userdata_template,
      merge(
        local.template_vars.base,
        local.template_vars[local.build_info[each.key].platform.key],
        {
          build_os    = each.key
          build_type  = local.build_type_standalone
          build_label = format(local.format_str_build_label, local.build_type_standalone, each.key)
          password    = local.build_info[each.key].platform.connection_password
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
    host        = coalesce(self.public_ip, self.private_ip)
    user        = local.build_info[each.key].platform.connection_user
    private_key = local.build_info[each.key].platform.connection_key
    port        = local.build_info[each.key].platform.connection_port
    timeout     = local.build_info[each.key].platform.connection_timeout
    password    = local.build_info[each.key].platform.connection_password
  }

  provisioner "file" {
    content = templatefile(
      local.build_info[each.key].platform.test_template,
      merge(
        local.template_vars.base,
        local.template_vars[local.build_info[each.key].platform.key],
        {
          build_os    = each.key
          build_type  = local.build_type_standalone
          build_label = format(local.format_str_build_label, local.build_type_standalone, each.key)
        }
      )
    )
    destination = format(
      local.build_info[each.key].platform.format_str_destination,
      local.build_info[each.key].platform.connection_user,
      local.build_type_standalone,
      each.key
    )
  }

  provisioner "remote-exec" {
    inline = [
      format(
        local.build_info[each.key].platform.format_str_inline_script,
        local.build_info[each.key].platform.connection_user,
        local.build_type_standalone,
        each.key
      ),
    ]

    connection {
      host = coalesce(self.public_ip, self.private_ip)
      type = local.build_info[each.key].platform.connection_type
      script_path = format(
        local.build_info[each.key].platform.format_str_inline_path,
        local.build_info[each.key].platform.connection_user,
        local.build_type_standalone,
        each.key
      )
    }
  }
}

resource "aws_instance" "source_build" {
  for_each = local.source_builds

  ami                         = data.aws_ami.amis[each.key].id
  associate_public_ip_address = var.assign_public_ip
  iam_instance_profile        = var.instance_profile
  key_name                    = aws_key_pair.auth.id
  subnet_id                   = element(random_shuffle.subnet_ids.result, index(sort(local.unique_builds_needed), each.key))
  vpc_security_group_ids      = [aws_security_group.builds.id]
  instance_type               = local.build_info[each.key].platform.instance_type

  user_data = format(
    local.build_info[each.key].platform.format_str_userdata,
    templatefile(
      local.build_info[each.key].platform.userdata_template,
      merge(
        local.template_vars.base,
        local.template_vars[local.build_info[each.key].platform.key],
        {
          build_os    = each.key
          build_type  = local.build_type_source
          build_label = format(local.format_str_build_label, local.build_type_source, each.key)
          password    = local.build_info[each.key].platform.connection_password
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
    host        = coalesce(self.public_ip, self.private_ip)
    user        = local.build_info[each.key].platform.connection_user
    private_key = local.build_info[each.key].platform.connection_key
    port        = local.build_info[each.key].platform.connection_port
    timeout     = local.build_info[each.key].platform.connection_timeout
    password    = local.build_info[each.key].platform.connection_password
  }

  provisioner "file" {
    content = templatefile(
      local.build_info[each.key].platform.test_template,
      merge(
        local.template_vars.base,
        local.template_vars[local.build_info[each.key].platform.key],
        {
          build_os    = each.key
          build_type  = local.build_type_source
          build_label = format(local.format_str_build_label, local.build_type_source, each.key)
        }
      )
    )
    destination = format(
      local.build_info[each.key].platform.format_str_destination,
      local.build_info[each.key].platform.connection_user,
      local.build_type_source,
      each.key
    )
  }

  provisioner "remote-exec" {
    inline = [
      format(
        local.build_info[each.key].platform.format_str_inline_script,
        local.build_info[each.key].platform.connection_user,
        local.build_type_source,
        each.key
      ),
    ]

    connection {
      host = coalesce(self.public_ip, self.private_ip)
      type = local.build_info[each.key].platform.connection_type
      script_path = format(
        local.build_info[each.key].platform.format_str_inline_path,
        local.build_info[each.key].platform.connection_user,
        local.build_type_source,
        each.key
      )
    }
  }
}
