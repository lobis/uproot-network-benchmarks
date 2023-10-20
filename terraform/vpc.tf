
data "aws_availability_zones" "available" {}

resource "aws_vpc" "main" {
  cidr_block           = "10.20.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = {
    Name = "benchmarks-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = {
    Name = "benchmarks-igw"
  }
}

resource "aws_subnet" "web_A" {
  vpc_id                  = aws_vpc.main.id
  availability_zone       = element(data.aws_availability_zones.available.names, 0)
  cidr_block              = "10.20.48.0/20"
  map_public_ip_on_launch = true
  tags                    = {
    Name = "subnet-web-A"
  }
}

resource "aws_subnet" "web_B" {
  vpc_id                  = aws_vpc.main.id
  availability_zone       = element(data.aws_availability_zones.available.names, 1)
  cidr_block              = "10.20.112.0/20"
  map_public_ip_on_launch = true
  tags                    = {
    Name = "subnet-web-B"
  }
}

resource "aws_subnet" "web_C" {
  vpc_id                  = aws_vpc.main.id
  availability_zone       = element(data.aws_availability_zones.available.names, 2)
  cidr_block              = "10.20.176.0/20"
  map_public_ip_on_launch = true
  tags                    = {
    Name = "subnet-web-C"
  }
}

resource "aws_route_table" "public_internet" {
  vpc_id = aws_vpc.main.id
  tags   = {
    Name = "rt-public-internet"
  }
}

resource "aws_route" "web" {
  route_table_id         = aws_route_table.public_internet.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "web_A" {
  subnet_id      = aws_subnet.web_A.id
  route_table_id = aws_route_table.public_internet.id
}

resource "aws_route_table_association" "web_B" {
  subnet_id      = aws_subnet.web_B.id
  route_table_id = aws_route_table.public_internet.id
}

resource "aws_route_table_association" "web_C" {
  subnet_id      = aws_subnet.web_C.id
  route_table_id = aws_route_table.public_internet.id
}
