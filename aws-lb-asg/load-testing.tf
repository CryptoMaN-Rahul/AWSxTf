# Security Group for Load Testing Instance
resource "aws_security_group" "load_tester_sg" {
  name        = "${var.project_name}-load-tester-sg"
  description = "Security group for load testing instance"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow SSH from anywhere"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-load-tester-sg"
  }
}

# IAM Role for Load Testing Instance
resource "aws_iam_role" "load_tester_role" {
  name = "${var.project_name}-load-tester-role"

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
    Name = "${var.project_name}-load-tester-role"
  }
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "load_tester_profile" {
  name = "${var.project_name}-load-tester-profile"
  role = aws_iam_role.load_tester_role.name
}

# Attach CloudWatch policy to the role
resource "aws_iam_role_policy_attachment" "cloudwatch_policy" {
  role       = aws_iam_role.load_tester_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Load Testing Instance (Apache Bench + Siege)
resource "aws_instance" "load_tester" {
  ami                    = "ami-0ecb62995f68bb549" # Amazon Linux 2023
  instance_type          = "t3.medium"
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.load_tester_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.load_tester_profile.name
  key_name               = var.ssh_key_name

  associate_public_ip_address = true

  user_data = templatefile("${path.module}/load-test-userdata.sh", {
    alb_dns = aws_lb.application_lb.dns_name
  })

  tags = {
    Name = "${var.project_name}-load-tester"
  }

  depends_on = [aws_lb.application_lb]
}

# Output for SSH access (if needed)
output "load_tester_public_ip" {
  description = "Public IP of load testing instance"
  value       = aws_instance.load_tester.public_ip
}

output "load_test_commands" {
  description = "Commands to run load tests"
  value = <<-EOT
    SSH into the load tester instance and run:
    
    # Light load (100 requests, 10 concurrent)
    ab -n 1000 -c 10 http://${aws_lb.application_lb.dns_name}/
    
    # Medium load (10000 requests, 50 concurrent)
    ab -n 10000 -c 50 http://${aws_lb.application_lb.dns_name}/
    
    # Heavy load (50000 requests, 100 concurrent)
    ab -n 50000 -c 100 http://${aws_lb.application_lb.dns_name}/
    
    # Continuous siege for 2 minutes
    siege -c 100 -t 2M http://${aws_lb.application_lb.dns_name}/
    
    # Extreme load (use carefully!)
    siege -c 200 -t 5M http://${aws_lb.application_lb.dns_name}/
  EOT
}
