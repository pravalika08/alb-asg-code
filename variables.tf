variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "aws_region" {}
variable "instance_type" {
  type = string
}
variable "ami_type" {
  type = map
  default = {
    "us-east-2"  = "ami-077e31c4939f6a2f3"
    "ap-south-1" = "ami-010aff33ed5991201"
  }
}
variable "key_name" {
  type = string
}
variable "vpc_cidr" {
  default = "10.0.0.0/16"
}
variable "cidr_public_subnet_1a" {
  default = "10.0.1.0/24"
}
variable "cidr_public_subnet_1b" {
  default = "10.0.2.0/24"
}
variable "launch_configuration_name" {
  type = string
}
variable "aws_autoscaling_group_name" {
  type = string
}
variable "image_id" {
  type    = string
  default = "image-id-based-on-the-region"
}
