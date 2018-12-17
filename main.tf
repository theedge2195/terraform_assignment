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

#--- VPC ---

#VPC Itself
resource "aws_vpc" "app_vpc" {
  cidr_block           = "${var.vpc_cidr}"
  enable_dns_hostnames = true
  enables_dns_support  = true

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

####THIS IS GOING TO STAY COMMENTED OUT UNTIL I CAN CONFIRM THIS BLOCK ISN'T NEEDED
#Elastic IP Address(Used for the NAT Gateway)
#resource "aws_eip" "app_eip" {

####NAT GATEWAY NEEDS TO BE EDITED FOR EIP ASSOCIATION CONFUSION
#NAT Gateway
resource "aws_nat_gateway" "app_nat_gateway" {
  allocation_id = "${aws_eip.app_nat_gateway.id}"
  subnet_id     = "${aws_subnet.load_balancer.id}"
  depends_on    = ["aws_internet_gateway.app_internet_gateway"]

  tags {
    Name = "app_nat_gateway"
  }
}

#May have to troubleshoot tag names below on route tables
#Route Table for Load_Balancer
resource "aws_route_table" "load_balancer_rt" {
  vpc_id = "${aws_vpc.app_vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.app_internet_gateway.id}"
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = "${aws_internet_gateway.app_internet_gateway.id}"
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

  route {
    ipv6_cidr_block = "::/0"
    nat_gateway_id  = "${aws_nat_gateway.app_nat_gateway.id}"
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

#NACL for Load_Balancer
resource "aws_network_acl" "load_balancer_nacl" {
  vpc_id = "${aws_vpc.app_vpc.id}"

  egress {
    protocol   = "tcp"
    rule_no    = 200
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 200
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  egress {
    protocol   = "tcp"
    rule_no    = 300
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 300
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }
}

#NOT CORRECT		
#NACL for Application
resource "aws_network_acl" "application_nacl" {
  vpc_id = "${aws_vpc.app_vpc.id}"

  egress {
    protocol   = "tcp"
    rule_no    = 200
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 200
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }
}

#NOT CORRECT
#NACL for Database
resource "aws_network_acl" "database_nacl" {
  vpc_id = "${aws_vpc.app_vpc.id}"

  egress {
    protocol   = "tcp"
    rule_no    = 200
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 200
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }
}

#LOAD_BALANCER SUBNET
resource "aws_subnet" "load_balancer_subnet" {
  vpc_id                  = "${aws_vpc.app_vpc.id}"
  cidr_block              = "${var.cidrs["load_balancer"]}"
  map_public_ip_on_launch = false

  #Above is false because the entire thing is going to depend on a single domain name.
  #If it isn't, it allows potential connections to one single server and potential DOS. 	
  ####NOT A HUGE FAN OF THIS IMPLEMENTATION, due to complexity####   availability_zone = "${data.aws_availability_zones.available.names[0]}"

  tags {
    Name = "load_balancer"
  }
}

#APPLICATION SUBNET
resource "aws_subnet" "application_subnet" {
  vpc_id                  = "${aws_vpc.app_vpc.id}"
  cidr_block              = "${var.cidrs["application"]}"
  map_public_ip_on_launch = false

  ####NOT A HUGE FAN OF THIS IMPLEMENTATION####   availability_zone = "${data.aws_availability_zones.available.names[0]}"

  tags {
    Name = "load_balancer"
  }
}

#DATABASE SUBNET
resource "aws_subnet" "database_subnet" {
  vpc_id                  = "${aws_vpc.app_vpc.id}"
  cidr_block              = "${var.cidrs["database"]}"
  map_public_ip_on_launch = false

  ####NOT A HUGE FAN OF THIS IMPLEMENTATION####   availability_zone = "${data.aws_availability_zones.available.names[0]}"

  tags {
    Name = "load_balancer"
  }
}

#------ Load Balancer ------

resource "aws_lb" "app_load_balancer" {
  name               = "app_load_balancer"
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["${aws_security group.load_balancer_sg.id}"]
  subnets            = ["${aws_subnet.load_balancer_subnet.id}"]
}

resource "aws_lb_target_group" "app_load_balancer_tg" {
  name     = "app_load_balancer_tg"
  vpc_id   = "${aws_vpc.app_vpc.id}"
  port     = 80
  protocol = "HTTP"

  health_check {
    port                = "80"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    internal            = 5
    timeout             = 4
    matcher             = "200-308"
  }
}

resource "aws_alb_target_group_attachment" "app_load_balancer_attachment" {
  target_group_arn = "${aws_lb_target_group.app_load_balancer_tg.id}"
  target_id        = "${aws_instance.INSTANCE MADE BY AUTOSCALING GROUP}"
}

resource "aws_alb_target_group_attachment" "app_load_balancer_attachment" {
  target_group_arn = "${aws_lb_target_group.app_load_balancer_tg.id}"
  target_id        = "${aws_instance.INSTANCE MADE BY AUTOSCALING GROUP}"
}

resource "aws_lb_listener_certificate" "app_load_balancer_certificate" {
  listener_arn    = "${aws_alb_listener.alb_front_https.arn}"
  certificate_arn = "${aws_iam_server_certificate.url3_valouille_fr.arn}"
}

resource "aws_lb_listener" "app_load_balancer_redirect" {
  load_balancer_arn = "${aws_lb.app_load_balancer.id}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "app_load_balancer_https" {
  load_balancer_arn = "${aws_lb.app_load_balancer.id}"
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = "${aws_iam_server_certificate.CERTIFICATE ID WILL GO HERE}"

  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.app_load_balancer_tg}"
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
  db_subnet_group_name   = "${aws_db_subnet_group.wp_rds_subnetgroup.name}"
  vpc_security_group_ids = ["${aws_security_group.wp_rds_sg.id}"]
  skip_final_snapshot    = true
}

#------ Golden AMI ------

#Random ami id

resource "random_id" "golden_ami" {
  byte_length = 3
}

# AMI

resource "aws_ami_from_instance" "wp_golden" {
  name               = "wp_ami-${random_id.golden_ami.b64}"
  source_instance_id = "${aws_instance.wp_dev.id}"

  provisioner "local-exec" {
    command = <<EOT
cat <<EOF > userdata
#!/bin/bash
/usr/bin/aws s3 sync s3://${aws_s3_bucket.code.bucket} /var/www/html/
/bin/touch /var/spool/cron/root
sudo /bin/echo '*/5 * * * * aws s3 sync s3://${aws_s3_bucket.code.bucket} /var/www/html' >> /var/spool/cron/root
EOF
EOT
  }
}
