#------Cidr for the VPC itself
vpc_cidr     = "10.20.0.0/16"

#------Cidrs for the 3 Subnets
#Referenced like "${var.cidrs["database"]}"
cidrs        = {
	database       = "10.20.10.0/24"
	application    = "10.20.20.0/24"
	load_balancer  = "10.20.30.0/24"
}
