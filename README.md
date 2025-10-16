# terraform-nginx-ecs-fargate

Terraform code to deploy Nginx on AWS ECS using Fargate or EC2 launch types.

![Nginx ECS  fargate](https://github.com/user-attachments/assets/ca37e882-3da2-49d8-a0f1-24e98fcd0e03)

## Overview

This repository contains Terraform modules that provision an Nginx web server running on AWS ECS (Elastic Container Service), with support for both Fargate and EC2 launch types. The infrastructure includes an Application Load Balancer (ALB), VPC/subnets integration, auto-scaling (for EC2), IAM roles, and CloudWatch logging. The solution is ideal for quickly launching a containerized Nginx service with a customizable web page.

## Features

- Deploys Nginx on AWS ECS using either Fargate or EC2
- Provisions an Application Load Balancer and target groups
- Supports custom cluster name, VPC, and subnets
- Configurable EC2 instance type and scaling parameters (for EC2 launch type)
- Manages IAM roles for ECS task execution
- Defines CloudWatch log groups for ECS service logging
- Outputs useful information such as cluster name, ALB DNS, service name, and application URL

## Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) >= 1.0
- AWS account with adequate permissions
- An existing VPC and subnets in your AWS account

## Usage

1. **Clone the repository:**

   ```bash
   git clone https://github.com/muralikrishna-sunkara/terraform-nginx-ecs-fargate.git
   cd terraform-nginx-ecs-fargate
   ```

2. **Update variables:**

   Edit `variables.tf` or use a `terraform.tfvars` file to specify your AWS region, cluster name, VPC ID, subnet IDs, and other parameters.

   Example `terraform.tfvars`:
   ```hcl
   cluster_name = "my-nginx-cluster"
   vpc_id       = "vpc-xxxxxx"
   subnet_ids   = ["subnet-aaaaaa", "subnet-bbbbbb"]
   launch_type  = "FARGATE" # or "EC2"
   ```

3. **Initialize and apply Terraform:**

   ```bash
   terraform init
   terraform apply
   ```

   Confirm the plan and wait for deployment to complete.

4. **Access your application:**

   The output will provide the ALB DNS name and URL. Open this in your browser to view the Nginx welcome page.

## Variables

Key configurable variables (see `variables.tf` for details):

- `aws_region`: AWS region to deploy resources (default: `eu-central-1`)
- `cluster_name`: Name for your ECS cluster
- `vpc_id`: VPC ID where resources are created
- `subnet_ids`: List of subnet IDs for ECS and ALB
- `launch_type`: ECS launch type (`FARGATE` or `EC2`)
- `instance_type`: EC2 instance type (for EC2 launch type)
- `desired_capacity`, `min_capacity`, `max_capacity`: Scaling parameters for EC2
- `key_name`: SSH key pair name (for EC2)

## Outputs

After deployment, Terraform provides:

- `cluster_id`: ECS Cluster ID
- `cluster_name`: ECS Cluster Name
- `alb_dns_name`: DNS name of the Application Load Balancer
- `application_url`: URL to access the Nginx web app
- `service_name`: ECS Service Name

## Customization

You can customize the Nginx welcome page by modifying the HTML rendered in the ECS task definition inside `modules/ecs-cluster/main.tf`.

## Clean Up

To destroy the infrastructure:

```bash
terraform destroy
```

## License

This project is open-source and available under the [MIT License](LICENSE).

## Author

Maintained by [muralikrishna-sunkara](https://github.com/muralikrishna-sunkara).
