variable "browserstation_api_key" {
  description = "API key for BrowserStation authentication. If empty, authentication is disabled."
  type        = string
  default     = ""
  sensitive   = true
}

variable "ray_version" {
  description = "Ray version to deploy"
  type        = string
  default     = "2.47.1"
}