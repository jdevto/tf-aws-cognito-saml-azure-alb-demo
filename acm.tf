# =============================================================================
# ACM CERTIFICATE
# =============================================================================

resource "aws_acm_certificate" "this" {
  domain_name       = local.web_subdomain
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(local.tags, {
    Name = "${var.project_name}-cert"
  })
}

# Certificate validation
resource "aws_acm_certificate_validation" "this" {
  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}
