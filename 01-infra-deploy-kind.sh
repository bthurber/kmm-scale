#!/bin/bash

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
