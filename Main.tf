terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region = "eu-west-2"
}
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "multi-tier-vpc"
  }
}
resource "aws_subnet" "public_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "eu-west-2a"

  tags = {
    Name = "public-subnet-1"
  }
}

resource "aws_subnet" "public_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "eu-west-2b"

  tags = {
    Name = "public-subnet-2"
  }
}
resource "aws_subnet" "private_app_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "eu-west-2a"

  tags = {
    Name = "private-app-subnet-1"
  }
}

resource "aws_subnet" "private_app_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "eu-west-2b"

  tags = {
    Name = "private-app-subnet-2"
  }
}
resource "aws_subnet" "private_db_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.5.0/24"
  availability_zone = "eu-west-2a"

  tags = {
    Name = "private-db-subnet-1"
  }
}

resource "aws_subnet" "private_db_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.6.0/24"
  availability_zone = "eu-west-2b"

  tags = {
    Name = "private-db-subnet-2"
  }
}
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "multi-tier-igw"
  }
}
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "public-route-table"
  }
}
resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}
resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "multi-tier-nat-eip"
  }
}
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_1.id

  tags = {
    Name = "multi-tier-nat-gateway"
  }
}
resource "aws_route_table" "private_app" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "multi-tier-private-app-rt"
  }
}

resource "aws_route_table_association" "private_app_1" {
  subnet_id      = aws_subnet.private_app_1.id
  route_table_id = aws_route_table.private_app.id
}

resource "aws_route_table_association" "private_app_2" {
  subnet_id      = aws_subnet.private_app_2.id
  route_table_id = aws_route_table.private_app.id
}
resource "aws_route_table" "private_db" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "multi-tier-private-db-rt"
  }
}

resource "aws_route_table_association" "private_db_1" {
  subnet_id      = aws_subnet.private_db_1.id
  route_table_id = aws_route_table.private_db.id
}

resource "aws_route_table_association" "private_db_2" {
  subnet_id      = aws_subnet.private_db_2.id
  route_table_id = aws_route_table.private_db.id
}
resource "aws_security_group" "alb" {
  name        = "multi-tier-alb-sg"
  description = "Security group for the Application Load Balancer"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "multi-tier-alb-sg"
  }
}

resource "aws_security_group" "app" {
  name        = "multi-tier-app-sg"
  description = "Security group for application servers"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "multi-tier-app-sg"
  }
}

resource "aws_security_group" "db" {
  name        = "multi-tier-db-sg"
  description = "Security group for the database"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "multi-tier-db-sg"
  }
}
# Internet -> ALB on HTTP
resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

# ALB -> App
resource "aws_vpc_security_group_egress_rule" "alb_to_app" {
  security_group_id            = aws_security_group.alb.id
  referenced_security_group_id = aws_security_group.app.id
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
}

# App accepts HTTP only from ALB
resource "aws_vpc_security_group_ingress_rule" "app_from_alb" {
  security_group_id            = aws_security_group.app.id
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
}

# App -> Internet HTTP through NAT
resource "aws_vpc_security_group_egress_rule" "app_http" {
  security_group_id = aws_security_group.app.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

# App -> Internet HTTPS through NAT
resource "aws_vpc_security_group_egress_rule" "app_https" {
  security_group_id = aws_security_group.app.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

# App -> Database
resource "aws_vpc_security_group_egress_rule" "app_to_db" {
  security_group_id            = aws_security_group.app.id
  referenced_security_group_id = aws_security_group.db.id
  from_port                    = 3306
  to_port                      = 3306
  ip_protocol                  = "tcp"
}

# Database accepts MySQL only from App
resource "aws_vpc_security_group_ingress_rule" "db_from_app" {
  security_group_id            = aws_security_group.db.id
  referenced_security_group_id = aws_security_group.app.id
  from_port                    = 3306
  to_port                      = 3306
  ip_protocol                  = "tcp"
}
# IAM role for EC2 application servers
resource "aws_iam_role" "app_ec2_role" {
  name = "multi-tier-app-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRole"

      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = {
    Name = "multi-tier-app-ec2-role"
  }
}

# Allow EC2 instances to use Systems Manager
resource "aws_iam_role_policy_attachment" "app_ssm" {
  role       = aws_iam_role.app_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Makes the IAM role attachable to EC2
resource "aws_iam_instance_profile" "app" {
  name = "multi-tier-app-instance-profile"
  role = aws_iam_role.app_ec2_role.name
}
# Latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
resource "aws_launch_template" "app" {
  name_prefix   = "multi-tier-app-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"

  iam_instance_profile {
    name = aws_iam_instance_profile.app.name
  }

  vpc_security_group_ids = [
    aws_security_group.app.id
  ]

  user_data = base64encode(<<-EOF
    #!/bin/bash
    dnf install -y nginx
    systemctl enable nginx
    systemctl start nginx

    cat > /usr/share/nginx/html/index.html <<'HTML'
    <!DOCTYPE html>
    <html>
    <head>
      <title>AWS Multi-Tier Application</title>
    </head>
    <body>
      <h1>AWS Multi-Tier Application</h1>
      <p>Application server deployed with Terraform.</p>
    </body>
    </html>
    HTML
  EOF
  )

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "multi-tier-app-server"
    }
  }
}
# Application Load Balancer
resource "aws_lb" "app" {
  name               = "multi-tier-app-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]

  subnets = [
    aws_subnet.public_1.id,
    aws_subnet.public_2.id
  ]

  tags = {
    Name = "multi-tier-app-alb"
  }
}

# Target group for application servers
resource "aws_lb_target_group" "app" {
  name     = "multi-tier-app-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
  }

  tags = {
    Name = "multi-tier-app-tg"
  }
}

# ALB HTTP listener
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}
# Auto Scaling Group for application servers
resource "aws_autoscaling_group" "app" {
  name = "multi-tier-app-asg"

  min_size         = 2
  max_size         = 4
  desired_capacity = 2

  vpc_zone_identifier = [
    aws_subnet.private_app_1.id,
    aws_subnet.private_app_2.id
  ]

  target_group_arns = [
    aws_lb_target_group.app.arn
  ]

  health_check_type         = "ELB"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "multi-tier-app-server"
    propagate_at_launch = true
  }
}
# Database subnet group
resource "aws_db_subnet_group" "main" {
  name = "multi-tier-db-subnet-group"

  subnet_ids = [
    aws_subnet.private_db_1.id,
    aws_subnet.private_db_2.id
  ]

  tags = {
    Name = "multi-tier-db-subnet-group"
  }
}
variable "db_username" {
  description = "Username for the RDS database"
  type        = string
  default     = "admin"
}

variable "db_password" {
  description = "Password for the RDS database"
  type        = string
  sensitive   = true
}
resource "aws_db_instance" "main" {
  identifier = "multi-tier-db"

  engine         = "mysql"
  engine_version = "8.0"
  instance_class = "db.t3.micro"

  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = "multitierdb"
  username = var.db_username
  password = var.db_password
  port     = 3306

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.db.id]

  publicly_accessible = false
  multi_az            = false

  skip_final_snapshot = true
  deletion_protection = false

  tags = {
    Name = "multi-tier-db"
  }
}
# Outputs
output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.app.dns_name
}

output "rds_endpoint" {
  description = "Endpoint of the RDS database"
  value       = aws_db_instance.main.endpoint
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}
