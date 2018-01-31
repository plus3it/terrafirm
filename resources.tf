
#used for importing the key pair created using aws cli
resource "aws_key_pair" "auth" {
  key_name   = "${var.tfi_key_pair_name}"
  public_key = "${var.tfi_public_key}"
}

# Security group to access the instances over WinRM
resource "aws_security_group" "terrafirm_winrm" {
  name        = "${var.tfi_win_security_grp}"
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
  name        = "${var.tfi_lx_security_grp}"
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

# bread & butter - this tells TF the provision/create the actual instance
resource "aws_instance" "spels" {
  count                        = "${length(matchkeys(values(data.null_data_source.spel_instance_amis.inputs),keys(data.null_data_source.spel_instance_amis.inputs),split(",", var.tfi_lx_instances)))}"
  ami                          = "${element(matchkeys(values(data.null_data_source.spel_instance_amis.inputs),keys(data.null_data_source.spel_instance_amis.inputs),split(",", var.tfi_lx_instances)), count.index)}"
  instance_type                = "${var.tfi_lx_instance_type}"
  iam_instance_profile         = "${var.tfi_instance_profile}"
  key_name                     = "${aws_key_pair.auth.id}"
  vpc_security_group_ids       = ["${aws_security_group.terrafirm_ssh.id}"]
  user_data                    = "${data.template_file.lx_userdata.rendered}"
  associate_public_ip_address  = "${var.tfi_assign_public_ip}"
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
      "while [ ! -f /tmp/SETUP_COMPLETE_SIGNAL ]; do echo \"scale=0; $(($(wc -c < ${var.tfi_lx_userdata_log})<57046?$(wc -c < ${var.tfi_lx_userdata_log}):57046))*100/57046\" | bc | awk '{printf \"%d%% done\", $0}' ; sleep 10 ; done",
      "chmod +x ~/watchmaker_test.sh",
      "~/watchmaker_test.sh",
    ]
  }  
}

# bread & butter - this tells TF the provision/create the actual instance
resource "aws_instance" "windows" {
  count                        = "${length(matchkeys(values(data.null_data_source.windows_instance_amis.inputs),keys(data.null_data_source.windows_instance_amis.inputs),split(",", var.tfi_win_instances)))}"
  ami                          = "${element(matchkeys(values(data.null_data_source.windows_instance_amis.inputs),keys(data.null_data_source.windows_instance_amis.inputs),split(",", var.tfi_win_instances)), count.index)}"  
  instance_type                = "${var.tfi_win_instance_type}"
  key_name                     = "${aws_key_pair.auth.id}"
  iam_instance_profile         = "${var.tfi_instance_profile}"
  vpc_security_group_ids       = ["${aws_security_group.terrafirm_winrm.id}"]
  user_data                    = "${data.template_file.win_userdata.rendered}"
  associate_public_ip_address  = "${var.tfi_assign_public_ip}"
  subnet_id                    = "${var.tfi_subnet_id}"
  
  timeouts {
    create = "120m"
    delete = "120m"
  }
  
  connection {
    type     = "winrm"
    user     = "${var.tfi_rm_user}"
    password = "${var.tfi_rm_pass}"
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
