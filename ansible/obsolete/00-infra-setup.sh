#!/bin/bash

# Moved to ansible playbook

# # Adjust limits
# sudo sysctl fs.inotify.max_user_watches=524288
# sudo sysctl fs.inotify.max_user_instances=512

# # Install tmux
# dnf -y install tmux

# # Upgrade packages
# dnf -y upgrade

# # Enable epel
# dnf -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm

# # Install a proper editor
# dnf -y install joe

# # Install container engine
# dnf -y install podman

# # Install go
# dnf -y install go

# # Extend path
# echo 'PATH=$PATH:~/go/bin' >~/.bashrc

ansible-playbook -i allhosts setup.yaml

# Install kind
go install sigs.k8s.io/kind@v0.17

# Install clusteradm
curl -L https://raw.githubusercontent.com/open-cluster-management-io/clusteradm/main/install.sh | bash

# Install kubectl
curl -L https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl >/usr/bin/kubectl
chmod +x /usr/bin/kubectl

# Prepare kcli installation
sudo usermod -aG qemu,libvirt $(id -un)
sudo newgrp libvirt
sudo systemctl enable --now libvirtd

# Optional if using docker daemon
sudo groupadd docker
sudo usermod -aG docker $(id -un)
sudo systemctl restart docker

sudo dnf -y copr enable karmab/kcli
sudo dnf -y install kcli

# Create ssh key if missing
[ -f /root/.ssh/id_rsa ] || ssh-keygen -P '' -f /root/.ssh/id_rsa

# Enable libvirt default pool if it's not enabled
virsh pool-define-as default dir --target "/var/lib/libvirt/images"
virsh pool-build default
virsh pool-start default
virsh pool-autostart default

# Prepare Hub Creation

# Download openshift-install to avoid bug when downloading in parallel during plan creation
for command in oc openshift-install; do
    kcli download ${command}
    mv ${command} /usr/bin/
done
