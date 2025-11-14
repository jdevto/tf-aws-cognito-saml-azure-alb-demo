# =============================================================================
# APPLICATION ACCESS
# =============================================================================

output "application_url" {
  description = "Full URL to access the application (with Cognito Azure AD authentication)"
  value       = "https://${local.web_subdomain}"
}

output "alb_dns_name" {
  description = "ALB DNS name (for debugging)"
  value       = aws_lb.this.dns_name
}

# =============================================================================
# AZURE AD CONFIGURATION
# =============================================================================

output "entity_id" {
  description = "SAML Entity ID (Identifier) to configure in Azure AD Enterprise Application"
  value       = "urn:amazon:cognito:sp:${aws_cognito_user_pool.this.id}"
}

output "redirect_uri" {
  description = "SAML Reply URL (Assertion Consumer Service URL) to configure in Azure AD Enterprise Application"
  value       = "https://${aws_cognito_user_pool_domain.this.domain}.auth.${local.region}.amazoncognito.com/saml2/idpresponse"
}

# =============================================================================
# COGNITO CONFIGURATION
# =============================================================================

output "cognito_user_pool_id" {
  description = "Cognito User Pool ID"
  value       = aws_cognito_user_pool.this.id
}

output "cognito_domain" {
  description = "Cognito User Pool Domain"
  value       = aws_cognito_user_pool_domain.this.domain
}

output "cognito_client_id" {
  description = "Cognito User Pool Client ID"
  value       = aws_cognito_user_pool_client.this.id
}
