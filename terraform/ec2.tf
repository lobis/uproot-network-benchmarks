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

  vpc_security_group_ids = [aws_security_group.ssh_access.id, aws_security_group.file_server.id]
  subnet_id              = aws_subnet.web_A.id

  associate_public_ip_address = true

  key_name = aws_key_pair.local_key.key_name

  user_data = <<-EOF
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
USER=ubuntu
HOME=/home/$USER # user_data is run as root, so we need to switch to ec2-user
sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get install -y git wget
git clone https://github.com/lobis/uproot-network-benchmarks.git $HOME/uproot-network-benchmarks
git clone https://github.com/scikit-hep/scikit-hep-testdata.git $HOME/scikit-hep-testdata

echo "Installing ROOT"
sudo apt-get install -y dpkg-dev cmake g++ gcc binutils libx11-dev libxpm-dev libxft-dev libxext-dev python3 python-is-python3 libssl-dev
ROOT_TAR="root_v6.28.06.Linux-ubuntu22-x86_64-gcc11.4.tar.gz"
wget https://root.cern/download/$ROOT_TAR -O /tmp/$ROOT_TAR
sudo tar -C /usr/local -xzf /tmp/$ROOT_TAR && rm -rf /tmp/$ROOT_TAR
echo "source /usr/local/root/bin/thisroot.sh" >> $HOME/.bashrc
source /usr/local/root/bin/thisroot.sh
cd $HOME/uproot-network-benchmarks
mkdir -p files
root -q 'make_tree.C(10000000, "files/tree.root", "Events")'
cd $HOME

echo "Installing nginx"
sudo apt-get install -y nginx nginx-extras
sudo usermod -aG www-data $USER
sudo systemctl start nginx
sudo systemctl enable nginx

# Create an Nginx server block configuration
echo 'server {
    listen       80;
    server_name  localhost;
    root /var/www/files;
    location / {
        try_files $uri $uri/ =404;
        fancyindex on;
        fancyindex_exact_size off;
        fancyindex_localtime on;
    }
    location ~ \.root$ {
        try_files $uri =404;
    }
    location ~ \.(?!root$) {
        deny all;
    }
}' | sudo tee /etc/nginx/sites-available/file_server.conf
sudo rm -f /etc/nginx/sites-enabled/default
sudo ln -s /etc/nginx/sites-available/file_server.conf /etc/nginx/sites-enabled/file_server.conf

# move files to /var/www
sudo mkdir -p /var/www/files/
sudo mv $HOME/uproot-network-benchmarks/files /var/www/files/benchmark
sudo mv $HOME/scikit-hep-testdata/src/skhep_testdata/data /var/www/files/scikit-hep-testdata
ln -s /var/www/files/benchmark/ $HOME/uproot-network-benchmarks/files
ln -s /var/www/files/scikit-hep-testdata/ $HOME/scikit-hep-testdata/src/skhep_testdata/data

echo "Done!"
sudo chown -R $USER:$USER $HOME
sudo chown -R www-data:www-data /var/www
sudo systemctl restart nginx
EOF

  tags = {
    Name = "Benchmarks File Server"
  }
}

# ssh ubuntu@$(terraform output -raw file_server_instance_dns)
output "file_server_instance_dns" {
  value = aws_instance.file_server.public_dns
}
