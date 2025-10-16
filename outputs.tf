output "cluster_id" {
  description = "ECS Cluster ID"
  value       = module.ecs_cluster.cluster_id
}

output "cluster_name" {
  description = "ECS Cluster Name"
  value       = module.ecs_cluster.cluster_name
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.ecs_cluster.alb_dns_name
}

output "application_url" {
  description = "URL to access the application"
  value       = module.ecs_cluster.alb_url
}

output "service_name" {
  description = "ECS Service Name"
  value       = module.ecs_cluster.service_name
}