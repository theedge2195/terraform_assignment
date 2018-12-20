aws_profile = "test_user"
aws_region = "us-east-1"
vpc_cidr     = "10.20.0.0/16"
cidrs        = {
	database       = "10.20.10.0/24"
	application    = "10.20.20.0/24"
	load_balancer  = "10.20.30.0/24"
}
db_instance_class = "t2.micro"
dbname = "test"
dbuser = "testuser"
dbpassword = "testpass"
