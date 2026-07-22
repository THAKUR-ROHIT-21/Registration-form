output "frontend_url" {
  description = "Frontend website URL."
  value       = "http://${google_compute_address.app_ip.address}"
}

output "backend_api_url" {
  description = "Backend users API URL through Nginx."
  value       = "http://${google_compute_address.app_ip.address}/api/users"
}

output "backend_health_url" {
  description = "Backend health-check URL."
  value       = "http://${google_compute_address.app_ip.address}/api/health"
}

output "vm_external_ip" {
  description = "Public static IP of the application VM."
  value       = google_compute_address.app_ip.address
}

output "vm_internal_ip" {
  description = "Private IP of the application VM."
  value       = google_compute_instance.app_vm.network_interface[0].network_ip
}

output "atlas_allowlist_cidr" {
  description = "Add this CIDR to MongoDB Atlas Network Access."
  value       = "${google_compute_address.app_ip.address}/32"
}

output "ssh_private_key_path" {
  description = "Generated SSH private-key path."
  value       = local_sensitive_file.private_key.filename
}

output "ssh_command" {
  description = "Command to connect to the GCP VM."
  value       = "ssh -o StrictHostKeyChecking=no -i ${local_sensitive_file.private_key.filename} ${var.ssh_user}@${google_compute_address.app_ip.address}"
}

output "application_directory" {
  description = "Application directory inside the VM."
  value       = "/opt/user-registration"
}

output "docker_status_command" {
  description = "Command to check frontend, backend and Nginx containers."
  value       = "ssh -i ${local_sensitive_file.private_key.filename} ${var.ssh_user}@${google_compute_address.app_ip.address} 'cd /opt/user-registration && sudo docker compose ps'"
}

output "backend_logs_command" {
  description = "Command to view backend logs."
  value       = "ssh -i ${local_sensitive_file.private_key.filename} ${var.ssh_user}@${google_compute_address.app_ip.address} 'cd /opt/user-registration && sudo docker compose logs -f backend'"
}

output "frontend_logs_command" {
  description = "Command to view frontend logs."
  value       = "ssh -i ${local_sensitive_file.private_key.filename} ${var.ssh_user}@${google_compute_address.app_ip.address} 'cd /opt/user-registration && sudo docker compose logs -f frontend'"
}

output "deployment_summary" {
  description = "Important URLs and SSH details."
  value = {
    frontend       = "http://${google_compute_address.app_ip.address}"
    backend_api    = "http://${google_compute_address.app_ip.address}/api/users"
    backend_health = "http://${google_compute_address.app_ip.address}/api/health"
    ssh            = "ssh -o StrictHostKeyChecking=no -i ${local_sensitive_file.private_key.filename} ${var.ssh_user}@${google_compute_address.app_ip.address}"
    app_directory  = "/opt/user-registration"
  }
}
