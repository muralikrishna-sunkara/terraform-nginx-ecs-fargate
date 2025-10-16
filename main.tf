module "ecs_cluster" {
  source = "./modules/ecs-cluster"
  cluster_name      = var.cluster_name
  vpc_id            = var.vpc_id
  subnet_ids        = var.subnet_ids
  launch_type       = var.launch_type
  instance_type     = var.instance_type
  desired_capacity  = var.desired_capacity
  min_capacity      = var.min_capacity
  max_capacity      = var.max_capacity
  key_name          = var.key_name
}