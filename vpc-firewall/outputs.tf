output "instance_id"{
    description="ID of the private EC2 instance"
    value=aws_instance.private_instance_server.id
}


output "connect_command"{
    description="Command to connect to the private EC2 instance via SSM"
    value="aws ssm start-session --target ${aws_instance.private_instance_server.id} --region ${var.region}"
}


output "vpc_id"{
    description="ID of the created VPC"
    value=aws_vpc.main.id
}

output "firewall_endpoint" {
    description="Network Firewall Endpoint ID for the selected AZ"
    value=local.fw_endpoint_id
  
}
output "nat_gateway_id" {
    description="ID of the NAT Gateway"
    value=aws_nat_gateway.main.id
}


output "internet_gateway_id" {
    description="ID of the Internet Gateway"
    value=aws_internet_gateway.igw.id
}

output "public_subnet_id" {
    description="ID of the public subnet"
    value=aws_subnet.public.id
}
output "private_subnet_id" {
    description="ID of the private subnet"
    value=aws_subnet.private.id
}

output "firewall_subnet_id" {
    description="ID of the firewall subnet"
    value=aws_subnet.firewall.id      

}
