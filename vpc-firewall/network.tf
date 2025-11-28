resource "aws_vpc" "main" {
  cidr_block  = var.vpc_cidr
  enable_dns_support = true
  enable_dns_hostnames = true
  tags={
    Name="vpc-firewall-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
    vpc_id=aws_vpc.main.id
    tags={
        Name="vpc-firewall-igw"
    }
  
}


#public subnet

resource "aws_subnet" "public" {
    vpc_id=aws_vpc.main.id
    cidr_block = var.public_subnet_cidr
    availability_zone = var.az
    tags={Name="vpc-firewall-public-subnet"}
  
}

#private subnet

resource "aws_subnet" "private" {
    vpc_id=aws_vpc.main.id
    cidr_block=var.private_subnet_cidr
    availability_zone = var.az
    tags={Name="vpc-firewall-private-subnet"}
  
}

#firewall subnet

resource "aws_subnet" "firewall" {
    vpc_id=aws_vpc.main.id
    cidr_block=var.firewall_subnet_cidr
    availability_zone = var.az
    tags={Name="vpc-firewall-firewall-subnet"}
}

#NAT gateway (private subnet internet access)

resource "aws_eip" "nat" {
    domain ="vpc"
  
}


resource "aws_nat_gateway" "main" {
    allocation_id = aws_eip.nat.id
    subnet_id = aws_subnet.public.id
    tags={Name="vpc-firewall-nat-gateway"}
    depends_on = [ aws_internet_gateway.igw ]
  
}


resource "aws_route" "public_to_firewall" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "10.0.3.0/24" # Your Private Subnet CIDR
  vpc_endpoint_id        = local.fw_endpoint_id
}