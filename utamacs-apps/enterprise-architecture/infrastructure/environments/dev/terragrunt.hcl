# Development environment — smaller, cheaper, single-AZ
# Mirrors production architecture but with burstable SKUs

locals {
  environment     = "dev"
  location        = "centralindia"
  resource_prefix = "utamacs-dev"

  common_tags = {
    environment  = "dev"
    project      = "utamacs"
    managed_by   = "terraform"
    cost_center  = "engineering"
  }
}

remote_state {
  backend = "azurerm"
  config = {
    resource_group_name  = "utamacs-tfstate-rg"
    storage_account_name = "utamacstfstate"
    container_name       = "tfstate"
    key                  = "dev/terraform.tfstate"
    use_oidc             = true
  }
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
}

inputs = {
  environment       = local.environment
  location          = local.location
  resource_prefix   = local.resource_prefix
  common_tags       = local.common_tags

  kubernetes_version = "1.31"
  system_node_count  = 1
  api_node_min       = 1
  api_node_max       = 3
  api_vm_size        = "Standard_D2s_v5"
  worker_node_min    = 1
  worker_node_max    = 2
  worker_vm_size     = "Standard_B2s"

  pg_sku_name        = "B_Standard_B2ms"   # Burstable for dev
  pg_storage_mb      = 32768

  redis_sku          = "Standard"
  redis_capacity     = 1
  redis_family       = "C"

  service_bus_sku    = "Standard"

  enable_geo_redundant_backup = false
  enable_zone_redundant_ha    = false
  enable_defender             = false   # Cost saving in dev
}
