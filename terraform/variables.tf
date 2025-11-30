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
