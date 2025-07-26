#1. Security Group
#for ALB (Internet -> ALB) allows public HTTP traffic from the internet
resource "aws_security_group" "alb_sg" {
  name        = "aws-prod-alb-sg"
  description = "Security Group for Application Load Balancer"
  vpc_id      = aws_vpc.custom_vpc.id

  ingress {
    from_port   = 80                   // Allow incoming traffic on port 80 (HTTP)
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]        // Accept from any IP (public internet)
  }

  egress {
    from_port   = 0                    // Allow all outbound traffic
    to_port     = 0
    protocol    = "-1"                 // "-1" means all protocols
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "aws-prod-alb-sg"
  }
}

# Security Group for EC2: accepts traffic ONLY from ALB
resource "aws_security_group" "ec2_sg" {
  name        = "aws-prod-ec2-sg"
  description = "Security Group for Web Server Instances"
  vpc_id      = aws_vpc.custom_vpc.id

  ingress {
    from_port       = 0               // Allow incoming traffic on all ports
    to_port         = 0
    protocol        = "-1"            // All protocols allowed
    security_groups = [aws_security_group.alb_sg.id]  // Only from ALB SG
  }

  egress {
    from_port   = 0                   // Allow all outbound traffic
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "aws-prod-ec2-sg"
  }
}

#2. Application Load Balancer
# Creates an internet-facing Application Load Balancer
resource "aws_lb" "app_lb" {
  name               = "aws-prod-app-lb"
  load_balancer_type = "application"              // HTTP/HTTPS load balancing (Layer 7)
  internal           = false                      // Not internal; exposed to the internet
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = aws_subnet.public_subnet[*].id
  depends_on         = [aws_internet_gateway.igw_vpc]  // Ensure IGW exists before LB
}

# Target group for EC2 instances behind the ALB
resource "aws_lb_target_group" "alb_ec2_tg" {
  name     = "aws-prod-web-server-tg"
  port     = 80                                   // Target EC2 must listen on port 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.custom_vpc.id
  tags = {
    Name = "aws-prod-alb_ec2_tg"
  }
}

# Listener for ALB: defines routing rule for incoming traffic
resource "aws_lb_listener" "alb_listener" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = "80"                         // Listens for HTTP traffic
  protocol          = "HTTP"
  default_action {
    type             = "forward"                   // Send incoming traffic to target group
    target_group_arn = aws_lb_target_group.alb_ec2_tg.arn
  }
  tags = {
    Name = "aws-prod-alb-listener"
  }
}

#3. Launch Template for EC2 Instances
# Template used by Auto Scaling Group to launch EC2 instances
resource "aws_launch_template" "ec2_launch_template" {
  name = "aws-prod-web-server"

  image_id      = "ami-014e30c8a36252ae5"          // Custom AMI ID (Ubuntu or app image)
  instance_type = "t2.micro"                       // Free-tier eligible

  network_interfaces {
    associate_public_ip_address = false            // Instance stays in private subnet
    security_groups             = [aws_security_group.ec2_sg.id]
  }

  user_data = filebase64("userdata.sh")            // Startup script (e.g., install web server)

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "aws-prod-ec2-web-server"
    }
  }
}

# Automatically launches EC2 instances across private subnets
resource "aws_autoscaling_group" "ec2_asg" {
  name                = "aws-prod-web-server-asg"
  desired_capacity    = 2                          // Start with 2 EC2 instances
  min_size            = 2                          // Minimum count
  max_size            = 3                          // Max scalable instances

  target_group_arns   = [aws_lb_target_group.alb_ec2_tg.arn]  // Link EC2s to ALB
  vpc_zone_identifier = aws_subnet.private_subnet[*].id       // Place in private subnets

  launch_template {
    id      = aws_launch_template.ec2_launch_template.id       // Use launch template defined above
    version = "$Latest"
  }

  health_check_type = "EC2"                       // Track instance health via EC2 status
}


# Expose ALB's public DNS name as Terraform output
output "alb_dns_name" {
  value = aws_lb.app_lb.dns_name
}

