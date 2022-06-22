resource "aws_key_pair" "app-ssh-key" {
  key_name   = "app-key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDdcpT+PCr2Uu8+1L0DZGigUJ3nLyfwZfL6a6ALkeTfOHIoh02s9Q9nPK97isolRt3H2CaIS1rcDXVFjCNZyWr+CaWN20RkOJbWf5N8vs1wgmgDTOpRsA+8VyglBp9JDc7oDG85wS/qOBsWVwZC2pqwgbawoDw29AJUrqGCi0ZYQZWaBzH7QUDktGmhGeh9ht2V/Uli+q0lMcwGXjQEgDqH8keyRpcqPEGldjJ7C4U7++I/DXKCn+YLtAgrnYIdU0qRaFXZkTkVY7H+pbf6N3JiP2cfYmcRdeDWrJd0pciygDdRGr4W12a3PmsScjnitVyo97RNxhxhoYWxwUUP1YhEcNGgI3UV9evfWEF0cGwufiHHFKlU8mL6dNl3mrgBZSVW/xiPRCVmtVK06a1Im9HO8bV2oMFo0DkEKXninN48/8jWIDxt0zIycyqq1N2FVLv0cQUgjaS+Mm97ShC6utpOEo361+tzR/jzVpsf6XHwJa0cYAQmj2PZXjkMwvV9nY8= app-turma08"
}

resource "aws_instance" "app-ec2" {
  ami                         = data.aws_ami.amazon-lnx.id
  instance_type               = var.instance_type_app
  subnet_id                   = data.aws_subnet.app-public-subnet.id
  associate_public_ip_address = true
  tags = {
    Name = format("%s-app", local.name)
  }
  key_name  = aws_key_pair.app-ssh-key.id
  user_data = file("ec2.sh")
}

resource "aws_instance" "app-mongdb" {
  ami           = data.aws_ami.amazon-lnx.id
  instance_type = var.instance_type_mongodb
  subnet_id     = data.aws_subnet.app-public-subnet.id
  tags = {
    Name = format("%s-mongodb", local.name)
  }
  key_name  = aws_key_pair.app-ssh-key.id
  user_data = file("mongodb.sh")
}

resource "aws_security_group" "allow-http-ssh" {
  name        = format("%s-allow-http-ssh", local.name)
  description = "Allow Http and ssh ports"
  vpc_id      = data.aws_vpc.vpc.id

  ingress = [
    {
      description      = "Allow ssh"
      from_port        = "22"
      to_port          = "22"
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      security_groups  = []
      self             = null
    },
    {
      description      = "Allow http"
      from_port        = "80"
      to_port          = "80"
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      security_groups  = []
      self             = null
    }
  ]

  egress = [
    {
      description      = "Allow all"
      from_port        = "0"
      to_port          = "0"
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      security_groups  = []
      self             = null
    }
  ]
}

resource "aws_security_group" "allow-mongodb" {
  name        = format("%s-allow-mongodb", local.name)
  description = "Allow mongodb port"
  vpc_id      = data.aws_vpc.vpc.id

  ingress = [
    {
      description      = "Allow mongodb"
      from_port        = "27017"
      to_port          = "27017"
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      security_groups  = []
      self             = null
    }
  ]

  egress = [
    {
      description      = "Allow all"
      from_port        = "0"
      to_port          = "0"
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      security_groups  = []
      self             = null
    }
  ]
}

resource "aws_network_interface_sg_attachment" "app-sg" {
  security_group_id    = aws_security_group.allow-http-ssh.id
  network_interface_id = aws_instance.app-ec2.primary_network_interface_id
}

resource "aws_network_interface_sg_attachment" "mongodb-sg" {
  security_group_id    = aws_security_group.allow-mongodb.id
  network_interface_id = aws_instance.app-mongdb.primary_network_interface_id
}

resource "aws_route53_zone" "app-zone" {
  name = format("%s.com.br", var.project)

  vpc {
    vpc_id = "vpc-0f7f13c5776c8786a"
  }
}

resource "aws_route53_record" "mongodb" {
  zone_id = aws_route53_zone.app-zone.id
  name    = format("mongodb.%s.com.br", var.project)
  type    = "A"
  ttl     = "300"
  records = [aws_instance.app-mongdb.private_ip]
}