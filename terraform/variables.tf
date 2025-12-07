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
  description = "List of CIDR blocks allowed to reach SSH (port 22). Defaults open for initial setup; tighten to your laptop / VPN CIDRs later."
  # Default is world-open for ease of first connection; override with a narrow list once you know your IP.
  default     = ["0.0.0.0/0"]

  validation {
    condition     = var.allowed_ssh_worldwide_override || !contains(var.allowed_ssh_source_ranges, "0.0.0.0/0")
    error_message = "Set allowed_ssh_worldwide_override=true to permit 0.0.0.0/0, or provide a restricted list of CIDRs."
  }
}

variable "allowed_web_source_ranges" {
  type        = list(string)
  description = "List of CIDR blocks allowed to reach HTTP/HTTPS (ports 80,443)."
  default     = ["0.0.0.0/0"]
}

variable "allowed_ssh_worldwide_override" {
  type        = bool
  description = "Flag that controls whether 0.0.0.0/0 is permitted in allowed_ssh_source_ranges (keeps validation togglable)."
  default     = true
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
