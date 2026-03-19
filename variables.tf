variable "do_token" {
  description = "DigitalOcean API token"
  type        = string
  sensitive   = true
}

variable "droplet_name" {
  description = "Name of the droplet"
  type        = string
  default     = "ai-gang-hq"
}

variable "droplet_region" {
  description = "DigitalOcean region"
  type        = string
  default     = "nyc1"
}

variable "droplet_size" {
  description = "Droplet size slug"
  type        = string
  default     = "s-2vcpu-2gb"
}

variable "verbose" {
  description = "Stream cloud-init log output during provisioning"
  type        = bool
  default     = false
}

variable "github_deploy_key" {
  description = "Private SSH deploy key for crashtest00/aigang repo"
  type        = string
  sensitive   = true
}
