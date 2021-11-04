variable "vpc_cidr_block" {
    description = "Main VPC CIDR Block"
}

variable "public_subnets" {
  type = map(string)
}

variable "private_subnets" {
  type = map(string)
}

variable "database_subnets" {
  type = map(string)
}

variable "availability_zones" {
  type = list(string)
}

variable "db_username" {
  type = string
}

variable "db_password" {
  type = string
  sensitive = true
}
