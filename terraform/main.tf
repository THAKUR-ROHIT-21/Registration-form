resource "google_project_service" "compute" {
  project            = var.project_id
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

resource "google_compute_network" "app_vpc" {
  name                    = "user-registration-vpc"
  auto_create_subnetworks = false
  depends_on              = [google_project_service.compute]
}

resource "google_compute_subnetwork" "app_subnet" {
  name          = "user-registration-subnet"
  ip_cidr_range = "10.10.1.0/24"
  region        = var.region
  network       = google_compute_network.app_vpc.id
}

resource "google_compute_firewall" "allow_http" {
  name    = "user-registration-allow-http"
  network = google_compute_network.app_vpc.name

  direction     = "INGRESS"
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["user-registration-web"]

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
}

resource "google_compute_firewall" "allow_ssh" {
  name    = "user-registration-allow-ssh"
  network = google_compute_network.app_vpc.name

  direction     = "INGRESS"
  source_ranges = [var.ssh_source_cidr]
  target_tags   = ["user-registration-web"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_address" "app_ip" {
  name   = "user-registration-static-ip"
  region = var.region
}

resource "tls_private_key" "ssh" {
  algorithm = "ED25519"
}

resource "local_sensitive_file" "private_key" {
  filename        = "${path.module}/gcp-user-app-key"
  content         = tls_private_key.ssh.private_key_openssh
  file_permission = "0600"
}

resource "local_file" "public_key" {
  filename        = "${path.module}/gcp-user-app-key.pub"
  content         = tls_private_key.ssh.public_key_openssh
  file_permission = "0644"
}

resource "google_compute_instance" "app_vm" {
  name         = "user-registration-vm"
  machine_type = var.machine_type
  zone         = var.zone
  tags         = ["user-registration-web"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2404-lts-amd64"
      size  = 15
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.app_subnet.id

    access_config {
      nat_ip = google_compute_address.app_ip.address
    }
  }

  metadata = {
    ssh-keys = "${var.ssh_user}:${tls_private_key.ssh.public_key_openssh}"
  }

  metadata_startup_script = <<-SCRIPT
    #!/usr/bin/env bash
    set -euxo pipefail
    apt-get update
    apt-get install -y ca-certificates curl
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" > /etc/apt/sources.list.d/docker.list
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    usermod -aG docker ${var.ssh_user}
    systemctl enable --now docker
  SCRIPT

  depends_on = [
    google_compute_firewall.allow_http,
    google_compute_firewall.allow_ssh,
    local_sensitive_file.private_key
  ]
}

resource "null_resource" "deploy_app" {
  triggers = {
    vm_id = google_compute_instance.app_vm.instance_id
    app_checksum = sha256(join("", [
      for f in fileset("${path.module}/../app", "**") :
      filesha256("${path.module}/../app/${f}")
    ]))
  }

  connection {
    type        = "ssh"
    host        = google_compute_address.app_ip.address
    user        = var.ssh_user
    private_key = tls_private_key.ssh.private_key_openssh
    timeout     = "8m"
  }

  provisioner "remote-exec" {
    inline = [
      "cloud-init status --wait || true",
      "sudo mkdir -p /opt/user-registration",
      "sudo chown -R ${var.ssh_user}:${var.ssh_user} /opt/user-registration"
    ]
  }

  provisioner "file" {
    source      = "${path.module}/../app/"
    destination = "/opt/user-registration"
  }

  provisioner "file" {
    content     = <<-ENV
      MONGODB_URI=${var.mongodb_uri}
      MONGODB_DB=${var.mongodb_database}
    ENV
    destination = "/tmp/user-registration.env"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mv /tmp/user-registration.env /opt/user-registration/.env",
      "sudo chmod 600 /opt/user-registration/.env",
      "cd /opt/user-registration && sudo docker compose up -d --build",
      "sudo docker compose -f /opt/user-registration/docker-compose.yml ps"
    ]
  }

  depends_on = [google_compute_instance.app_vm]
}
