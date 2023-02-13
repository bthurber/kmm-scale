#!/bin/bash

MAXSPOKE=4

# Cleanup previous hosts
kind delete clusters hub $(echo $(for spoke in $(seq 0 ${MAXSPOKE}); do echo cluster${spoke}; done | xargs echo))

# Prepare Hub Creation
kind create cluster --name hub
export CTX_HUB_CLUSTER=kind-hub

# Prepare clusteradm on HUB
clusteradm init --wait --context ${CTX_HUB_CLUSTER}
kubectl -n open-cluster-management get pod --context ${CTX_HUB_CLUSTER}
kubectl label node hub-control-plane node-role.kubernetes.io/worker="" --context ${CTX_HUB_CLUSTER}

# Get values we'll need for adding spokes
apiserver=$(clusteradm get token --context ${CTX_HUB_CLUSTER} | grep -v token= | tr " " "\n" | grep apiserver -A1 | tail -1)

# Join the spokes to the cluster
for spoke in $(seq 0 ${MAXSPOKE}); do
    token=$(clusteradm get token --context ${CTX_HUB_CLUSTER} | grep token= | cut -d "=" -f 2-)
    export CTX_MANAGED_CLUSTER=kind-cluster${spoke}
    kind create cluster --name cluster${spoke}
    clusteradm join --context ${CTX_MANAGED_CLUSTER} --hub-token ${token} --hub-apiserver ${apiserver} --wait --cluster-name "cluster${spoke}" --force-internal-endpoint-lookup
    kubectl label node hub-control-plane node-role.kubernetes.io/worker="" --context ${CTX_MANAGED_CLUSTER}
done

clusteradm addon enable addon --names config-policy-controller --context ${CTX_HUB_CLUSTER} --clusters $(echo $(for spoke in $(seq 0 ${MAXSPOKE}); do echo cluster${spoke}; done | xargs echo))

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
