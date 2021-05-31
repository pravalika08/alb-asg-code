terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "3.42.0"
    }
  }
  backend "s3" {
    bucket = "terraformstate31052021"
    key    = "production"
    region = "ap-south-1"
  }
}
data "aws_availability_zones" "available" {
  state = "available"
}
provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region     = var.aws_region
}
resource "aws_key_pair" "prod" {
  key_name   = "prod30"
  public_key = file("~/.ssh/id_rsa.pub")
}
resource "aws_vpc" "prod_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "prod_vpc"
  }
}
resource "aws_subnet" "public_subnet_1a" {
  vpc_id     = aws_vpc.prod_vpc.id
  cidr_block = "10.0.1.0/24"
  #cidr_block              = var.cidr_public_subnet_1a
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[0]
  tags = {
    Name = "public_subnet-1a"
  }
}
resource "aws_subnet" "public_subnet_1b" {
  vpc_id                  = aws_vpc.prod_vpc.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[1]
  tags = {
    Name = "public_subnet-1b"
  }
}
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.prod_vpc.id
  tags = {
    Name = "public_rt"
  }
}
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.prod_vpc.id
  tags = {
    Name = "public_igw"
  }
}
resource "aws_route" "public_internet_gateway" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id

}
resource "aws_route_table_association" "public_subnet_assoc_1a" {
  route_table_id = aws_route_table.public.id
  subnet_id      = aws_subnet.public_subnet_1a.id
}
resource "aws_route_table_association" "public_subnet_assoc_1b" {
  route_table_id = aws_route_table.public.id
  subnet_id      = aws_subnet.public_subnet_1b.id
}
resource "aws_security_group" "sg_26" {
  name   = "sg_26"
  vpc_id = aws_vpc.prod_vpc.id
}
resource "aws_security_group_rule" "allow-ssh" {
  from_port         = 22
  protocol          = "tcp"
  security_group_id = aws_security_group.sg_26.id
  to_port           = 22
  type              = "ingress"
  cidr_blocks       = ["0.0.0.0/0"]
}
resource "aws_security_group_rule" "allow-http" {
  from_port         = 80
  protocol          = "tcp"
  security_group_id = aws_security_group.sg_26.id
  to_port           = 80
  type              = "ingress"
  cidr_blocks       = ["0.0.0.0/0"]
}
resource "aws_security_group_rule" "allow-outbound" {
  from_port         = 0
  protocol          = "-1"
  security_group_id = aws_security_group.sg_26.id
  to_port           = 0
  type              = "egress"
  cidr_blocks       = ["0.0.0.0/0"]
}
resource "aws_instance" "public" {
  ami                         = lookup(var.ami_type, var.aws_region)
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.prod.key_name
  security_groups             = [aws_security_group.sg_26.id]
  subnet_id                   = aws_subnet.public_subnet_1a.id
  vpc_security_group_ids      = [aws_security_group.sg_26.id]
  associate_public_ip_address = true
  availability_zone           = data.aws_availability_zones.available.names[0]
  user_data                   = <<-EOF
  #!/bin/bash
  mkdir /var/www/html/login
    echo "<h1>This is login page</h1>" > /var/www/html/login/index.html
    service httpd start
    chkconfig httpd on
      
    EOF
  tags = {
    Name = "Production1"
  }
  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd -y",

    ]
    connection {
      type        = "ssh"
      user        = "ec2-user"
      password    = ""
      private_key = file("~/.ssh/id_rsa")
      host        = self.public_ip
    }
  }
}
resource "aws_instance" "public1" {
  ami                         = lookup(var.ami_type, var.aws_region)
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.prod.key_name
  security_groups             = [aws_security_group.sg_26.id]
  subnet_id                   = aws_subnet.public_subnet_1b.id
  vpc_security_group_ids      = [aws_security_group.sg_26.id]
  associate_public_ip_address = true
  availability_zone           = data.aws_availability_zones.available.names[1]
  user_data                   = <<-EOF
  #!/bin/bash
  mkdir /var/www/html/site
    echo "<h1>This is the site page</h1>" > /var/www/html/site/index.html
    service httpd start
    chkconfig httpd on
    EOF
  tags = {
    Name = "Production2"
  }
  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd -y",

    ]
    connection {
      type        = "ssh"
      user        = "ec2-user"
      password    = ""
      private_key = file("~/.ssh/id_rsa")
      host        = self.public_ip
    }
  }
}
resource "aws_lb_target_group" "alb_target_group" {
  health_check {
    path                = "/login/index.html"
    protocol            = "HTTP"
    healthy_threshold   = 5
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }
  stickiness {
    type    = "lb_cookie"
    enabled = false
  }
  name        = "alb-login1"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.prod_vpc.id
  depends_on  = [aws_lb.alb]

}
resource "aws_lb_target_group" "alb_target_group1" {
  health_check {
    path                = "/site/index.html"
    protocol            = "HTTP"
    healthy_threshold   = 5
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    matcher             = "200"


  }
  stickiness {
    type    = "lb_cookie"
    enabled = false
  }
  name        = "alb-site1"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.prod_vpc.id
  depends_on  = [aws_lb.alb]
}
resource "aws_lb_target_group_attachment" "test" {
  target_group_arn = aws_lb_target_group.alb_target_group.arn
  target_id        = aws_instance.public.id
  port             = 80
}
resource "aws_lb_target_group_attachment" "test1" {
  target_group_arn = aws_lb_target_group.alb_target_group1.arn
  target_id        = aws_instance.public1.id
  port             = 80
}
resource "aws_lb" "alb" {
  name               = "my-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_security_group.id]
  subnets = [aws_subnet.public_subnet_1a.id,
    aws_subnet.public_subnet_1b.id
  ]
}
resource "aws_security_group" "alb_security_group" {
  vpc_id = aws_vpc.prod_vpc.id
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
resource "aws_lb_listener" "alb_listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    target_group_arn = aws_lb_target_group.alb_target_group.arn
    type             = "forward"
  }
}
resource "aws_lb_listener_rule" "based_on_path" {
  depends_on   = [aws_lb_target_group.alb_target_group]
  listener_arn = aws_lb_listener.alb_listener.arn

  action {
    target_group_arn = aws_lb_target_group.alb_target_group.id
    type             = "forward"
  }
  condition {
    path_pattern {
      values = ["/login*"]
    }
  }
}
resource "aws_lb_listener_rule" "based_on_path1" {
  depends_on   = [aws_lb_target_group.alb_target_group1]
  listener_arn = aws_lb_listener.alb_listener.arn

  action {
    target_group_arn = aws_lb_target_group.alb_target_group1.id
    type             = "forward"
  }
  condition {
    path_pattern {
      values = ["/site*"]
    }
  }
}
resource "aws_launch_configuration" "launch_configuration" {
  name                        = var.launch_configuration_name
  image_id                    = var.image_id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.prod.key_name
  security_groups             = [aws_security_group.alb_security_group.id]
  associate_public_ip_address = true
  lifecycle {
    create_before_destroy = true
  }
  user_data = file("login.sh")
}
resource "aws_autoscaling_attachment" "aws_autoscaling_attachment" {
  alb_target_group_arn   = aws_lb_target_group.alb_target_group.arn
  autoscaling_group_name = aws_autoscaling_group.autoscaling_group.id
}
resource "aws_autoscaling_group" "autoscaling_group" {
  name                      = var.aws_autoscaling_group_name
  desired_capacity          = 2 
  min_size                  = 2 
  max_size                  = 5 
  health_check_grace_period = 200
  health_check_type         = "ELB"
  force_delete              = true

  launch_configuration = aws_launch_configuration.launch_configuration.id
  vpc_zone_identifier = [
    aws_subnet.public_subnet_1a.id,
    aws_subnet.public_subnet_1b.id
  ]
  timeouts {
    delete = "15m" 
  }
  lifecycle {
    create_before_destroy = true
  }
}
