# Data source for Ubuntu ECS-optimized AMI (only needed for EC2)
data "aws_ssm_parameter" "ecs_ami" {
  count = var.launch_type == "EC2" ? 1 : 0
  name  = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = var.cluster_name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = var.cluster_name
  }
}

# Capacity providers - only for EC2 launch type
resource "aws_ecs_cluster_capacity_providers" "main" {
  count        = var.launch_type == "EC2" ? 1 : 0
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = [aws_ecs_capacity_provider.main[0].name]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = aws_ecs_capacity_provider.main[0].name
  }
}

# IAM Role for EC2 instances (only for EC2 launch type)
resource "aws_iam_role" "ecs_instance_role" {
  count = var.launch_type == "EC2" ? 1 : 0
  name  = "${var.cluster_name}-ecs-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_instance_role_policy" {
  count      = var.launch_type == "EC2" ? 1 : 0
  role       = aws_iam_role.ecs_instance_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

# Attach SSM policy for Session Manager access (only for EC2 launch type)
resource "aws_iam_role_policy_attachment" "ecs_instance_ssm_policy" {
  count      = var.launch_type == "EC2" ? 1 : 0
  role       = aws_iam_role.ecs_instance_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ecs_instance_profile" {
  count = var.launch_type == "EC2" ? 1 : 0
  name  = "${var.cluster_name}-ecs-instance-profile"
  role  = aws_iam_role.ecs_instance_role[0].name
}

# Security Group for EC2 instances (only for EC2 launch type)
resource "aws_security_group" "ecs_instance_sg" {
  count       = var.launch_type == "EC2" ? 1 : 0
  name        = "${var.cluster_name}-ecs-instance-sg"
  description = "Security group for ECS container instances"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Allow HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  ingress {
    description     = "Allow dynamic ports from ALB"
    from_port       = 32768
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cluster_name}-ecs-instance-sg"
  }
}

# Security Group for Fargate tasks (only for Fargate launch type)
resource "aws_security_group" "fargate_task_sg" {
  count       = var.launch_type == "FARGATE" ? 1 : 0
  name        = "${var.cluster_name}-fargate-task-sg"
  description = "Security group for Fargate ECS tasks"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Allow HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cluster_name}-fargate-task-sg"
  }
}

# Security Group for ALB
resource "aws_security_group" "alb_sg" {
  name        = "${var.cluster_name}-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow HTTP traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cluster_name}-alb-sg"
  }
}

# Launch Template for EC2 instances (only for EC2 launch type)
resource "aws_launch_template" "ecs_instance" {
  count         = var.launch_type == "EC2" ? 1 : 0
  name_prefix   = "${var.cluster_name}-"
  image_id      = data.aws_ssm_parameter.ecs_ami[0].value
  instance_type = var.instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.ecs_instance_profile[0].name
  }

  vpc_security_group_ids = [aws_security_group.ecs_instance_sg[0].id]

  key_name = var.key_name != "" ? var.key_name : null

  user_data = base64encode(<<-EOF
              #!/bin/bash
              echo ECS_CLUSTER=${aws_ecs_cluster.main.name} >> /etc/ecs/ecs.config
              EOF
  )

  monitoring {
    enabled = true
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.cluster_name}-ecs-instance"
    }
  }
}

# Auto Scaling Group (only for EC2 launch type)
resource "aws_autoscaling_group" "ecs_asg" {
  count               = var.launch_type == "EC2" ? 1 : 0
  name                = "${var.cluster_name}-asg"
  vpc_zone_identifier = var.subnet_ids
  desired_capacity    = var.desired_capacity
  max_size            = var.max_capacity
  min_size            = var.min_capacity
  health_check_type   = "EC2"
  
  # Enable instance protection from scale in for managed termination protection
  protect_from_scale_in = true

  launch_template {
    id      = aws_launch_template.ecs_instance[0].id
    version = "$Latest"
  }

  tag {
    key                 = "AmazonECSManaged"
    value               = true
    propagate_at_launch = true
  }

  tag {
    key                 = "Name"
    value               = "${var.cluster_name}-ecs-instance"
    propagate_at_launch = true
  }
}

# ECS Capacity Provider (only for EC2 launch type)
resource "aws_ecs_capacity_provider" "main" {
  count = var.launch_type == "EC2" ? 1 : 0
  name  = "${var.cluster_name}-capacity-provider"

  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.ecs_asg[0].arn
    managed_termination_protection = "ENABLED"

    managed_scaling {
      status          = "ENABLED"
      target_capacity = 100
    }
  }
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${var.cluster_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = var.subnet_ids

  tags = {
    Name = "${var.cluster_name}-alb"
  }
}

resource "aws_lb_target_group" "main" {
  name        = "${var.cluster_name}-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = var.launch_type == "FARGATE" ? "ip" : "instance"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  deregistration_delay = 30

  tags = {
    Name = "${var.cluster_name}-tg"
  }
}    

resource "aws_lb_listener" "main" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

# IAM Role for ECS Task Execution
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.cluster_name}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# IAM Role for ECS Task
resource "aws_iam_role" "ecs_task_role" {
  name = "${var.cluster_name}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.cluster_name}"
  retention_in_days = 7

  tags = {
    Name = "${var.cluster_name}-logs"
  }
}

# ECS Task Definition
resource "aws_ecs_task_definition" "nginx" {
  family                   = "${var.cluster_name}-nginx"
  network_mode             = var.launch_type == "FARGATE" ? "awsvpc" : "bridge"
  requires_compatibilities = [var.launch_type]
  cpu                      = var.launch_type == "FARGATE" ? "256" : "256"
  memory                   = var.launch_type == "FARGATE" ? "512" : "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([{
    name      = "nginx"
    image     = "nginx:alpine"
    essential = true

    portMappings = [{
      containerPort = 80
      hostPort      = var.launch_type == "FARGATE" ? 80 : 80
      protocol      = "tcp"
    }]

    command = [
      "/bin/sh",
      "-c",
      <<-EOT
        cat > /usr/share/nginx/html/index.html <<'HTML'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>DevOps World</title>
    <style>
        body {
            margin: 0;
            padding: 0;
            font-family: 'Arial', sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
        }
        .container {
            text-align: center;
            color: white;
            padding: 40px;
            background: rgba(255, 255, 255, 0.1);
            border-radius: 20px;
            box-shadow: 0 8px 32px 0 rgba(31, 38, 135, 0.37);
            backdrop-filter: blur(4px);
            border: 1px solid rgba(255, 255, 255, 0.18);
        }
        h1 {
            font-size: 3em;
            margin: 0;
            text-shadow: 2px 2px 4px rgba(0,0,0,0.3);
        }
        p {
            font-size: 1.2em;
            margin-top: 20px;
        }
        .emoji {
            font-size: 4em;
            margin: 20px 0;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="emoji">🚀</div>
        <h1>Welcome to DevOps World</h1>
        <p>Running on AWS ECS with ${var.launch_type} Launch Type</p>
        <p>Powered by Terraform & Nginx</p>
    </div>
</body>
</html>
HTML
        echo "Custom HTML created successfully"
        exec nginx -g 'daemon off;'
      EOT
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
        "awslogs-region"        = data.aws_region.current.name
        "awslogs-stream-prefix" = "nginx"
      }
    }
  }])

  tags = {
    Name = "${var.cluster_name}-nginx-task"
  }
}

# Updated Launch Template with custom nginx page (only for EC2 launch type)
resource "aws_launch_template" "ecs_instance_updated" {
  count         = var.launch_type == "EC2" ? 1 : 0
  name_prefix   = "${var.cluster_name}-v2-"
  image_id      = data.aws_ssm_parameter.ecs_ami[0].value
  instance_type = var.instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.ecs_instance_profile[0].name
  }

  vpc_security_group_ids = [aws_security_group.ecs_instance_sg[0].id]

  key_name = var.key_name != "" ? var.key_name : null

  user_data = base64encode(<<-EOF
              #!/bin/bash
              echo ECS_CLUSTER=${aws_ecs_cluster.main.name} >> /etc/ecs/ecs.config
              EOF
  )

  monitoring {
    enabled = true
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.cluster_name}-ecs-instance"
    }
  }
}

# ECS Service
resource "aws_ecs_service" "nginx" {
  name            = "${var.cluster_name}-nginx-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.nginx.arn
  desired_count   = 2
  launch_type     = var.launch_type
  
  # Platform version for Fargate
  platform_version = var.launch_type == "FARGATE" ? "LATEST" : null
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  # Network configuration for Fargate
  dynamic "network_configuration" {
    for_each = var.launch_type == "FARGATE" ? [1] : []
    content {
      subnets          = var.subnet_ids
      security_groups  = [aws_security_group.fargate_task_sg[0].id]
      assign_public_ip = true
    }
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.main.arn
    container_name   = "nginx"
    container_port   = 80
  }

  depends_on = [
    aws_lb_listener.main
  ]

  tags = {
    Name = "${var.cluster_name}-nginx-service"
  }
}

# Auto Scaling for ECS Service
resource "aws_appautoscaling_target" "ecs_service" {
  max_capacity       = 4
  min_capacity       = 2
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.nginx.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "ecs_service_cpu" {
  name               = "${var.cluster_name}-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_service.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_service.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_service.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 75.0
  }
}

data "aws_region" "current" {}