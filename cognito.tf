# =============================================================================
# COGNITO RESOURCES
# =============================================================================

resource "aws_cognito_user_pool" "this" {
  name = "${var.project_name}-user-pool"

  # User pool settings
  auto_verified_attributes = ["email"]

  username_attributes = ["email"]

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }

  schema {
    name                = "email"
    attribute_data_type = "String"
    required            = true
    mutable             = true
  }

  tags = merge(local.tags, {
    Name = "${var.project_name}-user-pool"
  })
}

resource "aws_cognito_user_pool_client" "this" {
  name         = "${var.project_name}-app-client"
  user_pool_id = aws_cognito_user_pool.this.id

  # ALB authenticate-cognito REQUIRES a client secret
  generate_secret = true

  # OAuth settings
  # ALB authenticate-cognito uses authorization code flow (code alone is sufficient)
  # Implicit flow included for compatibility with common AWS examples
  allowed_oauth_flows                  = ["code", "implicit"]
  allowed_oauth_scopes                 = ["email", "openid", "profile"]
  allowed_oauth_flows_user_pool_client = true

  # Callback URLs - ALB Cognito authentication requires exact match
  callback_urls = [
    "https://${aws_lb.this.dns_name}/oauth2/idpresponse",
    "https://${local.web_subdomain}/oauth2/idpresponse"
  ]
  logout_urls = [
    "https://${aws_lb.this.dns_name}/",
    "https://${local.web_subdomain}/"
  ]

  supported_identity_providers = ["AzureAD"]

  # Ensure ALB is created first so we can reference its DNS name
  depends_on = [aws_lb.this]
}

resource "random_id" "domain_suffix" {
  byte_length = 4
}

resource "aws_cognito_user_pool_domain" "this" {
  domain       = var.cognito_domain_prefix != "" ? var.cognito_domain_prefix : "${replace(var.project_name, "cognito", "auth")}-${random_id.domain_suffix.hex}"
  user_pool_id = aws_cognito_user_pool.this.id
}

# =============================================================================
# SAML IDENTITY PROVIDER
# =============================================================================

resource "aws_cognito_identity_provider" "azure_ad" {
  user_pool_id  = aws_cognito_user_pool.this.id
  provider_name = "AzureAD"
  provider_type = "SAML"

  provider_details = {
    # MetadataURL automatically manages ActiveEncryptionCertificate
    # Do not set ActiveEncryptionCertificate explicitly to avoid drift
    MetadataURL           = local.azure_metadata_url
    SLORedirectBindingURI = "https://login.microsoftonline.com/${var.azure_tenant_id}/saml2"
    SSORedirectBindingURI = "https://login.microsoftonline.com/${var.azure_tenant_id}/saml2"
  }

  lifecycle {
    # ActiveEncryptionCertificate is automatically managed by MetadataURL
    # Ignore changes to prevent continuous drift when Cognito updates it from metadata
    ignore_changes = [provider_details["ActiveEncryptionCertificate"]]
  }

  attribute_mapping = {
    email       = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress"
    given_name  = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/givenname"
    family_name = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/surname"
    username    = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/upn"
  }

  # IDP identifiers - helps with SAML validation
  idp_identifiers = ["AzureAD"]
}
