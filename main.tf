# ==============================================================================
# IU Cloud Programming (DLBSEPCP01_E) - Task 1: Webpage Architecture
# ==============================================================================

terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider (Frankfurt region)
provider "aws" {
  region = "eu-central-1"
}

# Fetch available Availability Zones in this region
data "aws_availability_zones" "available" {
  state = "available"
}

# ------------------------------------------------------------------------------
# 1. NETWORKING: Amazon Virtual Private Cloud (VPC)
# ------------------------------------------------------------------------------

# Main VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "iu-task1-vpc"
  }
}

# Internet Gateway for public web access
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "iu-task1-igw"
  }
}

# Public Subnet in Availability Zone 1
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "iu-task1-public-subnet-1"
  }
}

# Public Subnet in Availability Zone 2 (High Availability requirement)
resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name = "iu-task1-public-subnet-2"
  }
}

# Route Table for Internet Access
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "iu-task1-public-rt"
  }
}

# Associate Subnets with Route Table
resource "aws_route_table_association" "a1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "a2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

# ------------------------------------------------------------------------------
# 2. SECURITY GROUPS (Firewalls)
# ------------------------------------------------------------------------------

# Security Group for the Application Load Balancer (Accepts global HTTP traffic)
resource "aws_security_group" "alb_sg" {
  name        = "iu-alb-security-group"
  description = "Allow inbound HTTP traffic to Load Balancer"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from anywhere"
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

  tags = {
    Name = "iu-task1-alb-sg"
  }
}

# Security Group for EC2 Web Servers (Accepts traffic ONLY from ALB for security)
resource "aws_security_group" "ec2_sg" {
  name        = "iu-ec2-security-group"
  description = "Allow HTTP traffic exclusively from Load Balancer"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "iu-task1-ec2-sg"
  }
}

# ------------------------------------------------------------------------------
# 3. COMPUTE: Launch Template & Auto Scaling Group
# ------------------------------------------------------------------------------

# Get latest free-tier Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

# EC2 Launch Template with Hello World Web Server setup
resource "aws_launch_template" "web" {
  name_prefix   = "iu-web-template-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = "t2.micro" # AWS Free Tier eligible

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.ec2_sg.id]
  }

  # Startup script to install Apache and create the 'Hello World' webpage
  user_data = base64encode(<<-EOF
              #!/bin/bash
              dnf update -y
              dnf install -y httpd
              systemctl start httpd
              systemctl enable httpd
              echo "<h1>Hello World!</h1><p>Hosted on AWS with Terraform - IU Cloud Programming</p>" > /var/www/html/index.html
              EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "iu-task1-webserver"
    }
  }
}

# Target Group to connect ALB to EC2 instances
resource "aws_lb_target_group" "web_tg" {
  name     = "iu-web-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# Auto Scaling Group (Distributes EC2 instances across 2 AZs)
resource "aws_autoscaling_group" "web_asg" {
  name_prefix         = "iu-web-asg-"
  vpc_zone_identifier = [aws_subnet.public_1.id, aws_subnet.public_2.id]
  target_group_arns   = [aws_lb_target_group.web_tg.arn]

  min_size         = 1
  max_size         = 2
  desired_capacity = 1

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "iu-asg-instance"
    propagate_at_launch = true
  }
}

# ------------------------------------------------------------------------------
# 4. LOAD BALANCING: Application Load Balancer (ALB)
# ------------------------------------------------------------------------------

resource "aws_lb" "web_alb" {
  name               = "iu-task1-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]

  tags = {
    Name = "iu-task1-alb"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.web_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_tg.arn
  }
}

# ------------------------------------------------------------------------------
# 5. GLOBAL CACHE: Amazon CloudFront Distribution (CDN)
# ------------------------------------------------------------------------------

resource "aws_cloudfront_distribution" "cdn" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "CloudFront Distribution for IU Task 1"
  default_root_object = ""

  origin {
    domain_name = aws_lb.web_alb.dns_name
    origin_id   = "ALB-Origin"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "ALB-Origin"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name = "iu-task1-cloudfront"
  }
}
