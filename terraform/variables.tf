variable "project_id" {
  description = "Google Cloud project ID."
  type        = string
}

variable "region" {
  description = "GCP region."
  type        = string
  default     = "asia-south1"
}

variable "zone" {
  description = "GCP zone."
  type        = string
  default     = "asia-south1-a"
}

variable "machine_type" {
  description = "Compute Engine machine type."
  type        = string
  default     = "e2-micro"
}

variable "ssh_user" {
  description = "Linux user created through SSH metadata."
  type        = string
  default     = "rohit"
}

variable "ssh_source_cidr" {
  description = "Your public IP in CIDR format, for example 203.0.113.10/32."
  type        = string
}

variable "mongodb_uri" {
  description = "MongoDB Atlas SRV connection URI. Special characters in username/password must be percent-encoded."
  type        = string
  sensitive   = true
}

variable "mongodb_database" {
  description = "MongoDB database name."
  type        = string
  default     = "user_registration"
}
