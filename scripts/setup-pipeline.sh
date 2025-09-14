#!/bin/bash

# ============================================================================
# Terraform Azure CI/CD Pipeline Setup Script
# This script automates the setup of Azure resources and GitHub secrets
# ============================================================================

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================================
# Configuration Variables
# ============================================================================

# Get current user and repository information
CURRENT_DIR=$(pwd)
GITHUB_USERNAME=$(gh api user --jq .login 2>/dev/null || echo "")
GITHUB_REPO=$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null || echo "")
REPO_NAME=$(basename "$GITHUB_REPO" 2>/dev/null || echo "terraform-azure")

# Azure Configuration
LOCATION="eastus2"
RESOURCE_GROUP_NAME="rg-terraform-state"
STORAGE_ACCOUNT_PREFIX="tfstate"
CONTAINER_NAME="tfstate"
SERVICE_PRINCIPAL_NAME="sp-terraform-cicd-${REPO_NAME}"

# Generate unique storage account name
RANDOM_SUFFIX=$(openssl rand -hex 3)
STORAGE_ACCOUNT_NAME="${STORAGE_ACCOUNT_PREFIX}${RANDOM_SUFFIX}"

# ============================================================================
# Functions
# ============================================================================

print_header() {
    echo -e "\n${BLUE}============================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}============================================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

check_prerequisites() {
    print_header "Checking Prerequisites"

    local missing_tools=()

    # Check Azure CLI
    if ! command -v az &> /dev/null; then
        missing_tools+=("Azure CLI (az)")
    else
        print_success "Azure CLI installed"
    fi

    # Check GitHub CLI
    if ! command -v gh &> /dev/null; then
        missing_tools+=("GitHub CLI (gh)")
    else
        print_success "GitHub CLI installed"
    fi

    # Check jq
    if ! command -v jq &> /dev/null; then
        missing_tools+=("jq")
    else
        print_success "jq installed"
    fi

    # Check if tools are missing
    if [ ${#missing_tools[@]} -gt 0 ]; then
        print_error "Missing required tools:"
        for tool in "${missing_tools[@]}"; do
            echo "  - $tool"
        done
        echo ""
        print_info "Installation instructions:"
        echo "  Azure CLI: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
        echo "  GitHub CLI: https://cli.github.com/manual/installation"
        echo "  jq: https://stedolan.github.io/jq/download/"
        exit 1
    fi
}

check_authentication() {
    print_header "Checking Authentication Status"

    # Check Azure authentication
    if ! az account show &> /dev/null; then
        print_warning "Not logged into Azure. Logging in..."
        az login
    else
        AZURE_ACCOUNT=$(az account show --query name -o tsv)
        print_success "Logged into Azure account: $AZURE_ACCOUNT"
    fi

    # Check GitHub authentication
    if ! gh auth status &> /dev/null; then
        print_warning "Not logged into GitHub. Logging in..."
        gh auth login
    else
        print_success "Logged into GitHub as: $GITHUB_USERNAME"
    fi

    # Verify repository
    if [ -z "$GITHUB_REPO" ]; then
        print_error "Not in a GitHub repository. Please run this script from your repository root."
        exit 1
    else
        print_success "GitHub repository: $GITHUB_REPO"
    fi
}

get_azure_subscription() {
    print_header "Selecting Azure Subscription"

    # Get current subscription
    SUBSCRIPTION_ID=$(az account show --query id -o tsv)
    SUBSCRIPTION_NAME=$(az account show --query name -o tsv)

    print_info "Current subscription: $SUBSCRIPTION_NAME ($SUBSCRIPTION_ID)"
    read -p "Use this subscription? (y/n): " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        # List available subscriptions
        echo "Available subscriptions:"
        az account list --output table

        read -p "Enter Subscription ID: " SUBSCRIPTION_ID
        az account set --subscription "$SUBSCRIPTION_ID"
        SUBSCRIPTION_NAME=$(az account show --query name -o tsv)
    fi

    print_success "Using subscription: $SUBSCRIPTION_NAME"
}

create_service_principal() {
    print_header "Creating Azure Service Principal"

    # Check if service principal already exists
    EXISTING_SP=$(az ad sp list --display-name "$SERVICE_PRINCIPAL_NAME" --query "[0].appId" -o tsv 2>/dev/null || echo "")

    if [ -n "$EXISTING_SP" ]; then
        print_warning "Service Principal already exists: $SERVICE_PRINCIPAL_NAME"
        read -p "Delete and recreate? (y/n): " -n 1 -r
        echo

        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_info "Deleting existing Service Principal..."
            az ad sp delete --id "$EXISTING_SP"
            sleep 5  # Wait for deletion to propagate
        else
            print_info "Using existing Service Principal"
            # Get existing credentials - note: we can't retrieve the secret
            print_warning "Cannot retrieve existing secret. You'll need to reset it."
            read -p "Reset credentials? (y/n): " -n 1 -r
            echo

            if [[ $REPLY =~ ^[Yy]$ ]]; then
                SP_CREDENTIALS=$(az ad sp credential reset --id "$EXISTING_SP" --years 2)
            else
                print_error "Cannot proceed without credentials. Exiting."
                exit 1
            fi
        fi
    fi

    if [ -z "$EXISTING_SP" ] || [[ $REPLY =~ ^[Yy]$ ]]; then
        # Create new service principal
        print_info "Creating Service Principal: $SERVICE_PRINCIPAL_NAME"
        SP_CREDENTIALS=$(az ad sp create-for-rbac \
            --name "$SERVICE_PRINCIPAL_NAME" \
            --role "Contributor" \
            --scopes "/subscriptions/$SUBSCRIPTION_ID" \
            --years 2 \
            --sdk-auth)

        print_success "Service Principal created successfully"
    fi

    # Extract credentials
    ARM_CLIENT_ID=$(echo "$SP_CREDENTIALS" | jq -r .clientId)
    ARM_CLIENT_SECRET=$(echo "$SP_CREDENTIALS" | jq -r .clientSecret)
    ARM_TENANT_ID=$(echo "$SP_CREDENTIALS" | jq -r .tenantId)
}

create_storage_account() {
    print_header "Creating Terraform Backend Storage"

    # Create resource group
    if az group show --name "$RESOURCE_GROUP_NAME" &> /dev/null; then
        print_success "Resource group exists: $RESOURCE_GROUP_NAME"
    else
        print_info "Creating resource group: $RESOURCE_GROUP_NAME"
        az group create \
            --name "$RESOURCE_GROUP_NAME" \
            --location "$LOCATION" \
            --output none
        print_success "Resource group created"
    fi

    # Check if any storage account exists in the resource group
    EXISTING_STORAGE=$(az storage account list \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --query "[0].name" -o tsv 2>/dev/null || echo "")

    if [ -n "$EXISTING_STORAGE" ]; then
        print_warning "Storage account exists: $EXISTING_STORAGE"
        read -p "Use existing storage account? (y/n): " -n 1 -r
        echo

        if [[ $REPLY =~ ^[Yy]$ ]]; then
            STORAGE_ACCOUNT_NAME="$EXISTING_STORAGE"
        else
            # Create new storage account
            print_info "Creating storage account: $STORAGE_ACCOUNT_NAME"
            az storage account create \
                --name "$STORAGE_ACCOUNT_NAME" \
                --resource-group "$RESOURCE_GROUP_NAME" \
                --location "$LOCATION" \
                --sku Standard_LRS \
                --encryption-services blob \
                --min-tls-version TLS1_2 \
                --allow-blob-public-access false \
                --output none
            print_success "Storage account created: $STORAGE_ACCOUNT_NAME"
        fi
    else
        # Create new storage account
        print_info "Creating storage account: $STORAGE_ACCOUNT_NAME"
        az storage account create \
            --name "$STORAGE_ACCOUNT_NAME" \
            --resource-group "$RESOURCE_GROUP_NAME" \
            --location "$LOCATION" \
            --sku Standard_LRS \
            --encryption-services blob \
            --min-tls-version TLS1_2 \
            --allow-blob-public-access false \
            --output none
        print_success "Storage account created: $STORAGE_ACCOUNT_NAME"
    fi

    # Create container
    if az storage container show \
        --name "$CONTAINER_NAME" \
        --account-name "$STORAGE_ACCOUNT_NAME" \
        --auth-mode login &> /dev/null; then
        print_success "Container exists: $CONTAINER_NAME"
    else
        print_info "Creating container: $CONTAINER_NAME"
        az storage container create \
            --name "$CONTAINER_NAME" \
            --account-name "$STORAGE_ACCOUNT_NAME" \
            --auth-mode login \
            --output none
        print_success "Container created"
    fi
}

get_user_inputs() {
    print_header "Collecting User Information"

    # Get admin email
    read -p "Enter admin email for notifications: " ADMIN_EMAIL
    while ! [[ "$ADMIN_EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; do
        print_error "Invalid email format"
        read -p "Enter admin email for notifications: " ADMIN_EMAIL
    done
    print_success "Admin email: $ADMIN_EMAIL"

    # Get current IP address
    print_info "Detecting your current IP address..."
    CURRENT_IP=$(curl -s https://api.ipify.org 2>/dev/null || echo "")
    if [ -n "$CURRENT_IP" ]; then
        print_success "Detected IP: $CURRENT_IP"
        read -p "Use this IP for allowed access? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            read -p "Enter IP address or CIDR (e.g., 192.168.1.0/24): " CURRENT_IP
        fi
    else
        read -p "Enter your IP address or CIDR for allowed access: " CURRENT_IP
    fi

    # Optional: Infracost API key
    echo ""
    read -p "Do you have an Infracost API key? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -sp "Enter Infracost API key: " INFRACOST_API_KEY
        echo
    else
        print_info "Skipping Infracost setup (cost estimation will be disabled)"
        INFRACOST_API_KEY=""
    fi

    # Optional: Slack webhook
    echo ""
    read -p "Do you have a Slack webhook URL? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "Enter Slack webhook URL: " SLACK_WEBHOOK_URL
    else
        print_info "Skipping Slack setup (notifications will be disabled)"
        SLACK_WEBHOOK_URL=""
    fi
}

create_github_secrets() {
    print_header "Creating GitHub Secrets"

    # Function to create or update a secret
    set_secret() {
        local secret_name=$1
        local secret_value=$2

        if [ -n "$secret_value" ]; then
            echo "$secret_value" | gh secret set "$secret_name" 2>/dev/null
            print_success "Set secret: $secret_name"
        else
            print_warning "Skipped empty secret: $secret_name"
        fi
    }

    # Azure secrets
    set_secret "ARM_CLIENT_ID" "$ARM_CLIENT_ID"
    set_secret "ARM_CLIENT_SECRET" "$ARM_CLIENT_SECRET"
    set_secret "ARM_SUBSCRIPTION_ID" "$SUBSCRIPTION_ID"
    set_secret "ARM_TENANT_ID" "$ARM_TENANT_ID"

    # Backend secrets
    set_secret "BACKEND_RESOURCE_GROUP" "$RESOURCE_GROUP_NAME"
    set_secret "BACKEND_STORAGE_ACCOUNT" "$STORAGE_ACCOUNT_NAME"
    set_secret "BACKEND_CONTAINER" "$CONTAINER_NAME"

    # Application secrets
    set_secret "ADMIN_EMAIL" "$ADMIN_EMAIL"

    # Optional secrets
    if [ -n "$INFRACOST_API_KEY" ]; then
        set_secret "INFRACOST_API_KEY" "$INFRACOST_API_KEY"
    fi

    if [ -n "$SLACK_WEBHOOK_URL" ]; then
        set_secret "SLACK_WEBHOOK_URL" "$SLACK_WEBHOOK_URL"
    fi
}

update_configuration_files() {
    print_header "Updating Configuration Files"

    # Update backend configuration files
    for env in dev staging prod; do
        BACKEND_FILE="environments/$env/backend.tf"
        if [ -f "$BACKEND_FILE" ]; then
            print_info "Updating $BACKEND_FILE"

            # Use sed for cross-platform compatibility
            if [[ "$OSTYPE" == "darwin"* ]]; then
                # macOS
                sed -i '' "s/stterraformstate12345/$STORAGE_ACCOUNT_NAME/g" "$BACKEND_FILE"
            else
                # Linux/Git Bash
                sed -i "s/stterraformstate12345/$STORAGE_ACCOUNT_NAME/g" "$BACKEND_FILE"
            fi
            print_success "Updated backend configuration for $env"
        fi
    done

    # Update terraform.tfvars files
    for env in dev staging prod; do
        TFVARS_FILE="environments/$env/terraform.tfvars"
        if [ -f "$TFVARS_FILE" ]; then
            print_info "Updating $TFVARS_FILE"

            # Update IP address
            if [[ "$OSTYPE" == "darwin"* ]]; then
                sed -i '' "s|YOUR_OFFICE_IP/32|$CURRENT_IP/32|g" "$TFVARS_FILE"
                sed -i '' "s|admin@example.com|$ADMIN_EMAIL|g" "$TFVARS_FILE"
            else
                sed -i "s|YOUR_OFFICE_IP/32|$CURRENT_IP/32|g" "$TFVARS_FILE"
                sed -i "s|admin@example.com|$ADMIN_EMAIL|g" "$TFVARS_FILE"
            fi
            print_success "Updated terraform.tfvars for $env"
        fi
    done

    # Update README.md
    if [ -f "README.md" ]; then
        print_info "Updating README.md"
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s|YOUR_GITHUB_USERNAME|$GITHUB_USERNAME|g" "README.md"
        else
            sed -i "s|YOUR_GITHUB_USERNAME|$GITHUB_USERNAME|g" "README.md"
        fi
        print_success "Updated README.md with GitHub username"
    fi

    # Update CODEOWNERS
    if [ -f ".github/CODEOWNERS" ]; then
        print_info "Updating CODEOWNERS"
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s|YOUR_GITHUB_USERNAME|$GITHUB_USERNAME|g" ".github/CODEOWNERS"
        else
            sed -i "s|YOUR_GITHUB_USERNAME|$GITHUB_USERNAME|g" ".github/CODEOWNERS"
        fi
        print_success "Updated CODEOWNERS"
    fi

    # Update dependabot.yml
    if [ -f ".github/dependabot.yml" ]; then
        print_info "Updating dependabot.yml"
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s|YOUR_GITHUB_USERNAME|$GITHUB_USERNAME|g" ".github/dependabot.yml"
        else
            sed -i "s|YOUR_GITHUB_USERNAME|$GITHUB_USERNAME|g" ".github/dependabot.yml"
        fi
        print_success "Updated dependabot.yml"
    fi
}

create_github_environments() {
    print_header "Creating GitHub Environments"

    # Check if we have the required permissions
    if ! gh api repos/$GITHUB_REPO/environments --silent 2>/dev/null; then
        print_warning "Cannot create environments (requires GitHub Pro/Enterprise or public repo)"
        print_info "Please manually create environments: dev, staging, prod"
        return
    fi

    # Create environments
    for env in dev staging prod; do
        print_info "Creating environment: $env"

        # Create or update environment
        gh api --method PUT repos/$GITHUB_REPO/environments/$env \
            --field wait_timer=0 \
            --field deployment_branch_policy=null \
            --silent 2>/dev/null || true

        # Add protection rules for prod
        if [ "$env" == "prod" ]; then
            print_info "Adding protection rules for production"
            gh api --method PUT repos/$GITHUB_REPO/environments/prod \
                --field wait_timer=10 \
                --field reviewers[][type]=User \
                --field reviewers[][id]=$(gh api user --jq .id) \
                --field deployment_branch_policy[protected_branches]=true \
                --field deployment_branch_policy[custom_branch_policies]=false \
                --silent 2>/dev/null || true
        fi

        print_success "Environment configured: $env"
    done
}

generate_summary() {
    print_header "Setup Complete!"

    # Create summary file
    SUMMARY_FILE="PIPELINE_SETUP_SUMMARY.md"

    cat > "$SUMMARY_FILE" << EOF
# CI/CD Pipeline Setup Summary

Generated on: $(date)

## Azure Resources Created

- **Subscription ID**: $SUBSCRIPTION_ID
- **Service Principal**: $SERVICE_PRINCIPAL_NAME
- **Client ID**: $ARM_CLIENT_ID
- **Tenant ID**: $ARM_TENANT_ID
- **Resource Group**: $RESOURCE_GROUP_NAME
- **Storage Account**: $STORAGE_ACCOUNT_NAME
- **Container**: $CONTAINER_NAME

## GitHub Configuration

- **Repository**: $GITHUB_REPO
- **User**: $GITHUB_USERNAME
- **Admin Email**: $ADMIN_EMAIL
- **Allowed IP**: $CURRENT_IP/32

## GitHub Secrets Created

✅ ARM_CLIENT_ID
✅ ARM_CLIENT_SECRET
✅ ARM_SUBSCRIPTION_ID
✅ ARM_TENANT_ID
✅ BACKEND_RESOURCE_GROUP
✅ BACKEND_STORAGE_ACCOUNT
✅ BACKEND_CONTAINER
✅ ADMIN_EMAIL
$([ -n "$INFRACOST_API_KEY" ] && echo "✅ INFRACOST_API_KEY" || echo "⭕ INFRACOST_API_KEY (not configured)")
$([ -n "$SLACK_WEBHOOK_URL" ] && echo "✅ SLACK_WEBHOOK_URL" || echo "⭕ SLACK_WEBHOOK_URL (not configured)")

## Files Updated

- environments/*/backend.tf (storage account name)
- environments/*/terraform.tfvars (IP address and email)
- README.md (GitHub username)
- .github/CODEOWNERS (GitHub username)
- .github/dependabot.yml (GitHub username)

## Next Steps

1. Review and commit the changes:
   \`\`\`bash
   git add -A
   git commit -m "Configure CI/CD pipeline settings"
   git push
   \`\`\`

2. The pipeline will automatically run on push to main/develop branches

3. To manually trigger a deployment:
   - Go to Actions tab in GitHub
   - Select "Terraform CI/CD Pipeline"
   - Click "Run workflow"

4. Monitor the pipeline:
   - Check the Actions tab for pipeline status
   - Review security findings in the Security tab
   - Check deployment history in Environments

## Important Notes

- Service Principal credentials expire in 2 years
- Rotate secrets regularly for security
- Review security scan findings before production deployment
- Set up branch protection rules for main and develop branches

## Troubleshooting

If the pipeline fails:
1. Check the Actions logs for detailed error messages
2. Verify all secrets are correctly set
3. Ensure the service principal has the required permissions
4. Check that the storage account is accessible

For more information, see SETUP_CICD.md
EOF

    print_success "Summary saved to: $SUMMARY_FILE"

    # Display summary
    echo ""
    cat "$SUMMARY_FILE"
}

# ============================================================================
# Main Execution
# ============================================================================

main() {
    print_header "Terraform Azure CI/CD Pipeline Setup"

    # Check prerequisites
    check_prerequisites

    # Check authentication
    check_authentication

    # Get Azure subscription
    get_azure_subscription

    # Create service principal
    create_service_principal

    # Create storage account
    create_storage_account

    # Get user inputs
    get_user_inputs

    # Create GitHub secrets
    create_github_secrets

    # Update configuration files
    update_configuration_files

    # Create GitHub environments
    create_github_environments

    # Generate summary
    generate_summary

    print_header "🎉 Setup Complete!"
    print_info "Review PIPELINE_SETUP_SUMMARY.md for details"
    print_info "Commit and push changes to activate the pipeline"
}

# Run main function
main "$@"