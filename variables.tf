variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "cognito-saml-azure-alb"
}

variable "azure_tenant_id" {
  description = "Azure AD tenant ID"
  type        = string
}

variable "azure_client_id" {
  description = "Azure AD application client ID"
  type        = string
}

variable "domain_name" {
  description = "Domain name"
  type        = string
}

variable "cognito_domain_prefix" {
  description = "Custom prefix for Cognito domain. If empty, a random suffix will be used."
  type        = string
  default     = ""
}
