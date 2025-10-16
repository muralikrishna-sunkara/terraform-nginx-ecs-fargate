variable "cluster_name" {
  description = "Name of the ECS cluster"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where resources will be created"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for ECS services and ALB"
  type        = list(string)
}

variable "launch_type" {
  description = "ECS launch type: EC2 or FARGATE"
  type        = string
  default     = "FARGATE"
  validation {
    condition     = contains(["EC2", "FARGATE"], var.launch_type)
    error_message = "Launch type must be either EC2 or FARGATE"
  }
}

variable "instance_type" {
  description = "EC2 instance type for ECS container instances (only used with EC2 launch type)"
  type        = string
  default     = "t3.micro"
}

variable "desired_capacity" {
  description = "Desired number of EC2 instances (only used with EC2 launch type)"
  type        = number
  default     = 2
}

variable "max_capacity" {
  description = "Maximum number of EC2 instances (only used with EC2 launch type)"
  type        = number
  default     = 4
}

variable "min_capacity" {
  description = "Minimum number of EC2 instances (only used with EC2 launch type)"
  type        = number
  default     = 2
}

variable "key_name" {
  description = "SSH key pair name for EC2 instances (only used with EC2 launch type)"
  type        = string
  default     = ""
}