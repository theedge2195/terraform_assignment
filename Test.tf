provider "aws" {
  region  = "${var.aws_region}"
  profile = "${var.aws_profile}"
}

#--- IAM ---

#RDS_Access
resource "aws_iam_instance_profile" "rds_access_profile" {
  name = "rds_access"
  role = "${aws_iam_role.rds_access_role.name}"
}

resource "aws_iam_role_policy" "rds_access_policy" {
  name = "rds_access_policy"
  role = "$(aws_iam_role.rds_access_role.id)"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "rds:*",
            "Resource": "*"
        }
    ]
}
EOF
}

resource "aws_iam_role" "rds_access_role" {
  name = "rds_access_role"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
    {
            "Action": "sts:AssumeRole",
            "Principle": {
                    "Service": "ec2.amazonaws.com"
    },
            "Effect": "Allow",
            "Sid": ""
            }
    ]
}
EOF
}

#--- VPC BASICS ---

#VPC Itself
resource "aws_vpc" "app_vpc" {
  cidr_block           = "${var.vpc_cidr}"
  enable_dns_hostnames = true
  enable_dns_support  = true

  tags {
    Name = "app_vpc"
  }
}

#Internet Gateway
resource "aws_internet_gateway" "app_internet_gateway" {
  vpc_id = "${aws_vpc.app_vpc.id}"

  tags {
    Name = "app_internet_gateway"
  }
}

#---PUBLIC LOAD_BALANCER SUBNETS---
resource "aws_subnet" "load_balancer_subnet1" {
  vpc_id                  = "${aws_vpc.app_vpc.id}"
  cidr_block              = "${var.cidrs["load_balancer"]}"
  map_public_ip_on_launch = false
  availability_zone       = "${data.aws_availability_zones.available.names[0]}"

  tags {
    Name = "public_load_balancer1_subnet"
  }
}

resource "aws_subnet" "load_balancer_subnet2" {
  vpc_id                  = "${aws_vpc.app_vpc.id}"
  cidr_block              = "${var.cidrs["load_balancer"]}"
  map_public_ip_on_launch = false 	
  availability_zone       = "${data.aws_availability_zones.available.names[1]}"
  
  tags {
    Name = "public_load_balancer2_subnet"
  }
}

#---APPLICATION SUBNETS--- 
resource "aws_subnet" "application_subnet1" {
  vpc_id                  = "${aws_vpc.app_vpc.id}"
  cidr_block              = "${var.cidrs["application"]}"
  map_public_ip_on_launch = false
  availability_zone       = "${data.aws_availability_zones.available.names[0]}"

  tags {
    Name = "application1_subnet"
  }
}

resource "aws_subnet" "application_subnet2" {
  vpc_id                  = "${aws_vpc.app_vpc.id}"
  cidr_block              = "${var.cidrs["application"]}"
  map_public_ip_on_launch = false
  availability_zone       = "${data.aws_availability_zones.available.names[1]}"

  tags {
    Name = "application2_subnet"
  }
}

#---DATABASE SUBNETS---
resource "aws_subnet" "database_subnet1" {
  vpc_id                  = "${aws_vpc.app_vpc.id}"
  cidr_block              = "${var.cidrs["database"]}"
  map_public_ip_on_launch = false
  availability_zone       = "${data.aws_availability_zones.available.names[0]}"
  
  tags {
    Name = "database1_subnet"
  }
}

resource "aws_subnet" "database_subnet2" {
  vpc_id                  = "${aws_vpc.app_vpc.id}"
  cidr_block              = "${var.cidrs["database"]}"
  map_public_ip_on_launch = false
  availability_zone       = "${data.aws_availability_zones.available.names[1]}"

  tags {
    Name = "database2_subnet"
  }
}

#---SUBNET GROUPS---DONE
resource "aws_db_subnet_group" "database_subnetgroup" {
  name = "database_subnetgroup"

  subnet_ids = ["${aws_subnet.database_subnet1.id}",
    "${aws_subnet.database_subnet2.id}"
  ]

  tags {
    Name = "database_sng"
  }
}

#Elastic IP
resource "aws_eip" "elastic_ip" {
	vpc = true
}

#NAT Gateway
resource "aws_nat_gateway" "app_nat_gateway" {
  allocation_id = "${aws_eip.elastic_ip.id}"
  subnet_id     = "${aws_subnet.load_balancer_subnet1.id}"
  depends_on    = ["aws_internet_gateway.app_internet_gateway"]

  tags {
    Name = "app_nat_gateway"
  }
}

#---ROUTE TABLES---

#Route Table for Load_Balancer
resource "aws_route_table" "load_balancer_rt" {
  vpc_id = "${aws_vpc.app_vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.app_internet_gateway.id}"
  }

  tags {
    Name = "load_balancer"
  }
}

#Route Table for Application
resource "aws_route_table" "application_rt" {
  vpc_id = "${aws_vpc.app_vpc.id}"

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = "${aws_nat_gateway.app_nat_gateway.id}"
  }

  tags {
    Name = "application"
  }
}

#Route Table for Database
resource "aws_route_table" "database_rt" {
  vpc_id = "${aws_vpc.app_vpc.id}"
  
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = "${aws_nat_gateway.app_nat_gateway.id}"
  }

  tags {
    Name = "database"
  }
}

#---SUBNET ASSOCIATIONS---
resource "aws_route_table_association" "load_balancer1_assoc" {
  subnet_id      = "${aws_subnet.load_balancer_subnet1.id}"
  route_table_id = "${aws_route_table.load_balancer_rt.id}"
}

resource "aws_route_table_association" "load_balancer2_assoc" {
  subnet_id      = "${aws_subnet.load_balancer_subnet2.id}"
  route_table_id = "${aws_route_table.load_balancer_rt.id}"
}

resource "aws_route_table_association" "application1_assoc" {
  subnet_id      = "${aws_subnet.application_subnet1.id}"
  route_table_id = "${aws_route_table.application_rt.id}"
}

resource "aws_route_table_association" "application2_assoc" {
  subnet_id      = "${aws_subnet.application_subnet2.id}"
  route_table_id = "${aws_route_table.application_rt.id}"
}

resource "aws_route_table_association" "database1_assoc" {
  subnet_id      = "${aws_subnet.database_subnet1.id}"
  route_table_id = "${aws_route_table.database_rt.id}"
}

resource "aws_route_table_association" "database2_assoc" {
  subnet_id      = "${aws_subnet.database_subnet2.id}"
  route_table_id = "${aws_route_table.database_rt.id}"
}


data "aws_availability_zones" "available" {}