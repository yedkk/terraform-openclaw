output "public_ip" {
  description = "Public IP address of the OpenClaw server"
  value       = google_compute_address.openclaw.address
}

output "agents" {
  description = "Per-agent dashboard URL and auth token"
  value = {
    for i in range(1, var.agent_count + 1) :
    "agent-${i}" => {
      url   = i == 1 ? "https://${google_compute_address.openclaw.address}" : "https://${google_compute_address.openclaw.address}:${8000 + i}"
      token = random_id.auth_token[i - 1].hex
    }
  }
}

output "ssh_private_key" {
  description = "Private SSH key — run: terraform output -raw ssh_private_key > key.pem && chmod 600 key.pem"
  value       = tls_private_key.ssh.private_key_openssh
  sensitive   = true
}

output "ssh_command" {
  description = "SSH command to connect to the server"
  value       = "ssh -i key.pem ubuntu@${google_compute_address.openclaw.address}"
}
