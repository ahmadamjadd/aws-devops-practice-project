# 1. Find the Default VPC
data "aws_vpc" "default" {
  default = true
}

# 2. Find the Subnets inside that VPC
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}