# various settings used by the instances
locals {
  pypi_url       = "https://pypi.org/simple"
  release_prefix = "release"

  lx_builder_instance_type  = "t2.large"
  win_builder_instance_type = "t2.xlarge"

  lx_sa_error_signal_file  = "${local.release_prefix}/lx_standalone_error_signal.log"
  win_sa_error_signal_file = "${local.release_prefix}/win_standalone_error_signal.log"

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
  date_ymd      = "${substr(data.null_data_source.start_time.inputs.tfi_timestamp, 0, 4)}${substr(data.null_data_source.start_time.inputs.tfi_timestamp, 5, 2)}${substr(data.null_data_source.start_time.inputs.tfi_timestamp, 8, 2)}" #equivalent of $(date +'%Y%m%d')
  date_hm       = "${substr(data.null_data_source.start_time.inputs.tfi_timestamp, 11, 2)}${substr(data.null_data_source.start_time.inputs.tfi_timestamp, 14, 2)}"                                                                     #equivalent of $(date +'%H%M')
  full_build_id = var.tfi_codebuild_id == "" ? format("notcb:%s", uuid()) : var.tfi_codebuild_id                                                                                                                                       #128-bit rfc 4122 v4 UUID
  build_id      = "${substr(element(split(":", local.full_build_id), 1), 0, 8)}${substr(element(split(":", local.full_build_id), 1), 9, 4)}"                                                                                           #extract node portion of uuid (last 6 octets) for brevity
  resource_name = "${local.name_prefix}-${local.build_id}"
  build_slug    = "${var.tfi_s3_bucket}/${local.date_ymd}/${local.date_hm}-${local.build_id}"

  # amis
  win_ami_find = {
    win12 = {
      search = "Windows_Server-2012-R2_RTM-English-64Bit-Base*"
    }

    win16 = {
      search = "Windows_Server-2016-English-Full-Base*"
    }

    win19 = {
      search = "Windows_Server-2019-English-Full-Base*"
    }
  }

  lx_ami_find = {
    centos6 = {
      search = "spel-minimal-centos-6-hvm-*.x86_64-gp2"
      regex  = "spel-minimal-centos-6-hvm-\\d{4}\\.\\d{2}\\.\\d{1}\\.x86_64-gp2"
    }

    centos7 = {
      search = "spel-minimal-centos-7-hvm-*.x86_64-gp2"
      regex  = "spel-minimal-centos-7-hvm-\\d{4}\\.\\d{2}\\.\\d{1}\\.x86_64-gp2"
    }

    rhel6 = {
      search = "spel-minimal-rhel-6-hvm-*.x86_64-gp2"
      regex  = "spel-minimal-rhel-6-hvm-\\d{4}\\.\\d{2}\\.\\d{1}\\.x86_64-gp2"
    }

    rhel7 = {
      search = "spel-minimal-rhel-7-hvm-*.x86_64-gp2"
      regex  = "spel-minimal-rhel-7-hvm-\\d{4}\\.\\d{2}\\.\\d{1}\\.x86_64-gp2"
    }

    xenial = {
      search = "ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server*"
      regex  = ""
    }
  }

  ami_settings = {
    owners              = ["701759196663", "099720109477", "801119661308"]
    virtualization_type = "hvm"
  }

  user_requests = sort(var.tfi_instances)

  win_src_requests    = [for k, v in local.win_ami_find : k if contains(local.user_requests, format("win_src-%s", k))]
  win_sa_requests     = [for k, v in local.win_ami_find : k if contains(local.user_requests, format("win_sa-%s", k))]
  win_builder_request = length(local.win_sa_requests) > 0 ? ["win12"] : []
  win_all_requests    = toset(concat(local.win_src_requests, local.win_sa_requests, local.win_builder_request))
  win_any_request     = length(local.win_all_requests) > 0 ? 1 : 0
  win_src_expanded    = var.tfi_instance_multiplier > 1 ? [for i in setproduct(local.win_src_requests, range(1, var.tfi_instance_multiplier + 1)) : format("%s-%02d", i[0], i[1])] : local.win_src_requests
  win_sa_expanded     = var.tfi_instance_multiplier > 1 ? [for i in setproduct(local.win_sa_requests, range(1, var.tfi_instance_multiplier + 1)) : format("%s-%02d", i[0], i[1])] : local.win_sa_requests

  lx_src_requests    = [for k, v in local.lx_ami_find : k if contains(local.user_requests, format("lx_src-%s", k))]
  lx_sa_requests     = [for k, v in local.lx_ami_find : k if contains(local.user_requests, format("lx_sa-%s", k))]
  lx_builder_request = length(local.lx_sa_requests) > 0 ? ["xenial"] : []
  lx_all_requests    = toset(concat(local.lx_src_requests, local.lx_sa_requests, local.lx_builder_request))
  lx_any_request     = length(local.lx_all_requests) > 0 ? 1 : 0
  lx_src_expanded    = var.tfi_instance_multiplier > 1 ? [for i in setproduct(local.lx_src_requests, range(1, var.tfi_instance_multiplier + 1)) : format("%s-%02d", i[0], i[1])] : local.lx_src_requests
  lx_sa_expanded     = var.tfi_instance_multiplier > 1 ? [for i in setproduct(local.lx_sa_requests, range(1, var.tfi_instance_multiplier + 1)) : format("%s-%02d", i[0], i[1])] : local.lx_sa_requests
}

data "null_data_source" "start_time" {
  inputs = {
    # necessary because if you just call timestamp in a local it re-evaluates it everytime that var is read
    tfi_timestamp = timestamp()
  }
}

data "aws_ami" "win_amis" {
  for_each    = local.win_all_requests
  most_recent = true

  filter {
    name   = "virtualization-type"
    values = [local.ami_settings.virtualization_type]
  }

  filter {
    name   = "name"
    values = [local.win_ami_find[each.key].search]
  }

  owners = local.ami_settings.owners
}

data "aws_ami" "lx_amis" {
  for_each    = local.lx_all_requests
  most_recent = true

  name_regex = local.lx_ami_find[each.key].regex

  filter {
    name   = "virtualization-type"
    values = [local.ami_settings.virtualization_type]
  }

  filter {
    name   = "name"
    values = [local.lx_ami_find[each.key].search]
  }

  owners = local.ami_settings.owners
}

data "aws_subnet" "tfi" {
  id = var.tfi_subnet_id == "" ? aws_default_subnet.tfi.id : var.tfi_subnet_id
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
  count            = local.win_any_request
  length           = 18
  special          = true
  override_special = "()~!@#^*+=|{}[]:;,?"
}

resource "aws_default_subnet" "tfi" {
  availability_zone = var.tfi_az
}

resource "aws_security_group" "winrm_sg" {
  count       = local.win_any_request
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
  count       = local.lx_any_request # only create if any lx instances
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

resource "aws_instance" "win_builder" {
  for_each = toset(local.win_builder_request)
  ami      = data.aws_ami.win_amis[each.key].id

  associate_public_ip_address = var.tfi_assign_public_ip
  iam_instance_profile        = var.tfi_instance_profile
  instance_type               = local.win_builder_instance_type
  key_name                    = aws_key_pair.auth.id
  subnet_id                   = var.tfi_subnet_id
  vpc_security_group_ids      = aws_security_group.winrm_sg.*.id

  user_data = format("<powershell>%s</powershell>", templatefile("templates/win_userdata.ps1", {
    bootstrap_url        = local.win_bootstrap_url
    build_slug           = local.build_slug
    common_args          = var.tfi_common_args
    debug                = var.tfi_debug
    download_dir         = local.win_download_dir
    sa_error_signal_file = local.win_sa_error_signal_file
    executable           = local.win_executable
    git_ref              = var.tfi_git_ref
    git_repo             = var.tfi_git_repo
    git_url              = local.win_git_url
    instance_os          = each.key
    instance_type        = "builder"
    pypi_url             = local.pypi_url
    python_url           = local.win_python_url
    release_prefix       = local.release_prefix
    rm_pass              = random_string.password[0].result
    rm_user              = var.tfi_rm_user
    seven_zip_url        = local.win_7zip_url
    temp_dir             = local.win_temp_dir
    userdata_log         = var.tfi_win_userdata_log
    userdata_status_file = local.win_userdata_status_file
    win_args             = var.tfi_win_args
  }))

  tags = {
    Name = "${local.resource_name}-win_builder-${each.key}"
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
    content = templatefile("templates/win_test.ps1", {
      instance_os          = each.key
      instance_type        = "builder"
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

resource "aws_instance" "win_src" {
  for_each = toset(local.win_src_expanded)
  ami      = data.aws_ami.win_amis[regex("[a-z0-9]+", each.key)].id   # in case of multiples, regex removes # to find ami (e.g., rhel7-01 becomes rhel7)

  associate_public_ip_address = var.tfi_assign_public_ip
  iam_instance_profile        = var.tfi_instance_profile
  instance_type               = var.tfi_win_instance_type
  key_name                    = aws_key_pair.auth.id
  subnet_id                   = var.tfi_subnet_id
  vpc_security_group_ids      = aws_security_group.winrm_sg.*.id

  user_data = format("<powershell>%s</powershell>", templatefile("templates/win_userdata.ps1", {
    bootstrap_url        = local.win_bootstrap_url
    build_slug           = local.build_slug
    common_args          = var.tfi_common_args
    debug                = var.tfi_debug
    download_dir         = local.win_download_dir
    sa_error_signal_file = local.win_sa_error_signal_file
    executable           = local.win_executable
    git_ref              = var.tfi_git_ref
    git_repo             = var.tfi_git_repo
    git_url              = local.win_git_url
    instance_os          = each.key
    instance_type        = "src"
    pypi_url             = local.pypi_url
    python_url           = local.win_python_url
    release_prefix       = local.release_prefix
    rm_pass              = random_string.password[0].result
    rm_user              = var.tfi_rm_user
    seven_zip_url        = local.win_7zip_url
    temp_dir             = local.win_temp_dir
    userdata_log         = var.tfi_win_userdata_log
    userdata_status_file = local.win_userdata_status_file
    win_args             = var.tfi_win_args
  }))

  tags = {
    Name      = "${local.resource_name}-win_src-${each.key}"
    BuilderID = "None (from source)"
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
    content = templatefile("templates/win_test.ps1", {
      instance_os          = each.key
      instance_type        = "src"
      userdata_status_file = local.win_userdata_status_file
      standalone_path      = local.win_download_dir
    })
    destination = "C:\\scripts\\watchmaker-test-win_src-${each.key}.ps1"
  }

  provisioner "remote-exec" {
    inline = [
      "powershell.exe -File C:\\scripts\\watchmaker-test-win_src-${each.key}.ps1",
    ]

    connection {
      host = coalesce(self.public_ip, self.private_ip)
      type = "winrm"
      # this is where terraform puts the above mini inline script
      script_path = "C:\\scripts\\inline-win_src-${each.key}.cmd"
    }
  }
}

resource "aws_instance" "win_sa" {
  for_each = toset(local.win_sa_expanded)
  ami      = data.aws_ami.win_amis[regex("[a-z0-9]+", each.key)].id   # in case of multiples, regex removes # to find ami (e.g., rhel7-01 becomes rhel7)

  associate_public_ip_address = var.tfi_assign_public_ip
  iam_instance_profile        = var.tfi_instance_profile
  instance_type               = var.tfi_win_instance_type
  key_name                    = aws_key_pair.auth.id
  subnet_id                   = var.tfi_subnet_id
  vpc_security_group_ids      = aws_security_group.winrm_sg.*.id

  user_data = format("<powershell>%s</powershell>", templatefile("templates/win_userdata.ps1", {
    bootstrap_url        = local.win_bootstrap_url
    build_slug           = local.build_slug
    common_args          = var.tfi_common_args
    debug                = var.tfi_debug
    download_dir         = local.win_download_dir
    sa_error_signal_file = local.win_sa_error_signal_file
    executable           = local.win_executable
    git_ref              = var.tfi_git_ref
    git_repo             = var.tfi_git_repo
    git_url              = local.win_git_url
    instance_os          = each.key
    instance_type        = "sa"
    pypi_url             = local.pypi_url
    python_url           = local.win_python_url
    release_prefix       = local.release_prefix
    rm_pass              = random_string.password[0].result
    rm_user              = var.tfi_rm_user
    seven_zip_url        = local.win_7zip_url
    temp_dir             = local.win_temp_dir
    userdata_log         = var.tfi_win_userdata_log
    userdata_status_file = local.win_userdata_status_file
    win_args             = var.tfi_win_args
  }))

  tags = {
    Name      = "${local.resource_name}-win_sa-${each.key}"
    BuilderID = aws_instance.win_builder[local.win_builder_request[0]].id
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
    content = templatefile("templates/win_test.ps1", {
      instance_os          = each.key
      instance_type        = "sa"
      standalone_path      = local.win_download_dir
      userdata_status_file = local.win_userdata_status_file
    })
    destination = "C:\\scripts\\watchmaker-test-win_sa-${each.key}.ps1"
  }

  provisioner "remote-exec" {
    inline = [
      "powershell.exe -File C:\\scripts\\watchmaker-test-win_sa-${each.key}.ps1",
    ]

    connection {
      host = coalesce(self.public_ip, self.private_ip)
      type = "winrm"
      # this is where terraform puts the above mini inline script
      script_path = "C:\\scripts\\inline-win_sa-${each.key}.cmd"
    }
  }
}

resource "aws_instance" "lx_builder" {
  for_each = toset(local.lx_builder_request)
  ami      = data.aws_ami.lx_amis[each.key].id

  associate_public_ip_address = var.tfi_assign_public_ip
  iam_instance_profile        = var.tfi_instance_profile
  instance_type               = local.lx_builder_instance_type
  key_name                    = aws_key_pair.auth.id
  subnet_id                   = var.tfi_subnet_id
  vpc_security_group_ids      = aws_security_group.ssh_sg.*.id

  user_data = templatefile("templates/lx_userdata.sh", {
    aws_region           = var.tfi_aws_region
    build_slug           = local.build_slug
    common_args          = var.tfi_common_args
    debug                = var.tfi_debug
    docker_slug          = var.tfi_docker_slug
    sa_error_signal_file = local.lx_sa_error_signal_file
    executable           = local.lx_executable
    git_ref              = var.tfi_git_ref
    git_repo             = var.tfi_git_repo
    instance_os          = each.key
    instance_type        = "builder"
    lx_args              = var.tfi_lx_args
    pypi_url             = local.pypi_url
    release_prefix       = local.release_prefix
    ssh_port             = local.ssh_port
    temp_dir             = local.lx_temp_dir
    userdata_log         = var.tfi_lx_userdata_log
    userdata_status_file = local.lx_userdata_status_file
  })

  tags = {
    Name = "${local.resource_name}-lx_builder-${each.key}"
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
    content = templatefile("templates/lx_test.sh", {
      instance_os          = each.key
      instance_type        = "builder"
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

resource "aws_instance" "lx_src" {
  for_each = toset(local.lx_src_expanded)
  ami      = data.aws_ami.lx_amis[regex("[a-z0-9]+", each.key)].id   # in case of multiples, regex removes # to find ami (e.g., rhel7-01 becomes rhel7)

  associate_public_ip_address = var.tfi_assign_public_ip
  iam_instance_profile        = var.tfi_instance_profile
  instance_type               = var.tfi_lx_instance_type
  key_name                    = aws_key_pair.auth.id
  subnet_id                   = var.tfi_subnet_id
  vpc_security_group_ids      = aws_security_group.ssh_sg.*.id

  user_data = templatefile("templates/lx_userdata.sh", {
    aws_region           = var.tfi_aws_region
    build_slug           = local.build_slug
    common_args          = var.tfi_common_args
    debug                = var.tfi_debug
    docker_slug          = var.tfi_docker_slug
    sa_error_signal_file = local.lx_sa_error_signal_file
    executable           = local.lx_executable
    git_ref              = var.tfi_git_ref
    git_repo             = var.tfi_git_repo
    instance_os          = each.key
    instance_type        = "src"
    lx_args              = var.tfi_lx_args
    pypi_url             = local.pypi_url
    release_prefix       = local.release_prefix
    ssh_port             = local.ssh_port
    temp_dir             = local.lx_temp_dir
    userdata_log         = var.tfi_lx_userdata_log
    userdata_status_file = local.lx_userdata_status_file
  })

  tags = {
    Name      = "${local.resource_name}-lx_src-${each.key}"
    BuilderID = "None (from source)"
  }

  timeouts {
    create = "50m"
  }

  connection {
    type        = "ssh"
    host        = self.public_ip
    user        = var.tfi_ssh_user
    private_key = tls_private_key.gen_key.private_key_pem
    port        = local.ssh_port
    timeout     = "40m"
  }

  provisioner "file" {
    content = templatefile("templates/lx_test.sh", {
      instance_os          = each.key
      instance_type        = "src"
      userdata_status_file = local.lx_userdata_status_file
    })
    destination = "~/watchmaker-test-lx_src-${each.key}.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x ~/watchmaker-test-lx_src-${each.key}.sh",
      "~/watchmaker-test-lx_src-${each.key}.sh",
    ]

    connection {
      host = coalesce(self.public_ip, self.private_ip)
      type = "ssh"
      # this is where terraform puts the above mini inline script
      script_path = "~/inline-lx_src-${each.key}.sh"
    }
  }
}

resource "aws_instance" "lx_sa" {
  for_each = toset(local.lx_sa_expanded)
  ami      = data.aws_ami.lx_amis[regex("[a-z0-9]+", each.key)].id   # in case of multiples, regex removes # to find ami (e.g., rhel7-01 becomes rhel7)

  associate_public_ip_address = var.tfi_assign_public_ip
  iam_instance_profile        = var.tfi_instance_profile
  instance_type               = var.tfi_lx_instance_type
  key_name                    = aws_key_pair.auth.id
  subnet_id                   = var.tfi_subnet_id
  vpc_security_group_ids      = aws_security_group.ssh_sg.*.id

  user_data = templatefile("templates/lx_userdata.sh", {
    aws_region           = var.tfi_aws_region
    build_slug           = local.build_slug
    common_args          = var.tfi_common_args
    debug                = var.tfi_debug
    docker_slug          = var.tfi_docker_slug
    sa_error_signal_file = local.lx_sa_error_signal_file
    executable           = local.lx_executable
    git_ref              = var.tfi_git_ref
    git_repo             = var.tfi_git_repo
    instance_os          = each.key
    instance_type        = "sa"
    lx_args              = var.tfi_lx_args
    pypi_url             = local.pypi_url
    release_prefix       = local.release_prefix
    ssh_port             = local.ssh_port
    temp_dir             = local.lx_temp_dir
    userdata_log         = var.tfi_lx_userdata_log
    userdata_status_file = local.lx_userdata_status_file
  })

  tags = {
    Name      = "${local.resource_name}-lx_sa-${each.key}"
    BuilderID = aws_instance.lx_builder[local.lx_builder_request[0]].id
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
    content = templatefile("templates/lx_test.sh", {
      instance_os          = each.key
      instance_type        = "sa"
      userdata_status_file = local.lx_userdata_status_file
    })
    destination = "~/watchmaker-test-lx_sa-${each.key}.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x ~/watchmaker-test-lx_sa-${each.key}.sh",
      "~/watchmaker-test-lx_sa-${each.key}.sh",
    ]

    connection {
      host = coalesce(self.public_ip, self.private_ip)
      type = "ssh"
      # this is where terraform puts the above mini inline script
      script_path = "~/inline-lx_sa-${each.key}.sh"
    }
  }
}
