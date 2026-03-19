terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

provider "digitalocean" {
  token = var.do_token
}

resource "digitalocean_droplet" "hq" {
  name      = var.droplet_name
  region    = var.droplet_region
  size      = var.droplet_size
  image     = "ubuntu-24-04-x64"
  user_data = file("cloud-init.sh")
}

resource "null_resource" "update_ssh_config" {
  triggers = {
    ip = digitalocean_droplet.hq.ipv4_address
  }

  provisioner "local-exec" {
    command = "sed -i 's/HostName .*/HostName ${digitalocean_droplet.hq.ipv4_address}/' ~/.ssh/config"
  }
}

resource "null_resource" "wait_for_cloud_init" {
  depends_on = [digitalocean_droplet.hq]

  provisioner "local-exec" {
    environment = {
      VERBOSE = var.verbose ? "1" : "0"
    }
    command = <<-EOF
      if [ "$VERBOSE" = "1" ]; then
        REMOTE_CMD='tail -f /var/log/cloud-init-output.log & TAIL_PID=$!; cloud-init status --wait >/dev/null; kill $TAIL_PID'
      else
        REMOTE_CMD='cloud-init status --wait >/dev/null'
      fi
      REMOTE_CMD="$REMOTE_CMD; echo '---'; cat /var/log/cloud-init-complete 2>/dev/null || echo 'cloud-init did not write completion marker'"
      until ssh -i ~/.ssh/ai-gang-hq \
        -o StrictHostKeyChecking=no \
        -o BatchMode=yes \
        -o ConnectTimeout=5 \
        -o ServerAliveInterval=30 \
        root@${digitalocean_droplet.hq.ipv4_address} \
        "$REMOTE_CMD"; do
          echo "Waiting for SSH to become available..."
          sleep 10
      done
    EOF
  }
}
