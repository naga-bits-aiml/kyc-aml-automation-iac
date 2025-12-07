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
  # Default allows SSH only through Cloud IAP TCP forwarding (35.235.240.0/20)
  default     = ["35.235.240.0/20"]

  validation {
    condition     = var.allowed_ssh_worldwide_override || !contains(var.allowed_ssh_source_ranges, "0.0.0.0/0")
    error_message = "allowed_ssh_source_ranges cannot include 0.0.0.0/0 unless allowed_ssh_worldwide_override is set to true."
  }
}

variable "allowed_web_source_ranges" {
  type        = list(string)
  description = "List of CIDR blocks allowed to reach HTTP/HTTPS (ports 80,443)."
  default     = ["0.0.0.0/0"]
}

variable "allowed_ssh_worldwide_override" {
  type        = bool
  description = "Opt-out flag to permit 0.0.0.0/0 in allowed_ssh_source_ranges for exceptional cases."
  default     = false
}

variable "install_tesseract" {
  type        = bool
  description = "Whether to install Tesseract OCR via the instance startup script. Can be controlled from Terraform."
  default     = false
}

variable "instance_metadata" {
  type        = map(string)
  description = "Optional metadata map to attach to the instance. Values are merged with startup-script and INSTALL_TESSERACT."
  default     = {}
}
