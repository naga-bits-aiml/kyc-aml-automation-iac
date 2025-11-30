variable "project_id" {
  type        = string
  description = "GCP Project ID"
  default     = "kyc-aml-automation"
}

variable "region" {
  type        = string
  default     = "us-central1"
}

variable "zone" {
  type        = string
  default     = "us-central1-a"
}

variable "vm_name" {
  type        = string
  default     = "kyc-onboarding-vm"
}

variable "machine_type" {
  type        = string
  default     = "e2-micro"
}

variable "allowed_ssh_source_ranges" {
  type        = list(string)
  description = "List of CIDR blocks allowed to reach SSH (port 22). Avoid 0.0.0.0/0 for production."
  default     = ["0.0.0.0/0"]
}

variable "allowed_web_source_ranges" {
  type        = list(string)
  description = "List of CIDR blocks allowed to reach HTTP/HTTPS (ports 80,443)."
  default     = ["0.0.0.0/0"]
}
