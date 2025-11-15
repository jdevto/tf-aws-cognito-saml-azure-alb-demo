# =============================================================================
# APPLICATION LOAD BALANCER
# =============================================================================

resource "aws_lb" "this" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  enable_deletion_protection = false

  tags = merge(local.tags, {
    Name = "${var.project_name}-alb"
  })
}

# =============================================================================
# TARGET GROUP
# =============================================================================

resource "aws_lb_target_group" "this" {
  name_prefix = "tg-"
  port        = 8000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.this.id
  target_type = "ip" # Required for Fargate with awsvpc network mode

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/health"
    protocol            = "HTTP"
    matcher             = "200"
  }

  tags = merge(local.tags, {
    Name = "${var.project_name}-tg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# =============================================================================
# ALB LISTENERS
# =============================================================================

# HTTP listener - redirect to HTTPS
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
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
}

# HTTPS listener with Cognito authentication
# Note: Certificate must be validated before this listener can be created
# Comment out this resource initially, validate the certificate, then uncomment
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.this.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate.this.arn

  # Default action - return 404 if no rules match
  # Actual routing is handled by listener rules below
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Not Found"
      status_code  = "404"
    }
  }

  # Wait for certificate to be issued (validation must be done manually)
  depends_on = [aws_acm_certificate.this]

  lifecycle {
    create_before_destroy = true
  }
}

# Catch-all listener rule with Cognito authentication for all paths
# Priority 100 ensures this is evaluated after health and oauth rules
resource "aws_lb_listener_rule" "default_auth" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 100

  action {
    type = "authenticate-cognito"

    authenticate_cognito {
      user_pool_arn              = aws_cognito_user_pool.this.arn
      user_pool_client_id        = aws_cognito_user_pool_client.this.id
      user_pool_domain           = aws_cognito_user_pool_domain.this.domain
      on_unauthenticated_request = "authenticate"
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }

  condition {
    path_pattern {
      values = ["/*"]
    }
  }
}

# Listener rule for health check endpoint - no authentication required
# Priority 1 ensures this rule is evaluated before the default action
resource "aws_lb_listener_rule" "health" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 1

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }

  condition {
    path_pattern {
      values = ["/health"]
    }
  }
}

# Listener rule for OAuth callback - must allow without additional auth
# Priority 2 ensures this is evaluated before default action
resource "aws_lb_listener_rule" "oauth_callback" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 2

  action {
    type = "authenticate-cognito"

    authenticate_cognito {
      user_pool_arn              = aws_cognito_user_pool.this.arn
      user_pool_client_id        = aws_cognito_user_pool_client.this.id
      user_pool_domain           = aws_cognito_user_pool_domain.this.domain
      on_unauthenticated_request = "allow"
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }

  condition {
    path_pattern {
      values = ["/oauth2/idpresponse"]
    }
  }
}
