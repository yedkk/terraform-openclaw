locals {
  machine_type = (
    var.agent_count <= 1  ? "e2-small" :       # 2 GB
    var.agent_count <= 3  ? "e2-medium" :      # 4 GB
    var.agent_count <= 6  ? "e2-standard-2" :  # 8 GB
    var.agent_count <= 10 ? "e2-standard-4" :  # 16 GB
    "e2-standard-8"                            # 32 GB
  )
  zone = "${var.region}-a"
}

# --- SSH Key (auto-generated) ---

resource "tls_private_key" "ssh" {
  algorithm = "ED25519"
}

# --- Auth Token ---

resource "random_id" "auth_token" {
  count       = var.agent_count
  byte_length = 32
}

# --- VPC Network ---

resource "google_compute_network" "main" {
  name                    = "openclaw-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "public" {
  name          = "openclaw-subnet"
  ip_cidr_range = "10.0.1.0/24"
  region        = var.region
  network       = google_compute_network.main.id
}

# --- Firewall Rules ---

resource "google_compute_firewall" "ssh" {
  name    = "openclaw-allow-ssh"
  network = google_compute_network.main.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["openclaw"]
}

resource "google_compute_firewall" "https" {
  name    = "openclaw-allow-https"
  network = google_compute_network.main.name

  allow {
    protocol = "tcp"
    ports    = concat(["443"], [for i in range(2, var.agent_count + 1) : tostring(8000 + i)])
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["openclaw"]
}

# --- Static External IP ---

resource "google_compute_address" "openclaw" {
  name   = "openclaw-ip"
  region = var.region
}

# --- Compute Instance ---

resource "google_compute_instance" "openclaw" {
  name         = "openclaw"
  machine_type = local.machine_type
  zone         = local.zone
  tags         = ["openclaw"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 30
      type  = "pd-ssd"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.public.id
    access_config {
      nat_ip = google_compute_address.openclaw.address
    }
  }

  metadata = {
    ssh-keys = "ubuntu:${tls_private_key.ssh.public_key_openssh}"
  }

  metadata_startup_script = templatefile("${path.module}/templates/cloud-init.sh.tpl", {
    agent_count = var.agent_count
    auth_tokens = random_id.auth_token[*].hex
  })
}
