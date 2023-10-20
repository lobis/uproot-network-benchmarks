resource "aws_key_pair" "local_key" {
  key_name   = "local_key"
  public_key = file("~/.ssh/id_rsa.pub") # Replace with the path to your public key file
}

# security group for ssh access
resource "aws_security_group" "ssh_access" {
  name        = "Allow SSH access"
  description = "Allow SSH access"
  vpc_id      = aws_vpc.main.id

  # Allow SSH access from your computer's IP address
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # -1 indicates all protocols
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "file_server" {
  name        = "File Server"
  description = "File Server"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# EC2 instance
resource "aws_instance" "file_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"

  vpc_security_group_ids = [aws_security_group.ssh_access.id]
  subnet_id              = aws_subnet.web_A.id

  associate_public_ip_address = true

  key_name = aws_key_pair.local_key.key_name

  user_data = <<-EOF
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
HOME=/home/ubuntu # user_data is run as root, so we need to switch to ec2-user
sudo apt-get update
sudo apt-get install -y git wget
git clone https://github.com/lobis/uproot-network-benchmarks.git $HOME/uproot-network-benchmarks
echo "Installing ROOT"
sudo apt-get install -y dpkg-dev cmake g++ gcc binutils libx11-dev libxpm-dev libxft-dev libxext-dev python3 python-is-python3 libssl-dev
ROOT_TAR="root_v6.28.06.Linux-ubuntu22-x86_64-gcc11.4.tar.gz"
wget https://root.cern/download/$ROOT_TAR -O /tmp/$ROOT_TAR
sudo tar -C /usr/local -xzf /tmp/$ROOT_TAR && rm -rf /tmp/$ROOT_TAR
echo "source /usr/local/root/bin/thisroot.sh" >> $HOME/.bashrc
source $HOME/.bashrc
cd $HOME/uproot-network-benchmarks
root -q 'make_tree.C(100000, "files/tree.root", "Events")'
echo "Done!"
EOF

  tags = {
    Name = "Benchmarks File Server"
  }
}

# ssh ec2-user@$(terraform output -raw file_server_instance_dns)
output "file_server_instance_dns" {
  value = aws_instance.file_server.public_dns
}
