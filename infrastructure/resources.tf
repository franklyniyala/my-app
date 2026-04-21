# VPC
resource "aws_vpc" "my-app-vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "my-app"
  }
}

# Public Subnet
resource "aws_subnet" "my-app-public-subnet" {
  count                   = 2
  vpc_id                  = aws_vpc.my-app-vpc.id
  cidr_block              = "10.0.${count.index}.0/24"
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true
  tags = {
    Name                     = "my-app-public-subnet[${count.index}]"
    "kubernetes.io/role/elb" = "1"
  }
}

# Private subnet

resource "aws_subnet" "my-app-private-subnet" {
  count                   = 2
  vpc_id                  = aws_vpc.my-app-vpc.id
  cidr_block              = "10.0.${count.index + 10}.0/24"
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name                              = "my-app-private-subnet[${count.index}]"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

# Elatic eip
resource "aws_eip" "my-app-eip" {
  count  = 1
  domain = "vpc"
}

# Nat Gateway
resource "aws_nat_gateway" "my-app-nat" {
  allocation_id = aws_eip.my-app-eip[0].id
  subnet_id     = aws_subnet.my-app-public-subnet[0].id

  tags = {
    Name = "my-app-nat"
  }
  depends_on = [aws_internet_gateway.my-app-igw]
}

# Internet Gateway
resource "aws_internet_gateway" "my-app-igw" {
  vpc_id = aws_vpc.my-app-vpc.id

  tags = {
    Name = "my-app-igw"
  }
}

# Public Route Table
resource "aws_route_table" "my-app-public-rt" {
  vpc_id = aws_vpc.my-app-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my-app-igw.id
  }

  tags = {
    Name = "my-app-public-rt"
  }
}

# Private Route Table
resource "aws_route_table" "my-app-private-rt" {
  vpc_id = aws_vpc.my-app-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.my-app-nat.id
  }

  tags = {
    Name = "my-app-private-rt"
  }
}

# Public Route Table Association
resource "aws_route_table_association" "my-app-public-rt-association" {
  count          = length(aws_subnet.my-app-public-subnet)
  subnet_id      = aws_subnet.my-app-public-subnet[count.index].id
  route_table_id = aws_route_table.my-app-public-rt.id
}


# Private Route Table Association
resource "aws_route_table_association" "my-app-private-rt-association" {
  count          = length(aws_subnet.my-app-private-subnet)
  subnet_id      = aws_subnet.my-app-private-subnet[count.index].id
  route_table_id = aws_route_table.my-app-private-rt.id
}

# Security Groups
resource "aws_security_group" "my-app-sg" {
  name        = "my-app-sg"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.my-app-vpc.id

  tags = {
    Name = "my-app-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_http" {
  security_group_id = aws_security_group.my-app-sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "allow_ssh" {
  security_group_id = aws_security_group.my-app-sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_egress_rule" "allow_all_outbound" {
  security_group_id = aws_security_group.my-app-sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_ecr_repository" "app" {
  name = "my-app-repo"

  image_scanning_configuration {
    scan_on_push = true
  }

  force_delete = true
}