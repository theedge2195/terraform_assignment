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

#NACL for Load_Balancer
resource "aws_network_acl" "load_balancer_nacl" {
  vpc_id = "${aws_vpc.app_vpc.id}"

  egress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  egress {
    protocol   = "tcp"
    rule_no    = 200
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 200
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }
}
	
#NACL for Application
resource "aws_network_acl" "application_nacl" {
  vpc_id = "${aws_vpc.app_vpc.id}"

  egress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "10.20.30.0/24"
    from_port  = 443
    to_port    = 443
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "10.20.30.0/24"
    from_port  = 443
    to_port    = 443  
  }
  
  egress {
    protocol   = "tcp"
    rule_no    = 200
    action     = "allow"
    cidr_block = "10.20.10.0/24"
    from_port  = 3306
    to_port    = 3306
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 200
    action     = "allow"
    cidr_block = "10.20.10.0/24"
    from_port  = 3306
    to_port    = 3306 
  }
}

#NACL for Database
resource "aws_network_acl" "database_nacl" {
  vpc_id = "${aws_vpc.app_vpc.id}"

  egress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "10.20.20.0/24"
    from_port  = 3306
    to_port    = 3306
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "10.20.20.0/24"
    from_port  = 3306
    to_port    = 3306
  }
}

#------Security Groups------

#public load balancer security group

resource "aws_security_group" "public_load_balancer_sg" {
  name        = "public_load_balancer_sg"
  description = "Used for the elastic load balancer for public access"
  vpc_id      = "${aws_vpc.app_vpc.id}"

  #http

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  #https

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


#private security group

resource "aws_security_group" "application_sg" {
  name        = "application_sg"
  description = "Used for the instances to securely connect to private resources"
  vpc_id      = "${aws_vpc.app_vpc.id}"

  #http

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["${var.vpc_cidr}"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#rds security group

resource "aws_security_group" "database_sg" {
  name        = "database_sg"
  description = "Used for RDS instances"
  vpc_id      = "${aws_vpc.app_vpc.id}"

  #sql access from public/private security groups

  ingress {
    from_port = 3306
    to_port   = 3306
    protocol  = "tcp"

    security_groups = ["${aws_security_group.application_sg.id}"]
  }
}

#------ RDS INSTANCE ------

resource "aws_db_instance" "app_db" {
  allocated_storage      = 10
  engine                 = "mysql"
  engine_version         = "8.0.11"
  instance_class         = "${var.db_instance_class}"
  name                   = "${var.dbname}"
  username               = "${var.dbuser}"
  password               = "${var.dbpassword}"
  db_subnet_group_name   = "${aws_db_subnet_group.database_subnetgroup.name}"
  vpc_security_group_ids = ["${aws_security_group.database_sg.id}"]
  skip_final_snapshot    = true
}