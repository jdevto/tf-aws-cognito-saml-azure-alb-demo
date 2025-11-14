# AWS Cognito SAML Azure AD ALB Demo

Terraform configuration for demonstrating AWS Cognito SAML authentication with Azure AD, using Application Load Balancer (ALB) to protect an ECS-hosted MkDocs Material documentation site.

## Architecture

- **ALB**: Performs Cognito authentication before forwarding requests (HTTPS with ACM certificate)
- **Cognito**: User pool with Azure AD SAML identity provider
- **ECS Fargate**: Hosts MkDocs Material documentation site using the test image
- **Route53**: DNS records for domain and certificate validation
- **VPC**: Multi-AZ setup with public and private subnets, single NAT Gateway

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.0
- A Route53 hosted zone for your domain
- Azure AD tenant with an Enterprise Application configured

## Deployment

### 1. Configure Variables

**Important**: You need to create an Azure AD Enterprise Application first to get the required values. See the "Azure AD Setup" section below for details on the chicken-and-egg problem.

Create a `terraform.tfvars` file with your values:

```hcl
# These values come from your Azure AD Enterprise Application
# You must create the Enterprise Application in Azure AD first
azure_tenant_id = "your-azure-tenant-id"  # From Azure AD → Overview → Tenant ID
azure_client_id = "your-azure-client-id"   # From Azure AD → Enterprise Application → Overview → Application (client) ID
domain_name     = "your-domain.com"
```

**Note**: The `azure_tenant_id` and `azure_client_id` must exist in Azure AD before deployment. However, you'll need to update the Azure AD Enterprise Application configuration with values from Terraform outputs after deployment. See "Azure AD Setup" section below.

### 2. Deploy Infrastructure

```bash
terraform init
terraform plan
terraform apply
```

### 3. Get Cognito SAML Endpoints

After deployment, retrieve the SAML configuration values:

```bash
terraform output entity_id
terraform output redirect_uri
```

### 4. Azure AD Setup (Chicken-and-Egg Problem)

**The Challenge**: You need Azure AD values (`azure_tenant_id` and `azure_client_id`) to deploy Terraform, but you need Terraform outputs (`entity_id` and `redirect_uri`) to configure Azure AD properly.

**Solution - Two-Step Process**:

#### Step 4a: Create Azure AD Enterprise Application (Before Terraform)

1. Go to Azure Portal → Azure Active Directory → Enterprise Applications
2. Click "New application" → "Create your own application"
3. Name it (e.g., "AWS Cognito SAML Demo") and select "Integrate any other application you don't find in the gallery"
4. After creation, note:
   - **Tenant ID**: Azure AD → Overview → Tenant ID (use this for `azure_tenant_id`)
   - **Application (Client) ID**: Enterprise Application → Overview → Application (client) ID (use this for `azure_client_id`)
5. You can leave SAML configuration incomplete for now - we'll complete it after Terraform deployment

#### Step 4b: Configure Azure AD SAML (After Terraform)

After running `terraform apply` and getting the outputs:

1. Go back to Azure Portal → Azure Active Directory → Enterprise Applications → Your Application
2. Navigate to "Single sign-on" → "Basic SAML Configuration"
3. **CRITICAL**: Remove ALL other Entity IDs and Reply URLs
4. Configure ONLY these values:
   - **Identifier (Entity ID)**: Use `entity_id` from `terraform output entity_id` (set as DEFAULT)
   - **Reply URL (Assertion Consumer Service URL)**: Use `redirect_uri` from `terraform output redirect_uri` (set as DEFAULT)
5. **DO NOT** add the ALB URL as a Reply URL - this is for OAuth callbacks, not SAML
6. In "SAML Signing Certificate" section:
   - Ensure the certificate status is "Active"
   - If there's a "New certificate", make sure the "Active" certificate is being used
7. Save configuration and wait 2-3 minutes for propagation

### 5. Troubleshooting

**If you get "SAML Assertion signature is invalid" error:**

- Run `terraform apply` again to force Cognito to refresh metadata
- Or manually refresh in AWS Console: Cognito → User Pool → Sign-in experience → Federated identity provider → Edit AzureAD → Save (this forces metadata refresh)
- Verify Azure AD certificate matches the one in metadata URL

**Health check endpoint:**

- `/health` - Returns JSON health status (may download in browsers due to Content-Type header)
- Access the application at the URL from `terraform output application_url`

## Architecture Details

### Network

- VPC with public and private subnets across multiple availability zones
- Single NAT Gateway for cost optimization
- ALB in public subnets, ECS tasks in private subnets

### Application

- ECS Fargate service running MkDocs Material test image
- Container serves on port 8000
- Health check endpoint at `/health`
- CloudWatch Logs for container logs

### Security

- ALB with HTTPS listener (TLS 1.3)
- Cognito authentication required for all paths except:
  - `/health` - No authentication (for health checks)
  - `/oauth2/idpresponse` - OAuth callback endpoint
- Security groups restrict traffic appropriately

## Variables

| Variable | Description | Required | Default |
|----------|-------------|----------|---------|
| `azure_tenant_id` | Azure AD tenant ID | Yes | - |
| `azure_client_id` | Azure AD application client ID | Yes | - |
| `domain_name` | Domain name for the application | Yes | - |
| `project_name` | Name of the project | No | `cognito-saml-azure-alb` |
| `cognito_domain_prefix` | Custom Cognito domain prefix | No | Auto-generated |

## Outputs

- `application_url`: Full HTTPS URL to access the application
- `alb_dns_name`: ALB DNS name (for debugging)
- `entity_id`: SAML Entity ID for Azure AD Enterprise Application configuration
- `redirect_uri`: SAML Reply URL (Assertion Consumer Service URL) for Azure AD Enterprise Application configuration
- `cognito_user_pool_id`: Cognito User Pool ID
- `cognito_domain`: Cognito User Pool Domain
- `cognito_client_id`: Cognito User Pool Client ID

## Security Notes

- **terraform.tfvars** is gitignored and should never be committed
- State files (`.tfstate*`) are gitignored
- Cognito client secret is auto-generated and stored securely
- All sensitive values should be provided via `terraform.tfvars` or environment variables

## Cost Optimization

- Single NAT Gateway (instead of per-AZ) for cost savings
- CloudWatch Logs retention set to 1 day
- Fargate tasks use minimal resources (256 CPU, 512 MB memory)

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

**Note**: This will delete all resources including the VPC, ALB, ECS cluster, and Cognito user pool.
