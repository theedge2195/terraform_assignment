#------ RDS INSTANCE ------

resource "aws_db_instance" "app_db" {
  allocated_storage      = 10
  engine                 = "mysql"
  engine_version         = "8.0.11"
  instance_class         = "${var.db_instance_class}"
  name                   = "${var.dbname}"
  username               = "${var.dbuser}"
  password               = "${var.dbpassword}"
  db_subnet_group_name   = "${aws_db_subnet_group.app_rds_subnetgroup.name}"
  vpc_security_group_ids = ["${aws_security_group.rds_sg.id}"]
  skip_final_snapshot    = true
}
