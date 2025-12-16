# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  enable_deletion_protection = false
  enable_http2               = true

  tags = {
    Name = "${var.project_name}-alb"
  }
}

# Target Group for ECS Service
resource "aws_lb_target_group" "ecs" {
  name_prefix          = "picus-"
  port                 = var.container_port
  protocol             = "HTTP"
  vpc_id               = aws_vpc.main.id
  target_type          = "ip"
  deregistration_delay = 30

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = var.health_check_path
    protocol            = "HTTP"
    matcher             = "200"
  }

  tags = {
    Name = "${var.project_name}-ecs-tg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Target Group for Lambda Function
resource "aws_lb_target_group" "lambda" {
  name_prefix = "lamb-"
  target_type = "lambda"

  tags = {
    Name = "${var.project_name}-lambda-tg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ALB Listener (HTTP on port 80) - Redirect to HTTPS
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  tags = {
    Name = "${var.project_name}-http-listener"
  }
}

# ALB Listener (HTTPS on port 443)
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate_validation.main.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs.arn
  }

  tags = {
    Name = "${var.project_name}-https-listener"
  }
}

# Listener Rule for GET /picus/list -> ECS
resource "aws_lb_listener_rule" "picus_list" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs.arn
  }

  condition {
    path_pattern {
      values = ["/picus/list"]
    }
  }

  condition {
    http_request_method {
      values = ["GET"]
    }
  }

  tags = {
    Name = "${var.project_name}-list-rule"
  }
}

# Listener Rule for POST /picus/put -> ECS
resource "aws_lb_listener_rule" "picus_put" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 20

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs.arn
  }

  condition {
    path_pattern {
      values = ["/picus/put"]
    }
  }

  condition {
    http_request_method {
      values = ["POST"]
    }
  }

  tags = {
    Name = "${var.project_name}-put-rule"
  }
}

# Listener Rule for GET /picus/get/* -> ECS
resource "aws_lb_listener_rule" "picus_get" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 30

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs.arn
  }

  condition {
    path_pattern {
      values = ["/picus/get/*"]
    }
  }

  condition {
    http_request_method {
      values = ["GET"]
    }
  }

  tags = {
    Name = "${var.project_name}-get-rule"
  }
}

# Listener Rule for DELETE /picus/* -> Lambda
resource "aws_lb_listener_rule" "picus_delete" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 40

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lambda.arn
  }

  condition {
    path_pattern {
      values = ["/picus/*"]
    }
  }

  condition {
    http_request_method {
      values = ["DELETE"]
    }
  }

  tags = {
    Name = "${var.project_name}-delete-rule"
  }
}

# Listener Rule for /health -> ECS
resource "aws_lb_listener_rule" "health" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 5

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs.arn
  }

  condition {
    path_pattern {
      values = ["/health"]
    }
  }

  tags = {
    Name = "${var.project_name}-health-rule"
  }
}
