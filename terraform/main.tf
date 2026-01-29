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
      "id platform || useradd -m -s /bin/bash platform",
      "echo 'platform ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/platform",

      "mkdir -p /home/platform/.ssh",
      "cp /root/.ssh/authorized_keys /home/platform/.ssh/authorized_keys",
      "chown -R platform:platform /home/platform/.ssh",
      "chmod 700 /home/platform/.ssh",
      "chmod 600 /home/platform/.ssh/authorized_keys",

      "apt update && apt install -y curl git sudo",

      "curl -sfL https://get.k3s.io | sh -",

      "chmod 644 /etc/rancher/k3s/k3s.yaml",
      "mkdir -p /home/platform/.kube",
      "cp /etc/rancher/k3s/k3s.yaml /home/platform/.kube/config",
      "chown -R platform:platform /home/platform/.kube",

      "su - platform -c 'export KUBECONFIG=$HOME/.kube/config && until kubectl get nodes; do sleep 5; done'",

      "su - platform -c 'curl -s https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash'",

      "su - platform -c 'export KUBECONFIG=$HOME/.kube/config && kubectl get ns argocd || kubectl create namespace argocd'",

      "su - platform -c 'export KUBECONFIG=$HOME/.kube/config && kubectl get deploy argocd-server -n argocd || kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml'",

      "su - platform -c 'export KUBECONFIG=$HOME/.kube/config && kubectl create secret docker-registry ghcr-secret --docker-server=ghcr.io --docker-username=${var.ghcr_username} --docker-password=${var.ghcr_token} --dry-run=client -o yaml | kubectl apply -f -'",

      "su - platform -c 'export KUBECONFIG=$HOME/.kube/config && kubectl apply -n argocd -f https://raw.githubusercontent.com/Terabyite/Crypto-Bot-Platform/main/argocd/root-app.yaml'"
    ]
  }
}