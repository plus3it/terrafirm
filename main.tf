# various settings used by the builds
locals {
  pypi_url       = "https://pypi.org/simple"
  release_prefix = "release"

  lx_builder_instance_type  = "t2.large"
  win_builder_instance_type = "t2.xlarge"

  lx_builder_os  = "xenial"
  win_builder_os = "win12"

  lx_standalone_error_signal_file  = "${local.release_prefix}/lx_standalone_error_signal.log"
  win_standalone_error_signal_file = "${local.release_prefix}/win_standalone_error_signal.log"

  lx_executable  = "${local.release_prefix}/latest/watchmaker-latest-standalone-linux-x86_64"
  win_executable = "${local.release_prefix}/latest/watchmaker-latest-standalone-windows-amd64.exe"

  lx_temp_dir  = "/tmp"
  win_temp_dir = "C:\\Temp"

  lx_userdata_status_file  = "${local.lx_temp_dir}/userdata_status"
  win_userdata_status_file = "${local.win_temp_dir}\\userdata_status"

  lx_builder_user = "ubuntu"
  ssh_port        = 122

  win_7zip_url      = "https://www.7-zip.org/a/7z1900-x64.exe"
  win_bootstrap_url = "https://raw.githubusercontent.com/plus3it/watchmaker/develop/docs/files/bootstrap/watchmaker-bootstrap.ps1"
  win_download_dir  = "C:\\Users\\Administrator\\Downloads"
  win_git_url       = "https://github.com/git-for-windows/git/releases/download/v2.26.2.windows.1/Git-2.26.2-64-bit.exe"
  win_python_url    = "https://www.python.org/ftp/python/3.7.7/python-3.7.7-amd64.exe"

  # build settings
  name_prefix   = "terrafirm"
  date_ymd      = "${substr(data.null_data_source.start_time.inputs.timestamp, 0, 4)}${substr(data.null_data_source.start_time.inputs.timestamp, 5, 2)}${substr(data.null_data_source.start_time.inputs.timestamp, 8, 2)}" #equivalent of $(date +'%Y%m%d')
  date_hm       = "${substr(data.null_data_source.start_time.inputs.timestamp, 11, 2)}${substr(data.null_data_source.start_time.inputs.timestamp, 14, 2)}"                                                                 #equivalent of $(date +'%H%M')
  full_build_id = var.codebuild_id == "" ? format("notcb:%s", uuid()) : var.codebuild_id                                                                                                                                   #128-bit rfc 4122 v4 UUID
  build_id      = "${substr(element(split(":", local.full_build_id), 1), 0, 8)}${substr(element(split(":", local.full_build_id), 1), 9, 4)}"                                                                               #extract node portion of uuid (last 6 octets) for brevity
  resource_name = "${local.name_prefix}-${local.build_id}"
  build_slug    = "${var.s3_bucket}/${local.date_ymd}/${local.date_hm}-${local.build_id}"

  # amis
  win_build_info = {
    win12 = {
      ami_search = "Windows_Server-2012-R2_RTM-English-64Bit-Base*"
    }

    win16 = {
      ami_search = "Windows_Server-2016-English-Full-Base*"
    }

    win19 = {
      ami_search = "Windows_Server-2019-English-Full-Base*"
    }
  }

  lx_build_info = {
    centos6 = {
      ami_search = "spel-minimal-centos-6-hvm-*.x86_64-gp2"
      ami_regex  = "spel-minimal-centos-6-hvm-\\d{4}\\.\\d{2}\\.\\d{1}\\.x86_64-gp2"
    }

    centos7 = {
      ami_search = "spel-minimal-centos-7-hvm-*.x86_64-gp2"
      ami_regex  = "spel-minimal-centos-7-hvm-\\d{4}\\.\\d{2}\\.\\d{1}\\.x86_64-gp2"
    }

    rhel6 = {
      ami_search = "spel-minimal-rhel-6-hvm-*.x86_64-gp2"
      ami_regex  = "spel-minimal-rhel-6-hvm-\\d{4}\\.\\d{2}\\.\\d{1}\\.x86_64-gp2"
    }

    rhel7 = {
      ami_search = "spel-minimal-rhel-7-hvm-*.x86_64-gp2"
      ami_regex  = "spel-minimal-rhel-7-hvm-\\d{4}\\.\\d{2}\\.\\d{1}\\.x86_64-gp2"
    }

    xenial = {
      ami_search = "ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server*"
      ami_regex  = ""
    }
  }

  ami_settings = {
    owners              = ["701759196663", "099720109477", "801119661308"]
    virtualization_type = "hvm"
  }

  # get list of all possible builds
  win_possible_builds = toset(keys(local.win_build_info))
  lx_possible_builds = setsubtract(
    toset(keys(local.lx_build_info)),
    toset([local.lx_builder_os])
  )
  possible_builds = setunion(local.win_possible_builds, local.lx_possible_builds)

  # user input
  source_builds     = var.run_all_builds ? local.possible_builds : var.source_builds
  standalone_builds = var.run_all_builds ? local.possible_builds : var.standalone_builds

  # win unique builds
  win_source_unique_builds     = setintersection(local.win_possible_builds, local.source_builds)
  win_standalone_unique_builds = setintersection(local.win_possible_builds, local.standalone_builds)
  win_builder_needed           = length(local.win_standalone_unique_builds) > 0 ? [local.win_builder_os] : []
  win_unique_builds            = setunion(local.win_source_unique_builds, local.win_standalone_unique_builds, local.win_builder_needed)
  win_any_builds               = length(local.win_unique_builds) > 0 ? 1 : 0

  # if build_multiplier is > 1, these will be used
  win_source_multiplied_builds = [
    for i in setproduct(
      local.win_source_unique_builds,
      range(1, var.build_multiplier + 1)
    ) : format("%s-%02d", i[0], i[1])
  ]
  win_standalone_multiplied_builds = [
    for i in setproduct(
      local.win_standalone_unique_builds,
      range(1, var.build_multiplier + 1)
    ) : format("%s-%02d", i[0], i[1])
  ]

  # which win builds to run
  win_source_builds     = var.build_multiplier > 1 ? local.win_source_multiplied_builds : local.win_source_unique_builds
  win_standalone_builds = var.build_multiplier > 1 ? local.win_standalone_multiplied_builds : local.win_standalone_unique_builds

  # lx unique builds
  lx_source_unique_builds     = setintersection(local.lx_possible_builds, local.source_builds)
  lx_standalone_unique_builds = setintersection(local.lx_possible_builds, local.standalone_builds)
  lx_builder_needed           = length(local.lx_standalone_unique_builds) > 0 ? [local.lx_builder_os] : []
  lx_unique_builds            = setunion(local.lx_source_unique_builds, local.lx_standalone_unique_builds, local.lx_builder_needed)
  lx_any_builds               = length(local.lx_unique_builds) > 0 ? 1 : 0

  # if build_multiplier is > 1, these will be used
  lx_source_multiplied_builds = [
    for i in setproduct(
      local.lx_source_unique_builds,
      range(1, var.build_multiplier + 1)
    ) : format("%s-%02d", i[0], i[1])
  ]
  lx_standalone_multiplied_builds = [
    for i in setproduct(
      local.lx_standalone_unique_builds,
      range(1, var.build_multiplier + 1)
    ) : format("%s-%02d", i[0], i[1])
  ]

  # which lx builds to run
  lx_source_builds     = var.build_multiplier > 1 ? local.lx_source_multiplied_builds : local.lx_source_unique_builds
  lx_standalone_builds = var.build_multiplier > 1 ? local.lx_standalone_multiplied_builds : local.lx_standalone_unique_builds
}

data "null_data_source" "start_time" {
  inputs = {
    # necessary because if you just call timestamp in a local it re-evaluates it everytime that var is read
    timestamp = timestamp()
  }
}

data "aws_ami" "win_amis" {
  for_each    = local.win_unique_builds
  most_recent = true

  filter {
    name   = "virtualization-type"
    values = [local.ami_settings.virtualization_type]
  }

  filter {
    name   = "name"
    values = [local.win_build_info[each.key].ami_search]
  }

  owners = local.ami_settings.owners
}

data "aws_ami" "lx_amis" {
  for_each    = local.lx_unique_builds
  most_recent = true

  name_regex = local.lx_build_info[each.key].ami_regex

  filter {
    name   = "virtualization-type"
    values = [local.ami_settings.virtualization_type]
  }

  filter {
    name   = "name"
    values = [local.lx_build_info[each.key].ami_search]
  }

  owners = local.ami_settings.owners
}

data "aws_subnet" "tfi" {
  id = var.subnet_id == "" ? aws_default_subnet.tfi.id : var.subnet_id
}

data "http" "ip" {
  # Used to get local ip for security group ingress
  url = "http://ipv4.icanhazip.com"
}

resource "aws_key_pair" "auth" {
  key_name   = "${local.resource_name}-key"
  public_key = tls_private_key.gen_key.public_key_openssh
}

resource "tls_private_key" "gen_key" {
  algorithm = "RSA"
  rsa_bits  = "4096"
}

resource "random_string" "password" {
  count            = local.win_any_builds
  length           = 18
  special          = true
  override_special = "()~!@#^*+=|{}[]:;,?"
}

resource "aws_default_subnet" "tfi" {
  availability_zone = var.availability_zone
}

resource "aws_security_group" "winrm_sg" {
  count       = local.win_any_builds
  name        = "${local.resource_name}-winrm"
  description = "Used in terrafirm"
  vpc_id      = data.aws_subnet.tfi.vpc_id

  tags = {
    Name = local.resource_name
  }

  ingress {
    from_port   = 5985
    to_port     = 5986
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.ip.body)}/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ssh_sg" {
  count       = local.lx_any_builds # only create if any lx builds
  name        = "${local.resource_name}-ssh"
  description = "Used in terrafirm"
  vpc_id      = data.aws_subnet.tfi.vpc_id

  tags = {
    Name = local.resource_name
  }

  ingress {
    from_port   = local.ssh_port
    to_port     = local.ssh_port
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.ip.body)}/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

locals {
  common_template_vars = {
    build_slug     = local.build_slug
    common_args    = var.common_args
    debug          = var.debug
    git_ref        = var.git_ref
    git_repo       = var.git_repo
    pypi_url       = local.pypi_url
    release_prefix = local.release_prefix
  }

  win_template_vars = {
    bootstrap_url                = local.win_bootstrap_url
    download_dir                 = local.win_download_dir
    executable                   = local.win_executable
    git_url                      = local.win_git_url
    python_url                   = local.win_python_url
    rm_pass                      = random_string.password[0].result
    rm_user                      = var.rm_user
    seven_zip_url                = local.win_7zip_url
    standalone_error_signal_file = local.win_standalone_error_signal_file
    temp_dir                     = local.win_temp_dir
    userdata_log                 = var.win_userdata_log
    userdata_status_file         = local.win_userdata_status_file
    win_args                     = var.win_args
  }

  lx_template_vars = {
    aws_region                   = var.aws_region
    docker_slug                  = var.docker_slug
    executable                   = local.lx_executable
    lx_args                      = var.lx_args
    ssh_port                     = local.ssh_port
    standalone_error_signal_file = local.lx_standalone_error_signal_file
    temp_dir                     = local.lx_temp_dir
    userdata_log                 = var.lx_userdata_log
    userdata_status_file         = local.lx_userdata_status_file
  }
}

resource "aws_instance" "win_builder" {
  for_each = toset(local.win_builder_needed)
  ami      = data.aws_ami.win_amis[each.key].id

  associate_public_ip_address = var.assign_public_ip
  iam_instance_profile        = var.instance_profile
  instance_type               = local.win_builder_instance_type
  key_name                    = aws_key_pair.auth.id
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = aws_security_group.winrm_sg.*.id

  user_data = format(
    "<powershell>%s</powershell>",
    templatefile(
      "templates/win_userdata.ps1",
      merge(
        local.common_template_vars,
        local.win_template_vars,
        {
          build_os   = each.key
          build_type = "builder"
        }
      )
    )
  )

  tags = {
    Name = "${local.resource_name}-win_builder-${each.key}"
  }

  timeouts {
    create = "30m"
  }

  connection {
    type     = "winrm"
    host     = self.public_ip
    user     = var.rm_user
    password = join("", random_string.password.*.result)
    timeout  = "30m"
  }

  provisioner "file" {
    content = templatefile("templates/win_test.ps1", {
      build_os             = each.key
      build_type           = "builder"
      standalone_path      = local.win_download_dir
      userdata_status_file = local.win_userdata_status_file
    })
    destination = "C:\\scripts\\watchmaker-test-win_builder-${each.key}.ps1"
  }

  provisioner "remote-exec" {
    inline = [
      "powershell.exe -File C:\\scripts\\watchmaker-test-win_builder-${each.key}.ps1",
    ]

    connection {
      host = coalesce(self.public_ip, self.private_ip)
      type = "winrm"
      # this is where terraform puts the above mini inline script
      script_path = "C:\\scripts\\inline-win_builder-${each.key}.cmd"
    }
  }
}

resource "aws_instance" "win_source" {
  for_each = toset(local.win_source_builds)
  ami      = data.aws_ami.win_amis[regex("[a-z0-9]+", each.key)].id # in case of multiples, regex removes # to find ami (e.g., rhel7-01 becomes rhel7)

  associate_public_ip_address = var.assign_public_ip
  iam_instance_profile        = var.instance_profile
  instance_type               = var.win_instance_type
  key_name                    = aws_key_pair.auth.id
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = aws_security_group.winrm_sg.*.id

  user_data = format(
    "<powershell>%s</powershell>",
    templatefile(
      "templates/win_userdata.ps1",
      merge(
        local.common_template_vars,
        local.win_template_vars,
        {
          build_os   = each.key
          build_type = "source"
        }
      )
    )
  )

  tags = {
    Name      = "${local.resource_name}-win_source-${each.key}"
    BuilderID = "None (from source)"
  }

  timeouts {
    create = "85m"
  }

  connection {
    type     = "winrm"
    host     = self.public_ip
    user     = var.rm_user
    password = join("", random_string.password.*.result)
    timeout  = "75m"
  }

  provisioner "file" {
    content = templatefile("templates/win_test.ps1", {
      build_os             = each.key
      build_type           = "source"
      userdata_status_file = local.win_userdata_status_file
      standalone_path      = local.win_download_dir
    })
    destination = "C:\\scripts\\watchmaker-test-win_source-${each.key}.ps1"
  }

  provisioner "remote-exec" {
    inline = [
      "powershell.exe -File C:\\scripts\\watchmaker-test-win_source-${each.key}.ps1",
    ]

    connection {
      host = coalesce(self.public_ip, self.private_ip)
      type = "winrm"
      # this is where terraform puts the above mini inline script
      script_path = "C:\\scripts\\inline-win_source-${each.key}.cmd"
    }
  }
}

resource "aws_instance" "win_standalone" {
  for_each = toset(local.win_standalone_builds)
  ami      = data.aws_ami.win_amis[regex("[a-z0-9]+", each.key)].id # in case of multiples, regex removes # to find ami (e.g., rhel7-01 becomes rhel7)

  associate_public_ip_address = var.assign_public_ip
  iam_instance_profile        = var.instance_profile
  instance_type               = var.win_instance_type
  key_name                    = aws_key_pair.auth.id
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = aws_security_group.winrm_sg.*.id

  user_data = format(
    "<powershell>%s</powershell>",
    templatefile(
      "templates/win_userdata.ps1",
      merge(
        local.common_template_vars,
        local.win_template_vars,
        {
          build_os   = each.key
          build_type = "standalone"
        }
      )
    )
  )

  tags = {
    Name      = "${local.resource_name}-win_standalone-${each.key}"
    BuilderID = aws_instance.win_builder[local.win_builder_needed[0]].id
  }

  timeouts {
    create = "85m"
  }

  connection {
    type     = "winrm"
    host     = self.public_ip
    user     = var.rm_user
    password = join("", random_string.password.*.result)
    timeout  = "75m"
  }

  provisioner "file" {
    content = templatefile("templates/win_test.ps1", {
      build_os             = each.key
      build_type           = "standalone"
      standalone_path      = local.win_download_dir
      userdata_status_file = local.win_userdata_status_file
    })
    destination = "C:\\scripts\\watchmaker-test-win_standalone-${each.key}.ps1"
  }

  provisioner "remote-exec" {
    inline = [
      "powershell.exe -File C:\\scripts\\watchmaker-test-win_standalone-${each.key}.ps1",
    ]

    connection {
      host = coalesce(self.public_ip, self.private_ip)
      type = "winrm"
      # this is where terraform puts the above mini inline script
      script_path = "C:\\scripts\\inline-win_standalone-${each.key}.cmd"
    }
  }
}

resource "aws_instance" "lx_builder" {
  for_each = toset(local.lx_builder_needed)
  ami      = data.aws_ami.lx_amis[each.key].id

  associate_public_ip_address = var.assign_public_ip
  iam_instance_profile        = var.instance_profile
  instance_type               = local.lx_builder_instance_type
  key_name                    = aws_key_pair.auth.id
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = aws_security_group.ssh_sg.*.id

  user_data = templatefile(
    "templates/lx_userdata.sh",
    merge(
      local.common_template_vars,
      local.lx_template_vars,
      {
        build_os   = each.key
        build_type = "builder"
      }
    )
  )

  tags = {
    Name = "${local.resource_name}-lx_builder-${each.key}"
  }

  timeouts {
    create = "30m"
  }

  connection {
    type        = "ssh"
    host        = self.public_ip
    user        = local.lx_builder_user
    private_key = tls_private_key.gen_key.private_key_pem
    port        = local.ssh_port
    timeout     = "30m"
  }

  provisioner "file" {
    content = templatefile("templates/lx_test.sh", {
      build_os             = each.key
      build_type           = "builder"
      userdata_status_file = local.lx_userdata_status_file
    })
    destination = "~/watchmaker-test-lx_builder-${each.key}.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x ~/watchmaker-test-lx_builder-${each.key}.sh",
      "~/watchmaker-test-lx_builder-${each.key}.sh",
    ]

    connection {
      host = coalesce(self.public_ip, self.private_ip)
      type = "ssh"
      # this is where terraform puts the above mini inline script
      script_path = "~/inline-lx_builder-${each.key}.sh"
    }
  }
}

resource "aws_instance" "lx_source" {
  for_each = toset(local.lx_source_builds)
  ami      = data.aws_ami.lx_amis[regex("[a-z0-9]+", each.key)].id # in case of multiples, regex removes # to find ami (e.g., rhel7-01 becomes rhel7)

  associate_public_ip_address = var.assign_public_ip
  iam_instance_profile        = var.instance_profile
  instance_type               = var.lx_instance_type
  key_name                    = aws_key_pair.auth.id
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = aws_security_group.ssh_sg.*.id

  user_data = templatefile(
    "templates/lx_userdata.sh",
    merge(
      local.common_template_vars,
      local.lx_template_vars,
      {
        build_os   = each.key
        build_type = "source"
      }
    )
  )

  tags = {
    Name      = "${local.resource_name}-lx_source-${each.key}"
    BuilderID = "None (from source)"
  }

  timeouts {
    create = "50m"
  }

  connection {
    type        = "ssh"
    host        = self.public_ip
    user        = var.ssh_user
    private_key = tls_private_key.gen_key.private_key_pem
    port        = local.ssh_port
    timeout     = "40m"
  }

  provisioner "file" {
    content = templatefile("templates/lx_test.sh", {
      build_os             = each.key
      build_type           = "source"
      userdata_status_file = local.lx_userdata_status_file
    })
    destination = "~/watchmaker-test-lx_source-${each.key}.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x ~/watchmaker-test-lx_source-${each.key}.sh",
      "~/watchmaker-test-lx_source-${each.key}.sh",
    ]

    connection {
      host = coalesce(self.public_ip, self.private_ip)
      type = "ssh"
      # this is where terraform puts the above mini inline script
      script_path = "~/inline-lx_source-${each.key}.sh"
    }
  }
}

resource "aws_instance" "lx_standalone" {
  for_each = toset(local.lx_standalone_builds)
  ami      = data.aws_ami.lx_amis[regex("[a-z0-9]+", each.key)].id # in case of multiples, regex removes "-01" to find ami (e.g., rhel7-01 becomes rhel7)

  associate_public_ip_address = var.assign_public_ip
  iam_instance_profile        = var.instance_profile
  instance_type               = var.lx_instance_type
  key_name                    = aws_key_pair.auth.id
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = aws_security_group.ssh_sg.*.id

  user_data = templatefile(
    "templates/lx_userdata.sh",
    merge(
      local.common_template_vars,
      local.lx_template_vars,
      {
        build_os   = each.key
        build_type = "standalone"
      }
    )
  )

  tags = {
    Name      = "${local.resource_name}-lx_standalone-${each.key}"
    BuilderID = aws_instance.lx_builder[local.lx_builder_needed[0]].id
  }

  timeouts {
    create = "50m"
  }

  connection {
    type        = "ssh"
    host        = self.public_ip
    user        = var.ssh_user
    private_key = tls_private_key.gen_key.private_key_pem
    port        = local.ssh_port
    timeout     = "40m"
  }

  provisioner "file" {
    content = templatefile("templates/lx_test.sh", {
      build_os             = each.key
      build_type           = "standalone"
      userdata_status_file = local.lx_userdata_status_file
    })
    destination = "~/watchmaker-test-lx_standalone-${each.key}.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x ~/watchmaker-test-lx_standalone-${each.key}.sh",
      "~/watchmaker-test-lx_standalone-${each.key}.sh",
    ]

    connection {
      host = coalesce(self.public_ip, self.private_ip)
      type = "ssh"
      # this is where terraform puts the above mini inline script
      script_path = "~/inline-lx_standalone-${each.key}.sh"
    }
  }
}
