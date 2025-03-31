#!/bin/bash

echo "### Installing SSM Agent"
cd /tmp
wget https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/debian_amd64/amazon-ssm-agent.deb
sudo dpkg -i amazon-ssm-agent.deb
sudo systemctl enable amazon-ssm-agent
sudo systemctl start amazon-ssm-agent

echo "### Installing Docker"
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "### Applying cgroup driver fix"
sudo echo 'version = 2' > /etc/containerd/config.toml
sudo echo '[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]' >> /etc/containerd/config.toml
sudo echo 'runtime_type = "io.containerd.runc.v2"' >> /etc/containerd/config.toml
sudo echo '[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]' >> /etc/containerd/config.toml
sudo echo 'SystemdCgroup = true' >> /etc/containerd/config.toml
sudo systemctl restart containerd

echo "### Installing Kubernetes"
sudo apt-get install -y apt-transport-https gpg
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
sudo systemctl enable --now kubelet

echo "### Setting hostname"
TAG_HOSTNAME=$(curl -s http://169.254.169.254/latest/meta-data/tags/instance/Name)
hostnamectl set-hostname "$TAG_HOSTNAME"

echo "### mkdir for local persistent volume"
if [ "$TAG_HOSTNAME" = "k8s-worker0" ]; then
  mkdir -p /var/lib/mysql
fi
