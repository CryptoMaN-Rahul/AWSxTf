resource "aws_route_table" "public" {
    vpc_id=aws_vpc.main.id
    route {
        cidr_block="0.0.0.0/0"
        gateway_id = aws_internet_gateway.igw.id
    }

    tags={Name="vpc-firewall-public-rt"}
  
}
resource "aws_route_table_association" "public" {
    subnet_id=aws_subnet.public.id
    route_table_id=aws_route_table.public.id
}


#firewall traffic to nat

resource "aws_route_table" "firewall" {
    vpc_id = aws_vpc.main.id
    route{
        cidr_block="0.0.0.0/0"
        nat_gateway_id = aws_nat_gateway.main.id
    }
    tags={Name="vpc-firewall-firewall-rt"}
  
}

resource "aws_route_table_association" "firewall" {
    subnet_id = aws_subnet.firewall.id
    route_table_id = aws_route_table.firewall.id
  
}

#private subnet route table ,traffic goes to firewall
# Helper to find the specific Firewall Endpoint ID for our AZ
locals {
  # This magic loop grabs the Endpoint ID specifically for the AZ we chose
  fw_endpoint_id = [
    for i in aws_networkfirewall_firewall.main.firewall_status[0].sync_states : i.attachment[0].endpoint_id
    if i.availability_zone == var.az
  ][0]
}


resource "aws_route_table" "private" {
    vpc_id = aws_vpc.main.id


    route{
    cidr_block="0.0.0.0/0"
    vpc_endpoint_id = local.fw_endpoint_id
}


    tags={Name="vpc-firewall-private-rt"}
  
}


resource "aws_route_table_association" "private" {
    subnet_id = aws_subnet.private.id
    route_table_id = aws_route_table.private.id
  
}



