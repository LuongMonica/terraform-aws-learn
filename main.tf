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

resource "aws_elb" "elb1" {
  name               = "elb1"
  security_groups    = [aws_security_group.elb_sg.id]
  availability_zones = data.aws_availability_zones.all.names

  health_check {
    target              = "HTTP:8080/"
    interval            = 60
    timeout             = 30
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  listener {
    lb_port          = 80
    lb_protocol      = "http"
    instance_port    = 8080
    instance_protocol = "http"
  }
}

resource "aws_security_group" "elb_sg" {
  name          = "elb_sg"
  description   = "security group for (classic) load balancer"

  ingress {
    from_port   = 80
    to_port     = 80
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

resource "aws_elb_attachment" "attach1" {
  elb      = aws_elb.elb1.id
  instance = aws_instance.ubuntu.id
}

resource "aws_elb_attachment" "attach2" {
  elb      = aws_elb.elb1.id
  instance = aws_instance.ubuntu2.id
}

/*
resource "aws_elb_attachment" "attach3" {
  elb      = aws_elb.elb1.id
  instance = aws_instance.centos.id
}
*/

resource "aws_instance" "ubuntu" {
  ami           = data.aws_ami.ubuntu_ami.id
  instance_type = "t2.micro"
  vpc_security_group_ids = ["${aws_security_group.allow_ssh_http.id}"]
  key_name      = var.key_name
  
  /*user_data = <<-EOT
    #!/bin/bash
    sudo apt-get update
    sudo apt install -y apache2
    service start apache2
    chkconfig apache2 on
    echo "<html><h1>Welcome to Apache Web Server</h2></html>" > /var/www/html/index.html  
    EOT
  */

  provisioner "remote-exec" {
    inline = [
      "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo 'Waiting for cloud-init...'; sleep 1; done",
      "sudo apt update",
      "sudo apt install python -y",
    ]
    
    connection {
      type     = "ssh"
      host     = aws_instance.ubuntu.public_ip
      user     = "ubuntu"
      private_key = file(var.private_key)
    }
  }

  provisioner "local-exec" {
    command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u ubuntu --private-key ${var.private_key} -i '${self.public_ip},' ubuntu_provision.yml"
  }
  
  root_block_device {
    delete_on_termination = "true"
  }

  tags = {
    Name = "ubuntu"
  }
  
}

resource "aws_instance" "ubuntu2" {
  ami           = data.aws_ami.ubuntu_ami.id
  instance_type = "t2.micro"
  vpc_security_group_ids = ["${aws_security_group.allow_ssh_http.id}"]
  key_name      = var.key_name
  
  /*user_data = <<-EOT
    #!/bin/bash
    sudo apt-get update
    sudo apt install -y apache2
    service start apache2
    chkconfig apache2 on
    echo "<html><h1>Welcome to Apache Web Server</h2></html>" > /var/www/html/index.html  
    EOT
  */

  provisioner "remote-exec" {
    inline = [
      "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo 'Waiting for cloud-init...'; sleep 1; done",
      "sudo apt update",
      "sudo apt install python -y",
    ]
    
    connection {
      type     = "ssh"
      host     = aws_instance.ubuntu2.public_ip
      user     = "ubuntu"
      private_key = file(var.private_key)
    }
  }

  provisioner "local-exec" {
    command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u ubuntu --private-key ${var.private_key} -i '${self.public_ip},' ubuntu_provision.yml"
  }
  
  root_block_device {
    delete_on_termination = "true"
  }

  tags = {
    Name = "ubuntu2"
  }
  
}

/*
  resource "aws_instance" "centos" {
  ami           = "ami-0affd4508a5d2481b"
  instance_type = "t2.micro"
  vpc_security_group_ids = ["${aws_security_group.allow_ssh_http.id}"]
  key_name      = var.key_name
   
  user_data = <<-EOT
    #!/bin/bash
    yum check-update
    yum install -y epel-release
    yum install -y nginx
    systemctl enable nginx
    systemctl start nginx
    EOT
  

  provisioner "remote-exec" {
    inline = [
      "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo 'Waiting for cloud-init...'; sleep 1; done",
      "sudo yum check-update",
      "sudo yum install -y python",              
    ]

    connection {
      type     = "ssh"
      host     = aws_instance.centos.public_ip 
      user     = "centos"
      private_key = file(var.private_key)
    }
  }

  provisioner "local-exec" {
    command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u centos --private-key ${var.private_key} -i '${self.public_ip},' centos_provision.yml"
  }

  root_block_device {
    delete_on_termination = "true"
  }

  tags = {
    Name = "centos"
  }
}
*/

resource "aws_security_group" "allow_ssh_http" {
  name          = "allow_ssh_http"
  description   = "Allows SSH and HTTP"

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

output "public_dns_ubuntu" {
  value        = aws_instance.ubuntu.public_dns
  description  = "The public DNS of the ubuntu machine"
}

output "public_ip_ubuntu" {
  value        = aws_instance.ubuntu.public_ip
  description  = "The public IP of the ubuntu machine"
}

output "public_dns_ubuntu2" {
  value        = aws_instance.ubuntu2.public_dns
  description  = "The public DNS of the 2nd ubuntu machine"
}

output "public_ip_ubuntu2" {
  value        = aws_instance.ubuntu2.public_ip
  description  = "The public IP of the 2nd ubuntu machine"
}

/*
output "public_dns_centos" {
  value        = aws_instance.centos.public_dns
  description  = "The public DNS of the centos machine"
}

output "public_ip_centos" {
  value        = aws_instance.centos.public_ip
  description  = "The public IP of the centos machine"
}
*/

output "dns_name_elb1" {
  value        = aws_elb.elb1.dns_name
  description  = "The DNS of the elb"
}
