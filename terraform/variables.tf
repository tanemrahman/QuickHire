variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "key_name" {
  type = string
}

variable "instance_ami" {
  type = string
}

variable "master_instance_type" {
  type    = string
  default = "t3.medium"
}

variable "worker_instance_type" {
  type    = string
  default = "t3.small"
}

variable "project_name" {
  type    = string
  default = "quickhire"
}

variable "ssh_cidr" {
  type    = string
  default = "0.0.0.0/0"
}

variable "kubernetes_version" {
  type    = string
  default = "1.29"
}