# Grafana Cloud Synthetic Monitoring: one HTTP check per public site.
# Probes run on the public internet, so a missing DNS record, a broken Cloudflare Tunnel,
# an expired certificate or a 5xx all fail the check, even when the cluster itself is down.

terraform {
  required_providers {
    grafana = {
      source  = "grafana/grafana"
      version = "~> 3.0"
    }
  }
}

variable "sm_url" {
  description = "Synthetic Monitoring API URL for the stack's region (ap-southeast-1 = Singapore)"
  type        = string
  default     = "https://synthetic-monitoring-api-ap-southeast-1.grafana.net"
}

variable "sm_access_token" {
  description = "Synthetic Monitoring access token. Pass via TF_VAR_sm_access_token, never commit."
  type        = string
  sensitive   = true
}

variable "probe_names" {
  description = "Public probe locations. Two locations so one bad probe does not page on its own."
  type        = list(string)
  default     = ["Singapore", "Frankfurt"]
}

variable "frequency_ms" {
  description = "How often each probe runs each check. 5 minutes keeps the free tier's execution budget."
  type        = number
  default     = 300000
}

provider "grafana" {
  sm_url          = var.sm_url
  sm_access_token = var.sm_access_token
}

data "grafana_synthetic_monitoring_probes" "all" {}

locals {
  sites = {
    "en-workshop" = "https://en-workshop.com"
    "stash"       = "https://stash.ionize13.com"
    "java-guide"  = "https://java.ionize13.com"
    "homepage"    = "https://ionize13.com"
  }
  probes = [for name in var.probe_names : data.grafana_synthetic_monitoring_probes.all.probes[name]]
}

resource "grafana_synthetic_monitoring_check" "http" {
  for_each = local.sites

  job                = each.key
  target             = each.value
  enabled            = true
  probes             = local.probes
  frequency          = var.frequency_ms
  timeout            = 10000
  basic_metrics_only = true

  labels = {
    cluster = "hetzner"
  }

  settings {
    http {
      method          = "GET"
      fail_if_ssl     = false
      fail_if_not_ssl = true
    }
  }
}

output "available_probes" {
  description = "Probe names you can use in probe_names"
  value       = sort(keys(data.grafana_synthetic_monitoring_probes.all.probes))
}

# Per-check alerting (the legacy alert_sensitivity field is rejected on new stacks).
resource "grafana_synthetic_monitoring_check_alerts" "http" {
  for_each = grafana_synthetic_monitoring_check.http

  check_id = each.value.id
  alerts = [{
    name      = "ProbeFailedExecutionsTooHigh"
    threshold = 1
    period    = "15m"
  }]
}
