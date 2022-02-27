variable "name" {
  description = "the name of your stack, e.g. \"demo\""
  default     = "nextjs-aws-terraform"
}

variable "env" {
  description = "the name of your environment, e.g. \"prod\""
  default     = "stage"
}

variable "region" {
  description = "the AWS region in which resources are created, you must set the availability_zones variable as well if you define this value to something other than the default"
  default     = "ap-southeast-1"
}