output "droplet_ip" {
  description = "Public IP address of the AI Gang HQ droplet"
  value       = digitalocean_droplet.hq.ipv4_address
}

output "ssh_command" {
  description = "SSH command to connect to the droplet"
  value       = "ssh -i ~/.ssh/ai-gang-hq aigang@${digitalocean_droplet.hq.ipv4_address}"
}
