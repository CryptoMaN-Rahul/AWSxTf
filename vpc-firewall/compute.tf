

resource "aws_iam_role" "ssm_role" {
  name = "ssm"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}


resource "aws_iam_role_policy_attachment" "ssm_policy" {
    role=aws_iam_role.ssm_role.name
    policy_arn="arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  
}

resource "aws_iam_instance_profile" "ssm_profile" {
    name="ssm-instance-profile"
    role=aws_iam_role.ssm_role.name
  
}


resource "aws_security_group" "ec2_sg" {
    name="private-sg"
    description = "allow all outbound traffic"
    vpc_id = aws_vpc.main.id

    egress{
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

  
}

resource "aws_instance" "private_instance_server" {

    ami=var.private_instance_ami
    instance_type=var.instance_type
    subnet_id=aws_subnet.private.id
    iam_instance_profile = aws_iam_instance_profile.ssm_profile.name
 
    vpc_security_group_ids = [aws_security_group.ec2_sg.id]

   tags={
        Name="vpc-firewall-private-ec2"
    }
}