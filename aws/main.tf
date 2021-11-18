terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.26.0"
    }
  }
}

provider "aws" {
  region = "eu-west-1"
}

resource "aws_key_pair" "keypair" {
  key_name   = "diarmaid-key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCwS/sf75LjdVHcSkiTY8Ixvk9fMCrf72xTsmtgkqmFpW3akKYz+UGrPojNaNPqNLbiQ+G3MRwnKRIH5xu1CgRct7knpE0cIEjv4ObcvcX0FvvDYMh+fyXqLy4ko7V4pPFPpzHxB0HwFTDOGGvvYHA6L2NqiSpDkiK3bM+525A/pyR8+Y72xxdRXcamrIUEkHSNJxy2G/xElEczBa8Pz+4Kakj9i4/T9SUUI6CHByjn4SZQsMvGzYzCv0uMZwe5qsjE4gnBVSz89Y6yJr0QHzb6y/NKkshivnniMz5JikfcBtbnEPlkt4jNes7c3VnY3//+4tAEo4Ix3tCZqsmdwPLT diarmaid@developmen"
}

# Define VPC
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr_block

  tags = {
    Name = "aws-terraform-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "internet-gateway" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "aws-terraform-internet-gateway"
  }
}

# Define Public Subnets
resource "aws_subnet" "public_subnet" {
  for_each = var.public_subnets

  vpc_id = aws_vpc.main.id

  availability_zone = each.key
  cidr_block        = each.value

  tags = {
    Name = "aws-terraform-public-subnet-${each.key}"
  }
}

# Define Private Subnets
resource "aws_subnet" "private_subnet" {
  for_each = var.private_subnets

  vpc_id = aws_vpc.main.id

  availability_zone = each.key
  cidr_block        = each.value

  tags = {
    Name = "aws-terraform-private-subnet-${each.key}"
  }
}

# Define Database Subnets
resource "aws_subnet" "database_subnet" {
  for_each = var.database_subnets

  vpc_id = aws_vpc.main.id

  availability_zone = each.key
  cidr_block        = each.value

  tags = {
    Name = "aws-terraform-database-subnet-${each.key}"
  }
}

# Route Table
resource "aws_route_table" "public_subnet_route_table" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet-gateway.id
  }

  tags = {
    Name = "aws-terraform-public-subnet-route-table"
  }
}

# Associate route table with public subnets
resource "aws_route_table_association" "public_subnet_route_table_association" {
  for_each = var.public_subnets

  subnet_id      = aws_subnet.public_subnet[each.key].id
  route_table_id = aws_route_table.public_subnet_route_table.id
}


##### Web tier config

# Web - ELB
resource "aws_lb" "webapp_lb" {
  name = "webapp-lb"
  internal = false
  load_balancer_type = "application"
  security_groups = [aws_security_group.alb_http.id]
  subnets = [for value in aws_subnet.public_subnet: value.id]
}

# Web - ELB Security Group
resource "aws_security_group" "alb_http" {
  name        = "alb-security-group"
  description = "Allowing HTTP requests to the application load balancer"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  tags = {
    Name = "alb-security-group"
  }
}

# Web - Listener
resource "aws_lb_listener" "web_listener" {
  load_balancer_arn = aws_lb.webapp_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_target_group.arn
  }
}

# Web - Target Group
resource "aws_lb_target_group" "web_target_group" {
  name     = "web-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    port     = 80
    protocol = "HTTP"
  }
}

# Web - EC2 Instance Security Group
resource "aws_security_group" "web_instance_sg" {
  name        = "web-server-security-group"
  description = "Allowing requests to the web servers"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    security_groups = [aws_security_group.alb_http.id]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    security_groups = [aws_security_group.alb_http.id]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  tags = {
    Name = "web-server-security-group"
  }
}

resource "aws_instance" "ec2webinstances" {
  for_each = aws_subnet.public_subnet
  ami           = "ami-06ce3edf0cff21f07"
  associate_public_ip_address = true
  key_name = aws_key_pair.keypair.key_name
  vpc_security_group_ids = [aws_security_group.web_instance_sg.id]
  availability_zone = each.key
  subnet_id = each.value.id
  instance_type = "t1.micro"
  user_data     = <<-EOF
                  #!/bin/bash
                  sudo su
                  yum -y install httpd
                  sudo systemctl start httpd
                  EOF
  tags = {
    Name = "aws-terraform-webserver-${each.key}"
  }
}



output "public_web_ips" {
  value = values(aws_instance.ec2webinstances)[*] #.public_ip
}


### App section

# App - LB Security Group
resource "aws_security_group" "app_lb_sg" {
  name        = "alb-app-security-group"
  description = "Allowing HTTP requests to the app tier application load balancer"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = [aws_security_group.web_instance_sg.id]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  tags = {
    Name = "alb-app-security-group"
  }
}

# App - Application Load Balancer
resource "aws_lb" "app_app_lb" {
  name = "app-app-lb"
  internal = false
  load_balancer_type = "application"
  security_groups = [aws_security_group.app_lb_sg.id]
  subnets = [for value in aws_subnet.private_subnet: value.id]
}

# App - Listener
resource "aws_lb_listener" "app_listener" {
  load_balancer_arn = aws_lb.app_app_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_target_group.arn
  }
}

# App - Target Group
resource "aws_lb_target_group" "app_target_group" {
  name     = "app-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    port     = 80
    protocol = "HTTP"
  }
}

# App - EC2 Instance Security Group
resource "aws_security_group" "app_instance_sg" {
  name        = "app-server-security-group"
  description = "Allowing requests to the app servers"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = [aws_security_group.app_lb_sg.id]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  tags = {
    Name = "app-server-security-group"
  }
}

resource "aws_instance" "ec2appinstances" {
  for_each = aws_subnet.private_subnet
  ami           = "ami-06ce3edf0cff21f07"
  associate_public_ip_address = false
  key_name = aws_key_pair.keypair.key_name
  vpc_security_group_ids = [aws_security_group.app_instance_sg.id]
  availability_zone = each.key
  subnet_id = each.value.id
  instance_type = "t1.micro"
  tags = {
    Name = "aws-terraform-appserver-${each.key}"
  }
}

# # DB - Security Group
resource "aws_security_group" "db_security_group" {
  name = "aws-terraform-db-sg"
  description = "RDS postgres server"
  vpc_id = aws_vpc.main.id

  # Only postgres in
  ingress {
    from_port = 5432
    to_port = 5432
    protocol = "tcp"
    security_groups = [aws_security_group.app_instance_sg.id]
  }

  # Allow all outbound traffic.
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# DB - Subnet Group
resource "aws_db_subnet_group" "db_subnet" {
  name       = "db-subnet"
  subnet_ids = [for value in aws_subnet.database_subnet: value.id]
  tags = {
    Name = "aws-terraform-subnet-group"
  }
}

# DB - RDS Instance
resource "aws_db_instance" "db_postgres" {
  allocated_storage        = 10
  backup_retention_period  = 0
  db_subnet_group_name     = aws_db_subnet_group.db_subnet.name
  engine                   = "postgres"
  engine_version           = "12.4"
  identifier               = "dbpostgres"
  instance_class           = "db.t3.micro"
  multi_az                 = false
  name                     = "dbpostgres"
  username                 = var.db_username
  password                 = var.db_password
  port                     = 5432
  publicly_accessible      = false
  storage_encrypted        = true
  storage_type             = "gp2"
  vpc_security_group_ids   = [aws_security_group.db_security_group.id]
  skip_final_snapshot      = true
}
