resource "google_compute_firewall" "allow_ssh" {
  name    = "kyc-allow-ssh"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  # Default is empty to avoid world-open SSH; provide explicit admin CIDRs via allowed_ssh_source_ranges.
  source_ranges = var.allowed_ssh_source_ranges

  target_tags = ["kyc-ssh"]
}

resource "google_compute_firewall" "allow_web" {
  name    = "kyc-allow-web"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = var.allowed_web_source_ranges

  target_tags = ["kyc-web"]
}

resource "google_compute_instance" "kyc_onboarding_vm" {
  name         = var.kyc_onboarding_vm_name
  zone         = var.zone
  machine_type = var.machine_type
  tags         = ["kyc-ssh", "kyc-web", "kyc-instance-group"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 30
    }
  }

  metadata = merge(var.instance_metadata, {
    INSTALL_DOCKER    = "1"
    INSTALL_NGINX     = "1"
    INSTALL_TESSERACT = var.install_tesseract ? "1" : "0"
    INSTALL_SUPERVISOR = "1"
    "startup-script" = file("${path.module}/startup.sh")
  })

  network_interface {
    network = "default"

    access_config {} # this creates external IP
  }
}

resource "google_compute_instance" "kyc_web_agent_vm" {
  name         = var.kyc_web_agent_vm_name
  zone         = var.zone
  machine_type = var.machine_type
  tags         = ["kyc-ssh", "kyc-web", "kyc-instance-group"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 30
    }
  }

  metadata = merge(var.instance_metadata, {
    INSTALL_DOCKER    = "0"
    INSTALL_NGINX     = "0"
    INSTALL_TESSERACT = "0"
    INSTALL_SUPERVISOR = "1"
    "startup-script" = file("${path.module}/startup.sh")
  })

  network_interface {
    network = "default"

    access_config {} # this creates external IP
  }
}

resource "google_compute_instance_group" "kyc_instance_group" {
  name        = "kyc-instance-group"
  zone        = var.zone
  description = "Instance group for KYC infrastructure VMs"

  instances = [
    google_compute_instance.kyc_onboarding_vm.id,
    google_compute_instance.kyc_web_agent_vm.id
  ]

  named_port {
    name = "http"
    port = "80"
  }

  named_port {
    name = "https"
    port = "443"
  }
}
