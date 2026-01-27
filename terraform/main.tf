terraform {
  required_providers {
    contabo = {
      source = "contabo/contabo"
    }
  }
}

provider "contabo" {
  client_id     = var.contabo_client_id
  client_secret = var.contabo_client_secret
}

resource "null_resource" "bootstrap" {
  connection {
    host        = var.vps_ip
    user        = "root"
    private_key = file(var.ssh_private_key_path)
  }

  provisioner "remote-exec" {
    inline = [
      # ---- user setup ----
      "id platform || useradd -m -s /bin/bash platform",
      "echo 'platform ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/platform",

      "mkdir -p /home/platform/.ssh",
      "cp /root/.ssh/authorized_keys /home/platform/.ssh/authorized_keys",
      "chown -R platform:platform /home/platform/.ssh",
      "chmod 700 /home/platform/.ssh",
      "chmod 600 /home/platform/.ssh/authorized_keys",

      # ---- base packages ----
      "apt update && apt install -y curl git sudo",

      # ---- k3s ----
      "su - platform -c \"curl -sfL https://get.k3s.io | sh -\"",

      "mkdir -p /home/platform/.kube",
      "cp /etc/rancher/k3s/k3s.yaml /home/platform/.kube/config",
      "chown -R platform:platform /home/platform/.kube",

      # ---- helm ----
      "su - platform -c \"curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash\"",

      # ---- argo cd ----
      "su - platform -c \"kubectl create namespace argocd || true\"",
      "su - platform -c \"kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml\"",

      # ---- ghcr image pull secret ----
      "su - platform -c \"kubectl create secret docker-registry ghcr-secret \
        --docker-server=ghcr.io \
        --docker-username=${var.ghcr_username} \
        --docker-password=${var.ghcr_token} \
        --dry-run=client -o yaml | kubectl apply -f -\"",

      # ---- monitoring ----
      "su - platform -c \"helm repo add prometheus-community https://prometheus-community.github.io/helm-charts\"",
      "su - platform -c \"helm repo update\"",
      "su - platform -c \"helm install monitoring prometheus-community/kube-prometheus-stack \
        --namespace monitoring --create-namespace \
        --set prometheus.prometheusSpec.retention=3d \
        --set grafana.resources.requests.memory=150Mi\""
    ]
  }
}
