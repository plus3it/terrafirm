provider "aws" {}

#used for importing the key pair created using aws cli
resource "aws_key_pair" "auth" {
  key_name   = "${var.key_pair_name}"
  public_key = "${var.public_key}"
}

# Security group to access the instances over WinRM
resource "aws_security_group" "terrafirm_winrm" {
  name        = "${var.security_group_win}"
  description = "Used in terrafirm"

  # SSH access from anywhere
  ingress {
    from_port   = 5985
    to_port     = 5986
    protocol    = "tcp"
    cidr_blocks = ["${var.cb_ip}/32"]
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
  name        = "${var.security_group_lin}"
  description = "Used in terrafirm"

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.cb_ip}/32"]
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
variable "linux_ami_owners" {
  default = ["701759196663", "self", "125523088429", "099720109477"]
}

#owners of canonical windows amis (basically Amazon)
variable "windows_ami_owners" {
  default = ["801119661308", "amazon"]
}

#these are just strings that are used by aws_ami data resources to find amis 
variable "ami_name_filters" {
  default = [
    "spel-minimal-centos-6*",
    "spel-minimal-centos-7*",
    "spel-minimal-rhel-6*",
    "spel-minimal-rhel-7*",
    "Windows_Server-2016-English-Full-Base*",
    "Windows_Server-2012-R2_RTM-English-64Bit-Base*",
    "Windows_Server-2008-R2_SP1-English-64Bit-Base*",
  ] 
}

variable "other_filters" {
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
    values = ["${var.other_filters["virtualization_type"]}"]
  }
  
  filter {
    name = "name"
    values = ["${element(var.ami_name_filters, 0)}"]
  }
  
  owners = "${var.linux_ami_owners}"
}

#used just to find the ami id matching criteria, which is then used in provisioning resource
data "aws_ami" "centos7" {
  most_recent = true
  
  filter {
    name = "virtualization-type"
    values = ["${var.other_filters["virtualization_type"]}"]
  }
  
  filter {
    name = "name"
    values = ["${element(var.ami_name_filters, 1)}"]
  }
  
  owners = "${var.linux_ami_owners}"
}

#used just to find the ami id matching criteria, which is then used in provisioning resource
data "aws_ami" "rhel6" {
  most_recent = true
  
  filter {
    name = "virtualization-type"
    values = ["${var.other_filters["virtualization_type"]}"]
  }
  
  filter {
    name = "name"
    values = ["${element(var.ami_name_filters, 2)}"]
  }
  
  owners = "${var.linux_ami_owners}"
}

#used just to find the ami id matching criteria, which is then used in provisioning resource
data "aws_ami" "rhel7" {
  most_recent = true
  
  filter {
    name = "virtualization-type"
    values = ["${var.other_filters["virtualization_type"]}"]
  }
  
  filter {
    name = "name"
    values = ["${element(var.ami_name_filters, 3)}"]
  }
  
  owners = "${var.linux_ami_owners}"
}

#used just to find the ami id matching criteria, which is then used in provisioning resource
data "aws_ami" "windows2016" {
  most_recent = true
  
  filter {
    name = "virtualization-type"
    values = ["${var.other_filters["virtualization_type"]}"]
  }
  
  filter {
    name = "name"
    values = ["${element(var.ami_name_filters, 4)}"]
  }
  
  owners = "${var.windows_ami_owners}"
}

#used just to find the ami id matching criteria, which is then used in provisioning resource
data "aws_ami" "windows2012" {
  most_recent = true
  
  filter {
    name = "virtualization-type"
    values = ["${var.other_filters["virtualization_type"]}"]
  }

  filter {
    name = "name"
    values = ["${element(var.ami_name_filters, 5)}"]
  }

  owners = "${var.windows_ami_owners}"
}

#used just to find the ami id matching criteria, which is then used in provisioning resource
data "aws_ami" "windows2008" {
  most_recent = true
  
  filter {
    name = "virtualization-type"
    values = ["${var.other_filters["virtualization_type"]}"]
  }

  filter {
    name = "name"
    values = ["${element(var.ami_name_filters, 6)}"]
  }
  
  owners = "${var.windows_ami_owners}"
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
  count = "0"
  #count = "${length(data.null_data_source.spel_instance_amis.inputs)}"
  ami = "${lookup(data.null_data_source.spel_instance_amis.inputs, count.index)}"
  instance_type = "t2.micro"
  key_name = "${aws_key_pair.auth.id}"
  vpc_security_group_ids = ["${aws_security_group.terrafirm_ssh.id}"]
  user_data = "${file("linux/userdata.sh")}"
  associate_public_ip_address = "${var.associate_public_ip_address}"
  
  timeouts {
    create = "40m"
    delete = "40m"
  }
}

# null resource used to connect to all the linux instances to test them
resource "null_resource" "spels_nr" {
  count = "${aws_instance.spels.count}"
  depends_on = ["aws_instance.spels"]
  
  connection {
    #ssh connection to tier-2 instance
    host     = "${element(aws_instance.spels.*.public_ip, count.index)}"
    user     = "${var.ssh_user}"
    private_key = "${var.private_key}"
    timeout   = "30m"
  }
  
  provisioner "file" {
    source = "linux/watchmaker_test.sh"
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
  count = "1"
  #count = "${length(data.null_data_source.windows_instance_amis.inputs)}"
  ami = "${lookup(data.null_data_source.windows_instance_amis.inputs, count.index)}"
  instance_type = "t2.micro"
  key_name = "${aws_key_pair.auth.id}"
  vpc_security_group_ids = ["${aws_security_group.terrafirm_winrm.id}"]
  user_data = "${file("windows/userdata.ps1")}"
  associate_public_ip_address = "${var.associate_public_ip_address}"  
  
  timeouts {
    create = "120m"
    delete = "120m"
  }
  
  #connection {
  #  #winrm connection to tier-2 instance
  #  type     = "winrm"
  #  user     = "${var.term_user}"
  #  password = "${var.term_passwd}"
  #  timeout   = "30m"
  #  #https    = true
  #}
  
  #provisioner "file" {
  #  source = "windows/watchmaker_test.ps1"
  #  destination = "C:\\scripts\\watchmaker_test.ps1"
  #}

  #provisioner "file" {
  #  source = "windows/block_until_setup.ps1"
  #  destination = "C:\\scripts\\block_until_setup.ps1"
  #}

  #provisioner "file" {
  #  source = "windows/check_block.ps1"
  #  destination = "C:\\scripts\\check_block.ps1"
  #}
  #provisioner "local-exec" {
  #  command = "sleep 10"
  #}
  
  #provisioner "remote-exec" {
  #  script = "windows/run_blocker.bat"
  #}
  
  #provisioner "remote-exec" {
  #  inline = [
  #    #"hostname",
  #    #"while (!(Test-Path 'C:\\tmp\\SIGNAL')) { Write-Host (\"Waiting for server setup to complete...\"); Start-Sleep 20; }",
  #    "powershell.exe -File C:\\scripts\\block_until_setup.ps1",
  #    "powershell.exe -File C:\\scripts\\watchmaker_test.ps1",
  #  ]
  #}
  
}

# null resource used to connect to all the windows instances to test them
resource "null_resource" "windows_nr" {
  count = "${aws_instance.windows.count}"
  depends_on = ["aws_instance.windows"]
  
  connection {
    type     = "winrm"
    host     = "${element(aws_instance.windows.*.public_ip, count.index)}"
    user     = "${var.term_user}"
    password = "${var.term_passwd}"
    timeout   = "30m"
  }
  
  #provisioner "file" {
  #  source = "windows/watchmaker_test.ps1"
  #  destination = "C:\\scripts\\watchmaker_test.ps1"
  #}
  
  #provisioner "file" {
  #  source = "windows/RefreshEnv.cmd"
  #  destination = "C:\\scripts\\RefreshEnv.cmd"
  #}
  
  provisioner "file" {
    source = "windows/accounts.ps1"
    destination = "C:\\scripts\\accounts.ps1"
  }
  
  provisioner "remote-exec" {
    inline = [
      #"powershell C:\\scripts\\accounts.ps1",
      "powershell \"while (!(Test-Path C:\\Temp\\SETUP_COMPLETE_SIGNAL)) { Start-Sleep 10; $admin = [adsi]('WinNT://./administrator, user') ; Write-Host $admin.Name ; }\"",
      #"powershell \"while (!(Test-Path 'C:\\Temp\\SETUP_COMPLETE_SIGNAL')) { Start-Sleep 30; Invoke-Expression -Command:'C:\\scripts\\RefreshEnv.cmd' ; }\"",
      #"powershell C:\\scripts\\watchmaker_test.ps1",
      #"while [ ! -f /tmp/SETUP_COMPLETE_SIGNAL ]; do sleep 2; done",
      #"~/watchmaker_test.sh",
    ]
  }
}
