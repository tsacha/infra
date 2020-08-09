#!/usr/bin/env bash
set -euo pipefail

pushd certs/
# Kube-proxy configuration
{
    KUBERNETES_PUBLIC_ADDRESS=k8s-controller.tsacha.fr
    kubectl config set-cluster kubernetes \
        --certificate-authority=ca.pem \
        --embed-certs=true \
        --server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443

    kubectl config set-credentials admin \
        --client-certificate=admin.pem \
        --client-key=admin-key.pem

    kubectl config set-context kubernetes \
        --cluster=kubernetes \
        --user=admin

    kubectl config use-context kubernetes
}

popd
