output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = aws_lb.main.zone_id
}

output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = aws_ecr_repository.app.repository_url
}

output "ecr_repository_name" {
  description = "Name of the ECR repository"
  value       = aws_ecr_repository.app.name
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table"
  value       = aws_dynamodb_table.picus_data.name
}

output "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table"
  value       = aws_dynamodb_table.picus_data.arn
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.app.name
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = aws_subnet.private[*].id
}

output "ecs_task_execution_role_arn" {
  description = "ARN of ECS task execution role"
  value       = aws_iam_role.ecs_task_execution.arn
}

output "ecs_task_role_arn" {
  description = "ARN of ECS task role"
  value       = aws_iam_role.ecs_task.arn
}

output "lambda_function_name" {
  description = "Name of the Lambda function (managed by Serverless Framework)"
  value       = "picus-${var.environment}-delete"
}

output "lambda_target_group_arn" {
  description = "ARN of the Lambda target group"
  value       = aws_lb_target_group.lambda.arn
}

output "api_base_url" {
  description = "Base URL for API endpoints"
  value       = "https://${aws_lb.main.dns_name}"
}

output "app_domain_name" {
  description = "Custom domain name for the application (requires Route53 hosted zone)"
  value       = try(aws_route53_record.app.fqdn, "Not configured - use ALB DNS instead")
}

output "app_url" {
  description = "Application URL (custom domain if Route53 configured, otherwise ALB DNS)"
  value       = try("https://${aws_route53_record.app.fqdn}", "https://${aws_lb.main.dns_name}")
}

output "acm_certificate_arn" {
  description = "ARN of the ACM certificate"
  value       = aws_acm_certificate.main.arn
}

output "acm_certificate_status" {
  description = "Status of the ACM certificate"
  value       = aws_acm_certificate.main.status
}

