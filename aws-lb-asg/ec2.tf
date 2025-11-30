
resource "aws_security_group" "lb_sg" {
  name        = "alb-sg"
  description = "Security group for ALB"
  vpc_id      = aws_vpc.main.id
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
  tags = {
    Name = "${var.project_name}-lb-sg"
  }

}



resource "aws_security_group" "ec2" {
  name        = "ec2-sg"
  description = "Security group for ec2"
  vpc_id      = aws_vpc.main.id
  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.lb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.project_name}-ec2-sg"
  }

}



resource "aws_lb" "application_lb" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_sg.id]
  subnets            = aws_subnet.public[*].id
  depends_on         = [aws_internet_gateway.main]
  tags = {
    Name = "${var.project_name}-alb"
  }
}


resource "aws_lb_target_group" "alb_ec2_tg" {
  name     = "web-server-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  tags = {
    Name = "${var.project_name}-alb-ec2-tg"
  }
}

resource "aws_lb_listener" "alb_listener" {
  load_balancer_arn = aws_lb.application_lb.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_ec2_tg.arn
  }
  tags = {
    Name = "${var.project_name}-alb-listener"
  }

}




# IAM Role for Web Servers
resource "aws_iam_role" "web_server_role" {
  name = "${var.project_name}-web-server-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-web-server-role"
  }
}

# Attach CloudWatch and SSM policies
resource "aws_iam_role_policy_attachment" "web_cloudwatch" {
  role       = aws_iam_role.web_server_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy_attachment" "web_ssm" {
  role       = aws_iam_role.web_server_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "web_server_profile" {
  name = "${var.project_name}-web-server-profile"
  role = aws_iam_role.web_server_role.name
}

##launch template for ASG t3 large with image id 

resource "aws_launch_template" "web_server_lt" {
  name_prefix = "${var.project_name}-lt-"
  image_id    = "ami-0ecb62995f68bb549"

  instance_type = "t3.large"
  iam_instance_profile {
    name = aws_iam_instance_profile.web_server_profile.name
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.ec2.id]
  }
  user_data = base64encode(<<-EOF
                #!/bin/bash
                set -e
                
                # Update system
                yum update -y
                
                # Install and configure Apache
                yum install -y httpd
                systemctl start httpd
                systemctl enable httpd
                
                # Create a simple web page with instance info
                INSTANCE_ID=$(ec2-metadata --instance-id | cut -d " " -f 2)
                AVAILABILITY_ZONE=$(ec2-metadata --availability-zone | cut -d " " -f 2)
                
                cat > /var/www/html/index.html <<HTML
                <!DOCTYPE html>
                <html>
                <head><title>Web Server</title></head>
                <body>
                  <h1>Welcome to the Web Server!</h1>
                  <p>Instance ID: $INSTANCE_ID</p>
                  <p>Availability Zone: $AVAILABILITY_ZONE</p>
                  <p>Server Time: $(date)</p>
                </body>
                </html>
HTML
                
                # Install CloudWatch Agent
                wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
                rpm -U ./amazon-cloudwatch-agent.rpm
                
                # Configure CloudWatch Agent
                cat > /opt/aws/amazon-cloudwatch-agent/etc/config.json <<'CW_CONFIG'
                {
                  "metrics": {
                    "namespace": "WebServers",
                    "metrics_collected": {
                      "cpu": {
                        "measurement": [
                          {"name": "cpu_usage_idle", "rename": "CPU_IDLE", "unit": "Percent"},
                          {"name": "cpu_usage_iowait", "rename": "CPU_IOWAIT", "unit": "Percent"}
                        ],
                        "metrics_collection_interval": 60,
                        "totalcpu": false
                      },
                      "disk": {
                        "measurement": [{"name": "used_percent", "rename": "DISK_USED", "unit": "Percent"}],
                        "metrics_collection_interval": 60,
                        "resources": ["*"]
                      },
                      "mem": {
                        "measurement": [{"name": "mem_used_percent", "rename": "MEM_USED", "unit": "Percent"}],
                        "metrics_collection_interval": 60
                      },
                      "netstat": {
                        "measurement": [
                          {"name": "tcp_established", "rename": "TCP_CONNECTIONS", "unit": "Count"}
                        ],
                        "metrics_collection_interval": 60
                      }
                    }
                  },
                  "logs": {
                    "logs_collected": {
                      "files": {
                        "collect_list": [
                          {
                            "file_path": "/var/log/httpd/access_log",
                            "log_group_name": "/aws/ec2/${var.project_name}",
                            "log_stream_name": "{instance_id}/apache-access"
                          },
                          {
                            "file_path": "/var/log/httpd/error_log",
                            "log_group_name": "/aws/ec2/${var.project_name}",
                            "log_stream_name": "{instance_id}/apache-error"
                          }
                        ]
                      }
                    }
                  }
                }
CW_CONFIG
                
                # Start CloudWatch Agent
                /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
                  -a fetch-config \
                  -m ec2 \
                  -s \
                  -c file:/opt/aws/amazon-cloudwatch-agent/etc/config.json
                
                echo "Web server setup complete!"
                EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-web-server"
    }
  }
}



resource "aws_autoscaling_group" "ec2_asg" {
  max_size            = 6
  min_size            = 3
  desired_capacity    = 3
  name                = "${var.project_name}-asg"
  target_group_arns   = [aws_lb_target_group.alb_ec2_tg.arn]
  vpc_zone_identifier = aws_subnet.private[*].id
  launch_template {
    id      = aws_launch_template.web_server_lt.id
    version = "$Latest"
  }
  health_check_type = "EC2"
}

output "alb_dns_name" {
  value = aws_lb.application_lb.dns_name

}