variable "name" {
  description = "the name of your stack, e.g. \"demo\""
  default     = "nextjs-aws-terraform"
}

variable "env" {
  description = "the name of your environment, e.g. \"prod\""
  default     = "stage"
}

variable "cidr" {
  description = "The CIDR block for the VPC."
  default     = "10.0.0.0/16"
}

variable "subnet_public_cidrblock" {
  default = [
    "10.0.1.0/24",
    "10.0.2.0/24"
  ]
  type = list(string)
}

variable "subnet_private_cidrblock" {
  default = [
    "10.0.11.0/24",
    "10.0.22.0/24"
  ]
  type = list(string)
}
