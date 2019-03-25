# Resources:
# https://registry.terraform.io/
# https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/1.60.0
# https://www.terraform.io/docs/providers/aws/
# https://registry.terraform.io/modules/terraform-aws-modules/ec2-instance/aws/1.21.0
#
#
# https://www.terraform.io/docs/providers/aws/r/default_route_table.html
# https://www.terraform.io/docs/providers/aws/r/default_network_acl.html
# https://www.terraform.io/docs/providers/aws/r/default_security_group.html
#
#######################################################################
#
# Define provider, keys and region:
# https://learn.hashicorp.com/terraform/getting-started/build
# https://www.terraform.io/docs/providers/aws/
# https://learn.hashicorp.com/terraform/getting-started/variables

provider "aws" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region     = "us-east-1"
}

#######################################################################
#
# Define VPC and CIDR Block:
# Creates default RT & NACL.
# https://www.terraform.io/docs/providers/aws/r/vpc.html
# https://www.terraform.io/docs/providers/aws/d/vpc.html

resource "aws_vpc" "tfvpc" {
  cidr_block = "10.2.0.0/16"

  #instance_tenancy = "dedicated"

  tags = {
    Name = "c2vpc"
  }
}

#######################################################################
#
# Define Internet Gateway and attach to VPC:
# https://www.terraform.io/docs/providers/aws/r/internet_gateway.html
# https://www.terraform.io/docs/providers/aws/d/internet_gateway.html

resource "aws_internet_gateway" "tfigw" {
  vpc_id = "${aws_vpc.tfvpc.id}"

  tags = {
    Name = "c2igw"
  }
}

#######################################################################
#
# Define Route Table and set route to Internet Gateway:
# https://www.terraform.io/docs/providers/aws/r/route_table.html
# https://www.terraform.io/docs/providers/aws/d/route_table.html

resource "aws_route_table" "tfrt" {
  vpc_id = "${aws_vpc.tfvpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.tfigw.id}"
  }

  tags = {
    Name = "c2rt"
  }
}

#######################################################################
#
# Set main Route Table:
# https://www.terraform.io/docs/providers/aws/r/main_route_table_assoc.html

resource "aws_main_route_table_association" "tfmainrt" {
  vpc_id         = "${aws_vpc.tfvpc.id}"
  route_table_id = "${aws_route_table.tfrt.id}"
}

#######################################################################
#
# Define inbound and outbound NACL rules and apply to Subnet(s):
# https://www.terraform.io/docs/providers/aws/r/network_acl.html

resource "aws_network_acl" "tfnacl" {
  vpc_id     = "${aws_vpc.tfvpc.id}"
  subnet_ids = ["${aws_subnet.tfsn.id}"]

  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 22
    to_port    = 22
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 110
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 120
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 130
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  egress {
    protocol   = "all"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    Name = "c2nacl"
  }
}

#######################################################################
#
# Define Subnet:
# Associates with default RT & NACL.
# https://www.terraform.io/docs/providers/aws/r/subnet.html
# https://www.terraform.io/docs/providers/aws/d/subnet.html

resource "aws_subnet" "tfsn" {
  vpc_id     = "${aws_vpc.tfvpc.id}"
  cidr_block = "10.2.2.0/24"

  tags = {
    Name = "c2sn"
  }
}

#######################################################################
#
# Define association between subnet and route table:
# https://www.terraform.io/docs/providers/aws/r/route_table_association.html

resource "aws_route_table_association" "tfsnrt" {
  subnet_id      = "${aws_subnet.tfsn.id}"
  route_table_id = "${aws_route_table.tfrt.id}"
}

#######################################################################
#
# Define association between subnet and Network ACL:
# Resolved in resource "aws_network_acl" section.

#######################################################################
#
# Define Security Group:
# https://www.terraform.io/docs/providers/aws/r/security_group.html

resource "aws_security_group" "tfsg" {
  #name        = "Group Name"  #description = "Allow TLS inbound traffic"
  vpc_id = "${aws_vpc.tfvpc.id}"

  ingress {
    # SSH
    from_port = 22
    to_port   = 22
    protocol  = "tcp"

    # Please restrict your ingress to only necessary IPs and ports.
    # Opening to 0.0.0.0/0 can lead to security vulnerabilities.
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    # HTTP
    from_port = 80
    to_port   = 80
    protocol  = "tcp"

    # Please restrict your ingress to only necessary IPs and ports.
    # Opening to 0.0.0.0/0 can lead to security vulnerabilities.
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "c2sg"
  }
}

#######################################################################
#
# Define EC2 Instance:
# https://www.terraform.io/docs/providers/aws/r/instance.html
# https://registry.terraform.io/modules/terraform-aws-modules/ec2-instance/aws/1.21.0

resource "aws_instance" "tfec2" {
  #ami                    = "ami-2757f631"
  ami                    = "ami-0080e4c5bc078760e"
  instance_type          = "t2.micro"
  vpc_security_group_ids = ["${aws_security_group.tfsg.id}"]
  subnet_id              = "${aws_subnet.tfsn.id}"

  tags = {
    Name = "c2ec2"
  }
}
