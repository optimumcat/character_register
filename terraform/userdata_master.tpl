su admin -c 'echo "### Initializing control plane node" ;\
sudo kubeadm init --pod-network-cidr=${pod_network_cidr} ;\
echo "### Configuring kubectl" ;\
mkdir -p $HOME/.kube ;\
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config ;\
sudo chown $(id -u):$(id -g) $HOME/.kube/config ;\
echo "### Installing Calico" ;\
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.2/manifests/tigera-operator.yaml ;\
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.2/manifests/custom-resources.yaml'
