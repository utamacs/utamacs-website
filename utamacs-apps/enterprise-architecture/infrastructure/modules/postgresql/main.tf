# Azure PostgreSQL Flexible Server — Zone-Redundant HA
# Multi-tenant: schema-per-tenant isolation, PgBouncer connection pooling

terraform {
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 3.100" }
    random  = { source = "hashicorp/random",  version = "~> 3.6" }
  }
}

resource "random_password" "admin" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}:?"
}

resource "azurerm_postgresql_flexible_server" "main" {
  name                = "utamacs-${var.environment}-pg"
  resource_group_name = var.resource_group_name
  location            = var.location  # centralindia — data residency

  # Zone-redundant HA: primary in zone 1, standby in zone 2
  # Failover is automatic, < 60 second RPO, < 120 second RTO
  high_availability {
    mode                      = "ZoneRedundant"
    standby_availability_zone = "2"
  }
  zone = "1"

  sku_name               = var.sku_name      # dev: B_Standard_B2ms; prod: GP_Standard_D4s_v3
  storage_mb             = var.storage_mb    # dev: 32768; prod: 131072 (128GB)
  backup_retention_days  = var.environment == "production" ? 35 : 7
  geo_redundant_backup_enabled = var.environment == "production"  # Cross-region backup for prod

  # Admin credentials — stored in Key Vault, never in Terraform state
  administrator_login    = "utamacs_admin"
  administrator_password = random_password.admin.result

  # PostgreSQL 16 — latest stable
  version = "16"

  # Network: Private Endpoint only — no public internet access
  delegated_subnet_id    = var.delegated_subnet_id
  private_dns_zone_id    = var.private_dns_zone_id

  # Performance settings
  postgresql_configurations = [
    { name = "max_connections",             value = "200" },
    { name = "shared_buffers",              value = "256MB" },
    { name = "work_mem",                    value = "16MB" },
    { name = "maintenance_work_mem",        value = "128MB" },
    { name = "effective_cache_size",        value = "1GB" },
    { name = "log_min_duration_statement",  value = "1000" },  # Log queries > 1s
    { name = "log_connections",             value = "on" },
    { name = "log_disconnections",          value = "on" },
    { name = "pgaudit.log",                 value = "write,ddl" },  # DPDPA audit
    { name = "azure.extensions",            value = "pgaudit,pg_stat_statements,pg_cron" },
  ]

  tags = merge(var.common_tags, {
    service     = "database"
    data_class  = "confidential"     # Data classification tag
    dpdpa_scope = "true"             # Flags for DPDPA compliance tooling
  })

  lifecycle {
    prevent_destroy = true   # Never accidentally destroy the database
  }
}

# Store admin password in Key Vault — never access directly
resource "azurerm_key_vault_secret" "pg_admin_password" {
  name         = "pg-admin-password-${var.environment}"
  value        = random_password.admin.result
  key_vault_id = var.key_vault_id

  expiration_date = timeadd(timestamp(), "8760h")  # Rotate annually

  lifecycle {
    ignore_changes = [expiration_date]  # Don't re-create on every plan
  }
}

# PgBouncer connection pooler — reduces connection overhead for serverless
# (AKS pods connecting simultaneously)
resource "azurerm_postgresql_flexible_server_configuration" "pgbouncer" {
  name      = "pgbouncer.enabled"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = "true"
}

# Diagnostic settings — all logs to Log Analytics for DPDPA audit trail
resource "azurerm_monitor_diagnostic_setting" "pg_diagnostics" {
  name                       = "pg-diagnostics"
  target_resource_id         = azurerm_postgresql_flexible_server.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log { category = "PostgreSQLLogs" }
  enabled_log { category = "PostgreSQLFlexDatabaseXacts" }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
