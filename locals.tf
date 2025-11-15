locals {
  region = data.aws_region.current.region

  tags = {
    Project     = var.project_name
    Environment = "dev"
    ManagedBy   = "terraform"
  }

  web_subdomain = "web.${var.domain_name}"

  azure_metadata_url = "https://login.microsoftonline.com/${var.azure_tenant_id}/federationmetadata/2007-06/federationmetadata.xml?appid=${var.azure_client_id}"
}
