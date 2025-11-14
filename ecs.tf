# =============================================================================
# ECS CLUSTER
# =============================================================================

resource "aws_ecs_cluster" "this" {
  name = "${var.project_name}-cluster"

  tags = merge(local.tags, {
    Name = "${var.project_name}-cluster"
  })
}

# =============================================================================
# ECS TASK DEFINITION
# =============================================================================

resource "aws_ecs_task_definition" "this" {
  family                   = "${var.project_name}-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution.arn

  container_definitions = jsonencode([
    {
      name  = "mkdocs"
      image = "ghcr.io/platformfuzz/mkdocs-material-image-test:latest"

      portMappings = [
        {
          containerPort = 8000
          protocol      = "tcp"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-region"        = local.region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:8000/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }

      # Test image contains pre-built static documentation served via nginx
      # No command needed - image is ready to run immediately
      # Health check endpoint available at /health
    }
  ])

  depends_on = [aws_cloudwatch_log_group.ecs]

  tags = merge(local.tags, {
    Name = "${var.project_name}-task"
  })
}

# =============================================================================
# ECS SERVICE
# =============================================================================

resource "aws_ecs_service" "this" {
  name            = "${var.project_name}-service"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.this.arn
    container_name   = "mkdocs"
    container_port   = 8000
  }

  depends_on = [
    aws_lb_listener.https,
    aws_lb_target_group.this
  ]

  tags = merge(local.tags, {
    Name = "${var.project_name}-service"
  })
}
