variable "helm_external_dns_chart_version" {
  description = "Helm chart version to use for ExternalDNS"
  type        = string
  default     = ""
}

variable "domain" {
  default     = "alerotech.xyz"
  description = "The domain name for Route53"
}

variable "zone_id" {
  default     = "Z00142321A57PFEG01MZN"
  description = "The ID of Route53 hosted zone"
}
