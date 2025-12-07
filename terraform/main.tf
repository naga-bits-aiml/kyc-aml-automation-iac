resource "google_compute_firewall" "allow_ssh" {
  name    = "kyc-allow-ssh"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

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

resource "google_compute_instance" "vm" {
  name         = var.vm_name
  zone         = var.zone
  machine_type = var.machine_type
  tags         = ["kyc-ssh", "kyc-web"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 30
    }
  }

  metadata = merge(var.instance_metadata, {
    INSTALL_TESSERACT = var.install_tesseract ? "1" : "0",
    "startup-script" = file("${path.module}/startup.sh")
  })

  network_interface {
    network = "default"

    access_config {} # this creates external IP
  }
}
