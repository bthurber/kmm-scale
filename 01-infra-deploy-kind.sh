#!/bin/bash

# Install tmux
dnf -y install tmux

# Upgrade packages
dnf -y upgrade

# Enable epel
dnf -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm

# Install a proper editor
dnf -y install joe

# Install container engine
dnf -y install podman

# Install go
dnf -y install go

# Extend path
echo 'PATH=$PATH:~/go/bin' >~/.bashrc

# Install kind
go install sigs.k8s.io/kind@v0.17

# Install clusteradm
curl -L https://raw.githubusercontent.com/open-cluster-management-io/clusteradm/main/install.sh | bash

# Install kubectl
curl -L https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl >/usr/bin/kubectl
chmod +x /usr/bin/kubectl

# Cleanup previous hosts
kind delete clusters cluster1 cluster2 cluster3 cluster4 cluster5 cluster cluster0 hub

# Prepare Hub Creation
kind create cluster --name hub
export CTX_HUB_CLUSTER=kind-hub

# Prepare clusteradm on HUB
clusteradm init --wait --context ${CTX_HUB_CLUSTER}
kubectl -n open-cluster-management get pod --context ${CTX_HUB_CLUSTER}

# Get values we'll need for adding spokes
apiserver=$(clusteradm get token --context ${CTX_HUB_CLUSTER} | grep -v token= | tr " " "\n" | grep apiserver -A1 | tail -1)

MAXSPOKE=4

# Join the spokes to the cluster
for spoke in $(seq 0 ${MAXSPOKE}); do
    token=$(clusteradm get token --context ${CTX_HUB_CLUSTER} | grep token= | cut -d "=" -f 2-)
    export CTX_MANAGED_CLUSTER=kind-cluster${spoke}
    kind create cluster --name cluster${spoke}
    clusteradm join --context ${CTX_MANAGED_CLUSTER} --hub-token ${token} --hub-apiserver ${apiserver} --wait --cluster-name "cluster${spoke}" --force-internal-endpoint-lookup
done

# Check clusterlet status
for spoke in $(seq 0 ${MAXSPOKE}); do
    export CTX_MANAGED_CLUSTER=kind-cluster${spoke}
    kubectl get klusterlet --context ${CTX_MANAGED_CLUSTER}
done

# Accept joins from HUB
for spoke in $(seq 0 ${MAXSPOKE}); do
    export CTX_MANAGED_CLUSTER=kind-cluster${spoke}
    clusteradm accept --clusters cluster${spoke} --context ${CTX_HUB_CLUSTER}
done

# Check CSR pending
kubectl get csr --context ${CTX_HUB_CLUSTER}
