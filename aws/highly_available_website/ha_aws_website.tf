#-------------------------------
#ProvisioN hIGHLY aVAILABLE WEBSITE IN ANY REGION default vpc
#-Create security group for webserver
#-Launch configuration with auto AMI lookup
#-Auto scaling group using 2 availability zones
#-Classic LoadBalancer in 2 availability zones
#!!!aws_launch_configuration - helps change info on servers without destroying them
#-----------------------------------------------

provider "aws" {
  region = "ca-central-1"
}


data "aws_availability_zones" "available" {}
#Looking for latest Amazon Linux
data "aws_ami" "latest_amazon_linux" {
  owners      = ["amazon"]
  most_recent = true
  filter {
    name   = "name"
    values = ["amzn2-ami-*x86_64-gp2"]
  }
}
output "latest_aws_amazon_linux_ami_id" {
  value = data.aws_ami.latest_amazon_linux.id
}
output "latest_aws_amazon_linux_ami_name" {
  value = data.aws_ami.latest_amazon_linux.name
}
#-----------------------------------------------
#Adding securiy group
resource "aws_security_group" "web" {
  name        = "dynamic security group"
  description = "High available dynamic secgroup"
  #Inbound rules
  dynamic "ingress" {
    for_each = ["80", "443", "22"]
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
  #Outbound rules
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_high_available_webserver"
  }
}
#-----------------------------------------------
resource "aws_launch_configuration" "web" {
  #name            = "WebServer-Highly-Available-LC"
  name_prefix     = "WebServer-Highly-Available-LC-"
  image_id        = data.aws_ami.latest_amazon_linux.id
  instance_type   = "t3.micro"
  security_groups = [aws_security_group.web.id]
  user_data       = file("user_data.sh")
  lifecycle {
    create_before_destroy = true
  }
}
#----------------Creating auto scaling group-------------------------------
resource "aws_autoscaling_group" "web" {
  name                 = "ASG-${aws_launch_configuration.web.name}"
  launch_configuration = aws_launch_configuration.web.name
  min_size             = 2
  max_size             = 2
  min_elb_capacity     = 2
  health_check_type    = "ELB" #Checks if web page is available by ping
  vpc_zone_identifier  = [aws_default_subnet.default_az1.id, aws_default_subnet.default_az1.id]
  load_balancers       = [aws_elb.web.name]

  dynamic "tag" {
    for_each = {
      Name   = "WebServer in ASG"
      Owner  = "Max"
      TAGKEY = "TAGVALUE"
    }
    content {
      key                 = "tag.key"
      value               = "tag.value"
      propagate_at_launch = true
    }
  }
  lifecycle {
    create_before_destroy = true
  }
}
#------------------Creating LoadBalancer in 2 availability zones--------
resource "aws_elb" "web" {
  name               = "WebServer-HA-ELB"
  availability_zones = [data.aws_availability_zones.available.names[0], data.aws_availability_zones.available.names[1]]
  security_groups    = [aws_security_group.web.id]
  listener {
    lb_port           = 80 #loadbalancer_port
    lb_protocol       = "http"
    instance_port     = 80
    instance_protocol = "http"
  }
  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:80/"
    interval            = 10 #seconds
  }
  tags = {
    Name = "WebServer-Highly-Available-ELB"
  }
}
#Find subnet id
resource "aws_default_subnet" "default_az1" { #availability zone 1
  availability_zone = data.aws_availability_zones.available.names[0]
}
resource "aws_default_subnet" "default_az2" { #availability zone 2
  availability_zone = data.aws_availability_zones.available.names[0]
}
#------Output--------------
output "web_load_balancer_url" {
  value = aws_elb.web.dns_name
}
