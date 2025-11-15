# =============================================================================
# CLOUDWATCH LOG GROUP
# =============================================================================

resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.project_name}"
  retention_in_days = 1

  lifecycle {
    prevent_destroy = false
  }

  tags = merge(local.tags, {
    Name = "${var.project_name}-ecs-logs"
  })
}
