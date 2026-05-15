# Cloudflare Infrastructure — Edge Gateway, R2 Storage, KV, Images
# All tenant routing and document storage is managed here

terraform {
  required_providers {
    cloudflare = { source = "cloudflare/cloudflare", version = "~> 4.36" }
  }
}

# R2 Bucket — document and media storage (replaces GitHub doc store)
resource "cloudflare_r2_bucket" "documents" {
  account_id = var.cloudflare_account_id
  name       = "utamacs-documents-${var.environment}"
  location   = "APAC"   # Singapore — closest to India, data residency in Asia-Pacific
}

resource "cloudflare_r2_bucket" "media" {
  account_id = var.cloudflare_account_id
  name       = "utamacs-media-${var.environment}"
  location   = "APAC"
}

resource "cloudflare_r2_bucket" "exports" {
  account_id = var.cloudflare_account_id
  name       = "utamacs-exports-${var.environment}"
  location   = "APAC"
}

# R2 lifecycle rules — auto-delete exports after 24 hours
resource "cloudflare_r2_bucket_lifecycle_rule" "exports_ttl" {
  account_id  = var.cloudflare_account_id
  bucket_name = cloudflare_r2_bucket.exports.name

  rules = [{
    id      = "delete-after-24h"
    enabled = true
    expiration = { days = 1 }
    filter = { prefix = "" }
  }]
}

# KV Namespace — tenant routing table (tenant_slug → tenant_id, plan, status)
# Globally replicated, ~1ms read latency worldwide
resource "cloudflare_workers_kv_namespace" "tenants" {
  account_id = var.cloudflare_account_id
  title      = "utamacs-tenants-${var.environment}"
}

# KV Namespace — feature flags cache (refreshed every 5 minutes)
resource "cloudflare_workers_kv_namespace" "feature_flags" {
  account_id = var.cloudflare_account_id
  title      = "utamacs-flags-${var.environment}"
}

# KV Namespace — visitor pass revocation bloom filters (per-tenant)
resource "cloudflare_workers_kv_namespace" "pass_revocations" {
  account_id = var.cloudflare_account_id
  title      = "utamacs-pass-revocations-${var.environment}"
}

# Rate limiter — per device_id, per tenant, per endpoint
resource "cloudflare_rate_limit" "api_per_device" {
  zone_id   = var.cloudflare_zone_id
  threshold = 100      # 100 requests
  period    = 60       # per 60 seconds

  match {
    request {
      url_pattern = "api.utamacs.org/api/v1/*"
      schemes     = ["HTTPS"]
    }
  }

  action {
    mode    = "ban"
    timeout = 60
    response {
      content_type = "application/json"
      body         = "{\"error\":\"RATE_LIMITED\",\"message\":\"Too many requests. Please wait 60 seconds.\"}"
    }
  }
}

# WAF Custom Rules — OWASP Core Rule Set + custom rules
resource "cloudflare_ruleset" "waf" {
  zone_id     = var.cloudflare_zone_id
  name        = "UTA MACS WAF Rules"
  description = "Custom WAF rules for UTAMACS platform"
  kind        = "zone"
  phase       = "http_request_firewall_custom"

  rules = [
    # Block requests without X-Platform header (native app or web only)
    {
      action      = "block"
      expression  = "not (http.request.headers[\"x-platform\"] in {\"flutter-android\" \"flutter-ios\" \"flutter-web\" \"flutter-desktop\" \"web\"})"
      description = "Reject requests not from known platforms"
      enabled     = false  # Enable after mobile launch — not during testing
    },
    # Block SQL injection patterns
    {
      action      = "block"
      expression  = "http.request.uri.query contains \"'\" and http.request.uri.query contains \"--\""
      description = "Basic SQL injection protection"
      enabled     = true
    },
    # Geo-restrict to India + common expat locations
    {
      action      = "challenge"
      expression  = "not (ip.geoip.country in {\"IN\" \"AE\" \"US\" \"GB\" \"SG\" \"AU\"})"
      description = "Challenge non-Indian traffic"
      enabled     = var.environment == "production"
    }
  ]
}

# DNS records
resource "cloudflare_record" "api" {
  zone_id = var.cloudflare_zone_id
  name    = "api"
  type    = "CNAME"
  value   = var.aks_ingress_hostname
  proxied = true   # Traffic flows through Cloudflare — AKS has no public IP
  ttl     = 1      # Auto (managed by Cloudflare)
}

resource "cloudflare_record" "portal" {
  zone_id = var.cloudflare_zone_id
  name    = "portal"
  type    = "CNAME"
  value   = var.azure_static_web_app_hostname
  proxied = true
  ttl     = 1
}

# Cloudflare Tunnel — secure private connection to AKS without public IP
resource "cloudflare_tunnel" "aks" {
  account_id = var.cloudflare_account_id
  name       = "utamacs-aks-${var.environment}"
  secret     = var.tunnel_secret
}

resource "cloudflare_tunnel_config" "aks" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_tunnel.aks.id

  config {
    ingress_rule {
      hostname = "api.utamacs.org"
      service  = "http://api-service.production.svc.cluster.local:3000"
    }
    ingress_rule {
      service = "http_status:404"
    }
  }
}
