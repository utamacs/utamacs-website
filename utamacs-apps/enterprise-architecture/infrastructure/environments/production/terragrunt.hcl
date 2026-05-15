# Production environment — Terragrunt root config
# All resources deploy to Azure Central India (Pune) for DPDPA compliance

locals {
  environment     = "production"
  location        = "centralindia"   # DPDPA data residency requirement
  location_short  = "cin"
  resource_prefix = "utamacs-prod"

  common_tags = {
    environment  = "production"
    project      = "utamacs"
    managed_by   = "terraform"
    cost_center  = "platform"
    data_class   = "confidential"
    dpdpa_scope  = "true"
  }
}

# Remote state: Azure Blob Storage (encrypted, versioned)
remote_state {
  backend = "azurerm"
  config = {
    resource_group_name  = "utamacs-tfstate-rg"
    storage_account_name = "utamacstfstate"
    container_name       = "tfstate"
    key                  = "${local.environment}/terraform.tfstate"
    use_oidc             = true   # GitHub Actions OIDC — no stored credentials
  }
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite"
  contents  = <<EOF
provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = false
      recover_soft_deleted_key_vaults = true
    }
    resource_group {
      prevent_deletion_if_contains_resources = true  # Safety net
    }
  }
  use_oidc = true
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

provider "kubernetes" {
  host                   = data.azurerm_kubernetes_cluster.main.kube_config[0].host
  client_certificate     = base64decode(data.azurerm_kubernetes_cluster.main.kube_config[0].client_certificate)
  client_key             = base64decode(data.azurerm_kubernetes_cluster.main.kube_config[0].client_key)
  cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.main.kube_config[0].cluster_ca_certificate)
}
EOF
}

inputs = {
  environment       = local.environment
  location          = local.location
  resource_prefix   = local.resource_prefix
  common_tags       = local.common_tags

  # AKS configuration
  kubernetes_version = "1.31"
  system_node_count  = 2
  api_node_min       = 3
  api_node_max       = 10
  api_vm_size        = "Standard_D4s_v5"
  worker_node_min    = 2
  worker_node_max    = 6
  worker_vm_size     = "Standard_D2s_v5"

  # PostgreSQL configuration
  pg_sku_name        = "GP_Standard_D4s_v3"
  pg_storage_mb      = 131072   # 128 GB

  # Redis configuration
  redis_sku          = "Premium"
  redis_capacity     = 1
  redis_family       = "P"

  # Service Bus
  service_bus_sku    = "Premium"
  service_bus_capacity = 1

  # Feature flags
  enable_geo_redundant_backup = true
  enable_zone_redundant_ha    = true
  enable_defender             = true
}
