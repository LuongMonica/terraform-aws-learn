provider "aws" {
  access_key = var.access_key
  secret_key = var.secret_key
  region     = "us-east-1"
}

data "aws_availability_zones" "all" {}

data "aws_ami" "ubuntu_ami" {
    most_recent = true
    owners = ["099720109477"] # Canonical
    filter {
        name   = "name"
        values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
    }
    filter {
        name   = "virtualization-type"
        values = ["hvm"]
    }
}

resource "aws_key_pair" "ec2_key" {
  key_name = "id_rsa_ec2.pub"
  public_key = file(var.public_key_path)
}

resource "aws_vpc" "test_vpc" {
  cidr_block           = "10.0.0.0/16"
  instance_tenancy     = "default"
  enable_dns_support   = "true"
  enable_dns_hostnames = "true"

  tags = {
    Name = "Test VPC"
  }

}

resource "aws_subnet" "vpc_pub_sub_1" {
  vpc_id                  = aws_vpc.test_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = "true"
  availability_zone       = var.avail_zone

  tags = {
    Name = "Public Subnet 1"
  }

}

resource "aws_subnet" "vpc_pub_sub_2" {
  vpc_id                  = aws_vpc.test_vpc.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = "true"
  availability_zone       = var.avail_zone

  tags = {
    Name = "Public Subnet 2"
  }

}

resource "aws_subnet" "vpc_priv_sub_1" {
  vpc_id                  = aws_vpc.test_vpc.id
  cidr_block              = "10.0.3.0/24"
  map_public_ip_on_launch = "false" 
  availability_zone       = var.avail_zone

  tags = {
    Name = "Private Subnet 1"
  }

}

resource "aws_subnet" "vpc_priv_sub_2" {
  vpc_id                  = aws_vpc.test_vpc.id
  cidr_block              = "10.0.4.0/24"
  map_public_ip_on_launch = "false"
  availability_zone       = var.avail_zone

  tags = {
    Name = "Private Subnet 2"
  }

}
resource "aws_internet_gateway" "vpc_igw" {
  vpc_id = aws_vpc.test_vpc.id
  
  tags = {
    Name = "Test VPC Internet Gateway"
  }

}

resource "aws_route_table" "vpc_pub_route_table" {
  vpc_id = aws_vpc.test_vpc.id
  
  tags = {
    Name = "Test VPC Public Route Table"
  }

}

resource "aws_route" "vpc_pub_route" {
  route_table_id         = aws_route_table.vpc_pub_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.vpc_igw.id
}

resource "aws_route_table_association" "vpc_rt_assoc_pub1" {
  route_table_id = aws_route_table.vpc_pub_route_table.id
  subnet_id      = aws_subnet.vpc_pub_sub_1.id
}

resource "aws_route_table_association" "vpc_rt_assoc_pub2" {
  route_table_id = aws_route_table.vpc_pub_route_table.id
  subnet_id      = aws_subnet.vpc_pub_sub_2.id
}

resource "aws_eip" "nat" {
  vpc = "true"
}

resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.vpc_pub_sub_1.id
  depends_on    = [aws_internet_gateway.vpc_igw]
}

resource "aws_route_table" "vpc_priv_route_table" {
  vpc_id = aws_vpc.test_vpc.id

  tags = {
    Name = "Test VPC Private Route Table"
  }

}
 
resource "aws_route" "vpc_priv_route" {
  route_table_id         = aws_route_table.vpc_priv_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gw.id
}

resource "aws_route_table_association" "vpc_rt_assoc_priv1" {
  route_table_id = aws_route_table.vpc_priv_route_table.id
  subnet_id      = aws_subnet.vpc_priv_sub_1.id
}

resource "aws_route_table_association" "vpc_rt_assoc_priv2" {
  route_table_id = aws_route_table.vpc_priv_route_table.id
  subnet_id      = aws_subnet.vpc_priv_sub_2.id
}

resource "aws_instance" "ubuntu_priv" {
  ami           = data.aws_ami.ubuntu_ami.id
  instance_type = "t2.micro"
  subnet_id = aws_subnet.vpc_priv_sub_1.id
  vpc_security_group_ids = ["${aws_security_group.vpc_sg.id}"]
  key_name      = aws_key_pair.ec2_key.key_name

  root_block_device {
    delete_on_termination = "true"
  }

  tags = {
    Name = "ubuntu_priv"
  }

}

resource "aws_instance" "bastion" {
  ami           = data.aws_ami.ubuntu_ami.id
  instance_type = "t2.micro"
  subnet_id = aws_subnet.vpc_pub_sub_1.id
  vpc_security_group_ids = ["${aws_security_group.vpc_sg.id}"]
  key_name      = aws_key_pair.ec2_key.key_name

  root_block_device {
    delete_on_termination = "true"
  }

  tags = {
    Name = "bastion"
  }

}

resource "aws_instance" "ubuntu_pub" {
  ami           = data.aws_ami.ubuntu_ami.id
  instance_type = "t2.micro"
  subnet_id = aws_subnet.vpc_pub_sub_1.id
  vpc_security_group_ids = ["${aws_security_group.allow_ssh_http.id}"]
  key_name      = var.key_name

  root_block_device {
    delete_on_termination = "true"
  }

  tags = {
    Name = "ubuntu_pub"
  }

}

resource "aws_security_group" "vpc_sg" {
  vpc_id        = aws_vpc.test_vpc.id
  name          = "vpc_sg"
  description   = "Security Group for VPC"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "allow_ssh_http" {
  vpc_id        = aws_vpc.test_vpc.id
  name          = "allow_ssh_http"
  description   = "allows ssh and http"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

output "public_dns_ubuntu_pub" {
  value        = aws_instance.ubuntu_pub.public_dns
  description  = "The public DNS of the ubuntu machine on the public subnet"
}

output "public_ip_ubuntu_pub" {
  value        = aws_instance.ubuntu_pub.public_ip
  description  = "The public IP of the ubuntu machine on the public subnet"
}

output "public_dns_bastion" {
  value        = aws_instance.bastion.public_dns
  description  = "The public DNS of the bastion instance on the public subnet"
}

output "public_ip_bastion" {
  value        = aws_instance.bastion.public_ip
  description  = "The public IP of the bastion instance on the public subnet"
}

output "private_dns_ubuntu_priv" {
  value        = aws_instance.ubuntu_priv.private_dns
  description  = "The private DNS of the ubuntu machine on the private subnet"
}

output "private_ip_ubuntu_priv" {
  value        = aws_instance.ubuntu_priv.private_ip
  description  = "The private IP of the ubuntu machine on the private subnet"
}
