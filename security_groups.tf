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
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#private security group

resource "aws_security_group" "wp_private_sg" {
  name        = "wp_private_sg"
  description = "Used for the instances to securely connect to private resources"
  vpc_id      = "${aws_vpc.wp_vpc.id}"

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

resource "aws_security_group" "wp_rds_sg" {
  name        = "wp_rds_sg"
  description = "Used for RDS instances"
  vpc_id      = "${aws_vpc.wp_vpc.id}"

  #sql access from public/private security groups

  ingress {
    from_port = 3306
    to_port   = 3306
    protocol  = "tcp"

    security_groups = ["${aws_security_group.wp_dev_sg.id}",
      "${aws_security_group.wp_public_sg.id}",
      "${aws_security_group.wp_private_sg.id}",
    ]
  }
}
