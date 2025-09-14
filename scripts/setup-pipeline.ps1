# ============================================================================
# Terraform Azure CI/CD Pipeline Setup Script (PowerShell)
# This script automates the setup of Azure resources and GitHub secrets
# ============================================================================

$ErrorActionPreference = "Stop"

# Color functions
function Write-Success { Write-Host "✓ $args" -ForegroundColor Green }
function Write-Error { Write-Host "✗ $args" -ForegroundColor Red }
function Write-Warning { Write-Host "⚠ $args" -ForegroundColor Yellow }
function Write-Info { Write-Host "ℹ $args" -ForegroundColor Cyan }
function Write-Header {
    Write-Host "`n============================================================" -ForegroundColor Blue
    Write-Host $args -ForegroundColor Blue
    Write-Host "============================================================`n" -ForegroundColor Blue
}

# ============================================================================
# Configuration Variables
# ============================================================================

$Location = "eastus2"
$ResourceGroupName = "rg-terraform-state"
$StorageAccountPrefix = "tfstate"
$ContainerName = "tfstate"
$CurrentDir = Get-Location

# Generate unique storage account name
$RandomSuffix = -join ((0..9) + ('a'..'z') | Get-Random -Count 6)
$StorageAccountName = "${StorageAccountPrefix}${RandomSuffix}"

# ============================================================================
# Functions
# ============================================================================

function Test-Prerequisites {
    Write-Header "Checking Prerequisites"

    $missingTools = @()

    # Check Azure CLI
    if (!(Get-Command az -ErrorAction SilentlyContinue)) {
        $missingTools += "Azure CLI (az)"
    } else {
        Write-Success "Azure CLI installed"
    }

    # Check GitHub CLI
    if (!(Get-Command gh -ErrorAction SilentlyContinue)) {
        $missingTools += "GitHub CLI (gh)"
    } else {
        Write-Success "GitHub CLI installed"
    }

    if ($missingTools.Count -gt 0) {
        Write-Error "Missing required tools:"
        $missingTools | ForEach-Object { Write-Host "  - $_" }
        Write-Info "Installation instructions:"
        Write-Host "  Azure CLI: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-windows"
        Write-Host "  GitHub CLI: https://cli.github.com/manual/installation"
        exit 1
    }
}

function Test-Authentication {
    Write-Header "Checking Authentication Status"

    # Check Azure authentication
    try {
        $azAccount = az account show --output json | ConvertFrom-Json
        Write-Success "Logged into Azure account: $($azAccount.name)"
    } catch {
        Write-Warning "Not logged into Azure. Logging in..."
        az login
        $azAccount = az account show --output json | ConvertFrom-Json
    }

    # Check GitHub authentication
    try {
        $ghUser = gh api user --jq .login 2>$null
        Write-Success "Logged into GitHub as: $ghUser"
    } catch {
        Write-Warning "Not logged into GitHub. Logging in..."
        gh auth login
        $ghUser = gh api user --jq .login
    }

    # Check repository
    try {
        $ghRepo = gh repo view --json nameWithOwner --jq .nameWithOwner 2>$null
        Write-Success "GitHub repository: $ghRepo"
    } catch {
        Write-Error "Not in a GitHub repository. Please run this script from your repository root."
        exit 1
    }

    return @{
        GitHubUser = $ghUser
        GitHubRepo = $ghRepo
        RepoName = Split-Path $ghRepo -Leaf
    }
}

function Get-AzureSubscription {
    Write-Header "Selecting Azure Subscription"

    $currentSub = az account show --output json | ConvertFrom-Json
    Write-Info "Current subscription: $($currentSub.name) ($($currentSub.id))"

    $useCurrentSub = Read-Host "Use this subscription? (y/n)"

    if ($useCurrentSub -ne 'y') {
        # List available subscriptions
        Write-Host "Available subscriptions:"
        az account list --output table

        $subId = Read-Host "Enter Subscription ID"
        az account set --subscription $subId
        $currentSub = az account show --output json | ConvertFrom-Json
    }

    Write-Success "Using subscription: $($currentSub.name)"
    return $currentSub.id
}

function New-ServicePrincipal {
    param(
        [string]$SubscriptionId,
        [string]$ServicePrincipalName
    )

    Write-Header "Creating Azure Service Principal"

    # Check if service principal exists
    $existingSp = az ad sp list --display-name $ServicePrincipalName --query "[0].appId" -o tsv 2>$null

    if ($existingSp) {
        Write-Warning "Service Principal already exists: $ServicePrincipalName"
        $recreate = Read-Host "Delete and recreate? (y/n)"

        if ($recreate -eq 'y') {
            Write-Info "Deleting existing Service Principal..."
            az ad sp delete --id $existingSp
            Start-Sleep -Seconds 5
        } else {
            Write-Warning "Resetting credentials for existing Service Principal..."
            $spCreds = az ad sp credential reset --id $existingSp --years 2 | ConvertFrom-Json
            return $spCreds
        }
    }

    # Create new service principal
    Write-Info "Creating Service Principal: $ServicePrincipalName"
    $spCreds = az ad sp create-for-rbac `
        --name $ServicePrincipalName `
        --role "Contributor" `
        --scopes "/subscriptions/$SubscriptionId" `
        --years 2 `
        --sdk-auth | ConvertFrom-Json

    Write-Success "Service Principal created successfully"
    return $spCreds
}

function New-StorageAccount {
    param(
        [string]$ResourceGroupName,
        [string]$StorageAccountName,
        [string]$ContainerName,
        [string]$Location
    )

    Write-Header "Creating Terraform Backend Storage"

    # Create resource group
    $rgExists = az group exists --name $ResourceGroupName | ConvertFrom-Json
    if ($rgExists) {
        Write-Success "Resource group exists: $ResourceGroupName"
    } else {
        Write-Info "Creating resource group: $ResourceGroupName"
        az group create --name $ResourceGroupName --location $Location --output none
        Write-Success "Resource group created"
    }

    # Check for existing storage account
    $existingStorage = az storage account list `
        --resource-group $ResourceGroupName `
        --query "[0].name" -o tsv 2>$null

    if ($existingStorage) {
        Write-Warning "Storage account exists: $existingStorage"
        $useExisting = Read-Host "Use existing storage account? (y/n)"

        if ($useExisting -eq 'y') {
            $StorageAccountName = $existingStorage
        } else {
            # Create new storage account
            Write-Info "Creating storage account: $StorageAccountName"
            az storage account create `
                --name $StorageAccountName `
                --resource-group $ResourceGroupName `
                --location $Location `
                --sku Standard_LRS `
                --encryption-services blob `
                --min-tls-version TLS1_2 `
                --allow-blob-public-access false `
                --output none
            Write-Success "Storage account created: $StorageAccountName"
        }
    } else {
        # Create new storage account
        Write-Info "Creating storage account: $StorageAccountName"
        az storage account create `
            --name $StorageAccountName `
            --resource-group $ResourceGroupName `
            --location $Location `
            --sku Standard_LRS `
            --encryption-services blob `
            --min-tls-version TLS1_2 `
            --allow-blob-public-access false `
            --output none
        Write-Success "Storage account created: $StorageAccountName"
    }

    # Create container
    $containerExists = az storage container exists `
        --name $ContainerName `
        --account-name $StorageAccountName `
        --auth-mode login `
        --query exists `
        --output tsv 2>$null

    if ($containerExists -eq "true") {
        Write-Success "Container exists: $ContainerName"
    } else {
        Write-Info "Creating container: $ContainerName"
        az storage container create `
            --name $ContainerName `
            --account-name $StorageAccountName `
            --auth-mode login `
            --output none
        Write-Success "Container created"
    }

    return $StorageAccountName
}

function Get-UserInputs {
    Write-Header "Collecting User Information"

    $inputs = @{}

    # Get admin email
    do {
        $inputs.AdminEmail = Read-Host "Enter admin email for notifications"
    } while ($inputs.AdminEmail -notmatch '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
    Write-Success "Admin email: $($inputs.AdminEmail)"

    # Get current IP address
    Write-Info "Detecting your current IP address..."
    try {
        $currentIp = (Invoke-WebRequest -Uri "https://api.ipify.org" -UseBasicParsing).Content
        Write-Success "Detected IP: $currentIp"
        $useDetectedIp = Read-Host "Use this IP for allowed access? (y/n)"

        if ($useDetectedIp -ne 'y') {
            $currentIp = Read-Host "Enter IP address or CIDR (e.g., 192.168.1.0/24)"
        }
    } catch {
        $currentIp = Read-Host "Enter your IP address or CIDR for allowed access"
    }
    $inputs.AllowedIp = $currentIp

    # Optional: Infracost API key
    $hasInfracost = Read-Host "`nDo you have an Infracost API key? (y/n)"
    if ($hasInfracost -eq 'y') {
        $secureKey = Read-Host "Enter Infracost API key" -AsSecureString
        $inputs.InfracostKey = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureKey)
        )
    } else {
        Write-Info "Skipping Infracost setup (cost estimation will be disabled)"
    }

    # Optional: Slack webhook
    $hasSlack = Read-Host "`nDo you have a Slack webhook URL? (y/n)"
    if ($hasSlack -eq 'y') {
        $inputs.SlackWebhook = Read-Host "Enter Slack webhook URL"
    } else {
        Write-Info "Skipping Slack setup (notifications will be disabled)"
    }

    return $inputs
}

function Set-GitHubSecrets {
    param(
        [hashtable]$Secrets
    )

    Write-Header "Creating GitHub Secrets"

    foreach ($secret in $Secrets.GetEnumerator()) {
        if ($secret.Value) {
            try {
                $secret.Value | gh secret set $secret.Key 2>$null
                Write-Success "Set secret: $($secret.Key)"
            } catch {
                Write-Warning "Failed to set secret: $($secret.Key)"
            }
        }
    }
}

function Update-ConfigurationFiles {
    param(
        [string]$StorageAccountName,
        [string]$GitHubUsername,
        [string]$AdminEmail,
        [string]$AllowedIp
    )

    Write-Header "Updating Configuration Files"

    # Update backend configuration files
    @("dev", "staging", "prod") | ForEach-Object {
        $backendFile = "environments\$_\backend.tf"
        if (Test-Path $backendFile) {
            Write-Info "Updating $backendFile"
            (Get-Content $backendFile) -replace 'stterraformstate12345', $StorageAccountName |
                Set-Content $backendFile
            Write-Success "Updated backend configuration for $_"
        }
    }

    # Update terraform.tfvars files
    @("dev", "staging", "prod") | ForEach-Object {
        $tfvarsFile = "environments\$_\terraform.tfvars"
        if (Test-Path $tfvarsFile) {
            Write-Info "Updating $tfvarsFile"
            $content = Get-Content $tfvarsFile
            $content = $content -replace 'YOUR_OFFICE_IP/32', "$AllowedIp/32"
            $content = $content -replace 'admin@example.com', $AdminEmail
            $content | Set-Content $tfvarsFile
            Write-Success "Updated terraform.tfvars for $_"
        }
    }

    # Update README.md
    if (Test-Path "README.md") {
        Write-Info "Updating README.md"
        (Get-Content "README.md") -replace 'YOUR_GITHUB_USERNAME', $GitHubUsername |
            Set-Content "README.md"
        Write-Success "Updated README.md"
    }

    # Update CODEOWNERS
    if (Test-Path ".github\CODEOWNERS") {
        Write-Info "Updating CODEOWNERS"
        (Get-Content ".github\CODEOWNERS") -replace 'YOUR_GITHUB_USERNAME', $GitHubUsername |
            Set-Content ".github\CODEOWNERS"
        Write-Success "Updated CODEOWNERS"
    }

    # Update dependabot.yml
    if (Test-Path ".github\dependabot.yml") {
        Write-Info "Updating dependabot.yml"
        (Get-Content ".github\dependabot.yml") -replace 'YOUR_GITHUB_USERNAME', $GitHubUsername |
            Set-Content ".github\dependabot.yml"
        Write-Success "Updated dependabot.yml"
    }
}

function New-GitHubEnvironments {
    param(
        [string]$GitHubRepo,
        [string]$GitHubUsername
    )

    Write-Header "Creating GitHub Environments"

    # Check permissions
    try {
        gh api repos/$GitHubRepo/environments --silent 2>$null
    } catch {
        Write-Warning "Cannot create environments (requires GitHub Pro/Enterprise or public repo)"
        Write-Info "Please manually create environments: dev, staging, prod"
        return
    }

    # Create environments
    @("dev", "staging", "prod") | ForEach-Object {
        Write-Info "Creating environment: $_"

        try {
            if ($_ -eq "prod") {
                # Add protection rules for prod
                $userId = gh api user --jq .id
                gh api --method PUT repos/$GitHubRepo/environments/$_ `
                    --field wait_timer=10 `
                    --field "reviewers[][type]=User" `
                    --field "reviewers[][id]=$userId" `
                    --silent 2>$null
            } else {
                gh api --method PUT repos/$GitHubRepo/environments/$_ `
                    --field wait_timer=0 `
                    --silent 2>$null
            }
            Write-Success "Environment configured: $_"
        } catch {
            Write-Warning "Failed to create environment: $_"
        }
    }
}

function New-Summary {
    param(
        [hashtable]$Config
    )

    Write-Header "Setup Complete!"

    $summaryFile = "PIPELINE_SETUP_SUMMARY.md"

    @"
# CI/CD Pipeline Setup Summary

Generated on: $(Get-Date)

## Azure Resources Created

- **Subscription ID**: $($Config.SubscriptionId)
- **Service Principal**: $($Config.ServicePrincipalName)
- **Client ID**: $($Config.ClientId)
- **Tenant ID**: $($Config.TenantId)
- **Resource Group**: $($Config.ResourceGroupName)
- **Storage Account**: $($Config.StorageAccountName)
- **Container**: $($Config.ContainerName)

## GitHub Configuration

- **Repository**: $($Config.GitHubRepo)
- **User**: $($Config.GitHubUsername)
- **Admin Email**: $($Config.AdminEmail)
- **Allowed IP**: $($Config.AllowedIp)/32

## GitHub Secrets Created

✅ ARM_CLIENT_ID
✅ ARM_CLIENT_SECRET
✅ ARM_SUBSCRIPTION_ID
✅ ARM_TENANT_ID
✅ BACKEND_RESOURCE_GROUP
✅ BACKEND_STORAGE_ACCOUNT
✅ BACKEND_CONTAINER
✅ ADMIN_EMAIL
$(if ($Config.InfracostKey) { "✅ INFRACOST_API_KEY" } else { "⭕ INFRACOST_API_KEY (not configured)" })
$(if ($Config.SlackWebhook) { "✅ SLACK_WEBHOOK_URL" } else { "⭕ SLACK_WEBHOOK_URL (not configured)" })

## Files Updated

- environments/*/backend.tf (storage account name)
- environments/*/terraform.tfvars (IP address and email)
- README.md (GitHub username)
- .github/CODEOWNERS (GitHub username)
- .github/dependabot.yml (GitHub username)

## Next Steps

1. Review and commit the changes:
   ``````powershell
   git add -A
   git commit -m "Configure CI/CD pipeline settings"
   git push
   ``````

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
"@ | Out-File -FilePath $summaryFile -Encoding UTF8

    Write-Success "Summary saved to: $summaryFile"
    Get-Content $summaryFile
}

# ============================================================================
# Main Execution
# ============================================================================

Write-Header "Terraform Azure CI/CD Pipeline Setup"

# Check prerequisites
Test-Prerequisites

# Check authentication
$authInfo = Test-Authentication
$GitHubUsername = $authInfo.GitHubUser
$GitHubRepo = $authInfo.GitHubRepo
$ServicePrincipalName = "sp-terraform-cicd-$($authInfo.RepoName)"

# Get Azure subscription
$SubscriptionId = Get-AzureSubscription

# Create service principal
$spCreds = New-ServicePrincipal -SubscriptionId $SubscriptionId -ServicePrincipalName $ServicePrincipalName

# Create storage account
$StorageAccountName = New-StorageAccount `
    -ResourceGroupName $ResourceGroupName `
    -StorageAccountName $StorageAccountName `
    -ContainerName $ContainerName `
    -Location $Location

# Get user inputs
$userInputs = Get-UserInputs

# Create GitHub secrets
$secrets = @{
    ARM_CLIENT_ID = $spCreds.clientId
    ARM_CLIENT_SECRET = $spCreds.clientSecret
    ARM_SUBSCRIPTION_ID = $SubscriptionId
    ARM_TENANT_ID = $spCreds.tenantId
    BACKEND_RESOURCE_GROUP = $ResourceGroupName
    BACKEND_STORAGE_ACCOUNT = $StorageAccountName
    BACKEND_CONTAINER = $ContainerName
    ADMIN_EMAIL = $userInputs.AdminEmail
}

if ($userInputs.InfracostKey) {
    $secrets.INFRACOST_API_KEY = $userInputs.InfracostKey
}

if ($userInputs.SlackWebhook) {
    $secrets.SLACK_WEBHOOK_URL = $userInputs.SlackWebhook
}

Set-GitHubSecrets -Secrets $secrets

# Update configuration files
Update-ConfigurationFiles `
    -StorageAccountName $StorageAccountName `
    -GitHubUsername $GitHubUsername `
    -AdminEmail $userInputs.AdminEmail `
    -AllowedIp $userInputs.AllowedIp

# Create GitHub environments
New-GitHubEnvironments -GitHubRepo $GitHubRepo -GitHubUsername $GitHubUsername

# Generate summary
$summaryConfig = @{
    SubscriptionId = $SubscriptionId
    ServicePrincipalName = $ServicePrincipalName
    ClientId = $spCreds.clientId
    TenantId = $spCreds.tenantId
    ResourceGroupName = $ResourceGroupName
    StorageAccountName = $StorageAccountName
    ContainerName = $ContainerName
    GitHubRepo = $GitHubRepo
    GitHubUsername = $GitHubUsername
    AdminEmail = $userInputs.AdminEmail
    AllowedIp = $userInputs.AllowedIp
    InfracostKey = $userInputs.InfracostKey
    SlackWebhook = $userInputs.SlackWebhook
}

New-Summary -Config $summaryConfig

Write-Header "🎉 Setup Complete!"
Write-Info "Review PIPELINE_SETUP_SUMMARY.md for details"
Write-Info "Commit and push changes to activate the pipeline"