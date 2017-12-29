provider "aws" {}

resource "aws_key_pair" "auth" {
  key_name   = "${var.key_pair_name}"
  public_key = "${var.public_key}"
}

# Security group to access the instances over WinRM
resource "aws_security_group" "terrafirm" {
  name        = "terrafirm_sg"
  description = "Used in terrafirm"

  # SSH access from anywhere
  ingress {
    from_port   = 5986
    to_port     = 5986
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "windows" {
  ami = "${var.ami}"
  instance_type = "t2.micro"
  key_name = "${aws_key_pair.auth.id}"
  vpc_security_group_ids = ["${aws_security_group.terrafirm.id}"]
  user_data = <<USERDATA
<powershell>
$BootstrapUrl = "https://raw.githubusercontent.com/plus3it/watchmaker/master/docs/files/bootstrap/watchmaker-bootstrap.ps1"
$PythonUrl = "https://www.python.org/ftp/python/3.6.3/python-3.6.3-amd64.exe"
$PypiUrl = "https://pypi.org/simple"

# Download bootstrap file
$BootstrapFile = "${Env:Temp}\$(${BootstrapUrl}.split('/')[-1])"
(New-Object System.Net.WebClient).DownloadFile("$BootstrapUrl", "$BootstrapFile")

# Install python
& "$BootstrapFile" -PythonUrl "$PythonUrl" -Verbose -ErrorAction Stop

# Install watchmaker
pip install --index-url="$PypiUrl" --upgrade pip setuptools watchmaker

# Run watchmaker
watchmaker --log-level debug --log-dir=C:\Watchmaker\Logs
</powershell>
USERDATA
  
  timeouts {
    create = "30m"
    delete = "30m"
  }
  
  connection {
    #winrm connection to tier-2 instance
    user     = "${var.ssh_user}"
    private_key = "${var.private_key}"
    timeout   = "3m"
    type     = "winrm"
  }
  
  
  provisioner "remote-exec" {
    script = "watchmaker_test.bat"
  }
}
