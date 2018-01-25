provider "aws" {
  region     = "${var.tfi_region}"
}

#used for importing the key pair created using aws cli
resource "aws_key_pair" "auth" {
  key_name   = "${var.tfi_key_pair_name}"
  public_key = "${var.tfi_public_key}"
}

# Security group to access the instances over WinRM
resource "aws_security_group" "terrafirm_winrm" {
  name        = "${var.tfi_win_security_group}"
  description = "Used in terrafirm"
  vpc_id      = "${var.tfi_vpc_id}"

  # SSH access from anywhere
  ingress {
    from_port   = 5985
    to_port     = 5986
    protocol    = "tcp"
    cidr_blocks = ["${var.tfi_cb_ip}/32"]
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
resource "aws_security_group" "terrafirm_ssh" {
  name        = "${var.tfi_lx_security_group}"
  description = "Used in terrafirm"
  vpc_id      = "${var.tfi_vpc_id}"
  
  # SSH access 
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.tfi_cb_ip}/32"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#owners of canonical centos, rhel, linux amis
variable "tfi_linux_ami_owners" {
  default = ["701759196663", "self", "125523088429", "099720109477"]
}

#owners of canonical windows amis (basically Amazon)
variable "tfi_windows_ami_owners" {
  default = ["801119661308", "amazon"]
}

#these are just strings that are used by aws_ami data resources to find amis 
variable "tfi_ami_name_filters" {
  default = [
    "spel-minimal-centos-6*",
    "spel-minimal-centos-7*",
    "spel-minimal-rhel-6*",
    "spel-minimal-rhel-7*",
    "Windows_Server-2008-R2_SP1-English-64Bit-Base*",
    "Windows_Server-2016-English-Full-Base*",
    "Windows_Server-2012-R2_RTM-English-64Bit-Base*",
  ] 
}

# Template for initial configuration bash script
data "template_file" "win_userdata" {
  template = "${file("windows/userdata.ps1")}"

  vars {
    tfi_repo = "${var.tfi_repo}"
    tfi_branch = "${var.tfi_branch}"
    tfi_common_args = "${var.tfi_common_args}"
    tfi_windows_args = "${var.tfi_windows_args}"
    tfi_rm_passwd = "${var.tfi_rm_passwd}"
    tfi_rm_user = "${var.tfi_rm_user}"
    tfi_ssh_user = "${var.tfi_ssh_user}"
  }
}

variable "tfi_other_filters" {
  type  = "map"
  default = {
    virtualization_type = "hvm"
  }
}

#used just to find the ami id matching criteria, which is then used in provisioning resource
data "aws_ami" "centos6" {
  most_recent = true
  
  filter {
    name = "virtualization-type"
    values = ["${var.tfi_other_filters["virtualization_type"]}"]
  }
  
  filter {
    name = "name"
    values = ["${element(var.tfi_ami_name_filters, 0)}"]
  }
  
  owners = "${var.tfi_linux_ami_owners}"
}

#used just to find the ami id matching criteria, which is then used in provisioning resource
data "aws_ami" "centos7" {
  most_recent = true
  
  filter {
    name = "virtualization-type"
    values = ["${var.tfi_other_filters["virtualization_type"]}"]
  }
  
  filter {
    name = "name"
    values = ["${element(var.tfi_ami_name_filters, 1)}"]
  }
  
  owners = "${var.tfi_linux_ami_owners}"
}

#used just to find the ami id matching criteria, which is then used in provisioning resource
data "aws_ami" "rhel6" {
  most_recent = true
  
  filter {
    name = "virtualization-type"
    values = ["${var.tfi_other_filters["virtualization_type"]}"]
  }
  
  filter {
    name = "name"
    values = ["${element(var.tfi_ami_name_filters, 2)}"]
  }
  
  owners = "${var.tfi_linux_ami_owners}"
}

#used just to find the ami id matching criteria, which is then used in provisioning resource
data "aws_ami" "rhel7" {
  most_recent = true
  
  filter {
    name = "virtualization-type"
    values = ["${var.tfi_other_filters["virtualization_type"]}"]
  }
  
  filter {
    name = "name"
    values = ["${element(var.tfi_ami_name_filters, 3)}"]
  }
  
  owners = "${var.tfi_linux_ami_owners}"
}

#used just to find the ami id matching criteria, which is then used in provisioning resource
data "aws_ami" "windows2016" {
  most_recent = true
  
  filter {
    name = "virtualization-type"
    values = ["${var.tfi_other_filters["virtualization_type"]}"]
  }
  
  filter {
    name = "name"
    values = ["${element(var.tfi_ami_name_filters, 4)}"]
  }
  
  owners = "${var.tfi_windows_ami_owners}"
}

#used just to find the ami id matching criteria, which is then used in provisioning resource
data "aws_ami" "windows2012" {
  most_recent = true
  
  filter {
    name = "virtualization-type"
    values = ["${var.tfi_other_filters["virtualization_type"]}"]
  }

  filter {
    name = "name"
    values = ["${element(var.tfi_ami_name_filters, 5)}"]
  }

  owners = "${var.tfi_windows_ami_owners}"
}

#used just to find the ami id matching criteria, which is then used in provisioning resource
data "aws_ami" "windows2008" {
  most_recent = true
  
  filter {
    name = "virtualization-type"
    values = ["${var.tfi_other_filters["virtualization_type"]}"]
  }

  filter {
    name = "name"
    values = ["${element(var.tfi_ami_name_filters, 6)}"]
  }
  
  owners = "${var.tfi_windows_ami_owners}"
}

# data source (place to put the ami id strings), used to mitigate lack of intermediate variables and interpolation
data "null_data_source" "spel_instance_amis" {
  inputs = {
    "0" = "${data.aws_ami.centos6.id}"
    "1" = "${data.aws_ami.centos7.id}"
    "2" = "${data.aws_ami.rhel6.id}"
    "3" = "${data.aws_ami.rhel7.id}"
  }
}

# bread & butter - this tells TF the provision/create the actual instance
resource "aws_instance" "spels" {
  count                        = "${lookup(map("all",length(data.null_data_source.spel_instance_amis.inputs),"one",1,"none",0),var.tfi_lx_all_one_none)}"
  ami                          = "${lookup(data.null_data_source.spel_instance_amis.inputs, count.index)}"
  instance_type                = "${var.tfi_lx_instance_type}"
  iam_instance_profile         = "${var.tfi_instance_profile}"
  key_name                     = "${aws_key_pair.auth.id}"
  vpc_security_group_ids       = ["${aws_security_group.terrafirm_ssh.id}"]
  user_data                    = "${file("linux/userdata.sh")}"
  associate_public_ip_address  = "${var.tfi_associate_public_ip_address}"
  subnet_id                    = "${var.tfi_subnet_id}"
  
  timeouts {
    create = "40m"
    delete = "40m"
  }
  
  connection {
    #ssh connection to tier-2 instance
    user        = "${var.tfi_ssh_user}"
    private_key = "${var.tfi_private_key}"
    timeout     = "30m"
  }
  
  provisioner "file" {
    source      = "linux/watchmaker_test.sh"
    destination = "~/watchmaker_test.sh"
  }
  
  provisioner "remote-exec" {
    inline = [
      "while [ ! -f /tmp/SETUP_COMPLETE_SIGNAL ]; do sleep 2; done",
      "chmod +x ~/watchmaker_test.sh",
      "~/watchmaker_test.sh",
    ]
  }  
}

# data source (place to put the ami id strings), used to mitigate lack of intermediate variables and interpolation
data "null_data_source" "windows_instance_amis" {
  inputs = {
    "0" = "${data.aws_ami.windows2016.id}"
    "1" = "${data.aws_ami.windows2012.id}"
    "2" = "${data.aws_ami.windows2008.id}"
  }
}

# bread & butter - this tells TF the provision/create the actual instance
resource "aws_instance" "windows" {
  count                        = "${lookup(map("all",length(data.null_data_source.windows_instance_amis.inputs),"one",1,"none",0),var.tfi_win_all_one_none)}"
  ami                          = "${lookup(data.null_data_source.windows_instance_amis.inputs, count.index)}"
  instance_type                = "${var.tfi_win_instance_type}"
  key_name                     = "${aws_key_pair.auth.id}"
  iam_instance_profile         = "${var.tfi_instance_profile}"
  vpc_security_group_ids       = ["${aws_security_group.terrafirm_winrm.id}"]
  #user_data                    = "${file("windows/userdata.ps1")}"
  user_data                    = "${data.template_file.win_userdata.rendered}"
  associate_public_ip_address  = "${var.tfi_associate_public_ip_address}"
  subnet_id                    = "${var.tfi_subnet_id}"
  
  timeouts {
    create = "120m"
    delete = "120m"
  }
  
  connection {
    type     = "winrm"
    user     = "${var.tfi_term_user}"
    password = "${var.tfi_term_passwd}"
    timeout   = "30m"
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
