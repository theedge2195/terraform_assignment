#------Cidr for the VPC itself
vpc_cidr     = "10.20.0.0/16"

#------Cidrs for the 3 Subnets
#Referenced like "${var.cidrs["database"]}"
cidrs        = {
	database       = "10.20.10.0/24"
	application    = "10.20.20.0/24"
	load_balancer  = "10.20.30.0/24"
}

#-------Availability Zones for Various Purposes
#Referenced like "${var.availability_zones["1"]}"
availability_zones = {
	az1 = "us-east-1a"
	az2 = "us-east-1b"
	az3 = "us-east-1c"
}
#-------