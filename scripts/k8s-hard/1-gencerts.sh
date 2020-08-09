#!/usr/bin/env bash
set -euo pipefail

DOCKER_IMAGE="cfssl/cfssl"

if [ -d certs/ ]; then
    rm -Rf certs/
fi
mkdir certs

{
# Generic configuration
cat > certs/ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "8760h"
    },
    "profiles": {
      "kubernetes": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "8760h"
      }
    }
  }
}
EOF

# CA
cat > certs/ca-csr.json <<EOF
{
  "CN": "Kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "FR",
      "L": "Nantes",
      "O": "Sacha T.",
      "OU": "Kubernetes Cluster",
      "ST": "Loire-Atlantique"
    }
  ]
}
EOF

docker run -u $UID -v $PWD/certs:/certs -w /certs --entrypoint cfssl $DOCKER_IMAGE gencert -initca ca-csr.json | docker run -u $UID -v $PWD/certs:/certs -w /certs -i --entrypoint cfssljson $DOCKER_IMAGE -bare ca
}

# ETCD certificates
{
for instance in $(aws ec2 describe-instances --filters Name=instance-state-name,Values=running Name=tag:Name,Values=etcd-cluster --query "Reservations[*].Instances[*].InstanceId" --output text); do

    cat > certs/etcd-$instance-csr.json <<EOF
{
  "CN": "${instance}.etcd-cluster.tsacha.fr",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "FR",
      "L": "Nantes",
      "O": "Sacha T.",
      "OU": "Kubernetes Cluster",
      "ST": "Loire-Atlantique"
    }
  ]
}
EOF

    docker run -u $UID -v $PWD/certs:/certs -w /certs --entrypoint cfssl $DOCKER_IMAGE gencert \
        -ca=ca.pem \
        -ca-key=ca-key.pem \
        -config=ca-config.json \
        -hostname=${instance}.etcd-cluster.tsacha.fr,tsacha.fr \
        -profile=kubernetes \
        etcd-${instance}-csr.json | docker run -u $UID -v $PWD/certs:/certs -w /certs -i --entrypoint cfssljson $DOCKER_IMAGE -bare etcd-${instance}
done
}

# Controller certificates
{
KUBERNETES_HOSTNAMES=kubernetes,kubernetes.default,kubernetes.default.svc,kubernetes.default.svc.cluster,kubernetes.svc.cluster.local
for instance in $(aws ec2 describe-instances --filters Name=instance-state-name,Values=running Name=tag:Name,Values=k8s-controller --query "Reservations[*].Instances[*].InstanceId" --output text); do
    cat > certs/controller-$instance-csr.json <<EOF
{
  "CN": "kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "FR",
      "L": "Nantes",
      "O": "Sacha T.",
      "OU": "Kubernetes Cluster",
      "ST": "Loire-Atlantique"
    }
  ]
}
EOF

    docker run -u $UID -v $PWD/certs:/certs -w /certs --entrypoint cfssl $DOCKER_IMAGE gencert \
        -ca=ca.pem \
        -ca-key=ca-key.pem \
        -config=ca-config.json \
        -hostname=10.32.0.1,${instance}.k8s-controller.tsacha.fr,k8s-controller.tsacha.fr,tsacha.fr,127.0.0.1,${KUBERNETES_HOSTNAMES}  \
        -profile=kubernetes \
        controller-${instance}-csr.json | docker run -u $UID -v $PWD/certs:/certs -w /certs -i --entrypoint cfssljson $DOCKER_IMAGE -bare controller-${instance}
done
}

# Worker certificates
{
for instance in $(aws ec2 describe-instances --filters Name=instance-state-name,Values=running Name=tag:Name,Values=k8s-worker --query "Reservations[*].Instances[*].InstanceId" --output text); do
    cat > certs/worker-$instance-csr.json <<EOF
{
  "CN": "system:node:${instance}.k8s-worker.tsacha.fr",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "FR",
      "L": "Nantes",
      "O": "system:nodes",
      "OU": "Kubernetes Cluster",
      "ST": "Loire-Atlantique"
    }
  ]
}
EOF

    docker run -u $UID -v $PWD/certs:/certs -w /certs --entrypoint cfssl $DOCKER_IMAGE gencert \
        -ca=ca.pem \
        -ca-key=ca-key.pem \
        -config=ca-config.json \
        -hostname=${instance},${instance}.k8s-worker.tsacha.fr  \
        -profile=kubernetes \
        worker-${instance}-csr.json | docker run -u $UID -v $PWD/certs:/certs -w /certs -i --entrypoint cfssljson $DOCKER_IMAGE -bare worker-${instance}
done
}

# Controller Manager
{
cat > certs/kube-controller-manager-csr.json <<EOF
{
  "CN": "system:kube-controller-manager",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "FR",
      "L": "Nantes",
      "O": "system:kube-controller-manager",
      "OU": "Kubernetes Cluster",
      "ST": "Loire-Atlantique"
    }
  ]
}
EOF

docker run -u $UID -v $PWD/certs:/certs -w /certs --entrypoint cfssl $DOCKER_IMAGE gencert \
    -ca=ca.pem \
    -ca-key=ca-key.pem \
    -config=ca-config.json \
    -profile=kubernetes \
    kube-controller-manager-csr.json | docker run -u $UID -v $PWD/certs:/certs -w /certs -i --entrypoint cfssljson $DOCKER_IMAGE -bare kube-controller-manager
}

# Kube Proxy Client
{
cat > certs/kube-proxy-csr.json <<EOF
{
  "CN": "system:kube-proxy",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "FR",
      "L": "Nantes",
      "O": "system:node-proxier",
      "OU": "Kubernetes Cluster",
      "ST": "Loire-Atlantique"
    }
  ]
}
EOF

docker run -u $UID -v $PWD/certs:/certs -w /certs --entrypoint cfssl $DOCKER_IMAGE gencert \
    -ca=ca.pem \
    -ca-key=ca-key.pem \
    -config=ca-config.json \
    -profile=kubernetes \
    kube-proxy-csr.json | docker run -u $UID -v $PWD/certs:/certs -w /certs -i --entrypoint cfssljson $DOCKER_IMAGE -bare kube-proxy
}

# Scheduler Client
{
cat > certs/kube-scheduler-csr.json <<EOF
{
  "CN": "system:kube-scheduler",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "FR",
      "L": "Nantes",
      "O": "system:kube-scheduler",
      "OU": "Kubernetes Cluster",
      "ST": "Loire-Atlantique"
    }
  ]
}
EOF

docker run -u $UID -v $PWD/certs:/certs -w /certs --entrypoint cfssl $DOCKER_IMAGE gencert \
    -ca=ca.pem \
    -ca-key=ca-key.pem \
    -config=ca-config.json \
    -profile=kubernetes \
    kube-scheduler-csr.json | docker run -u $UID -v $PWD/certs:/certs -w /certs -i --entrypoint cfssljson $DOCKER_IMAGE -bare kube-scheduler
}

# Service Account
{
cat > certs/service-account-csr.json <<EOF
{
  "CN": "service-accounts",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "FR",
      "L": "Nantes",
      "O": "Sacha T.",
      "OU": "Kubernetes Cluster",
      "ST": "Loire-Atlantique"
    }
  ]
}
EOF

docker run -u $UID -v $PWD/certs:/certs -w /certs --entrypoint cfssl $DOCKER_IMAGE gencert \
    -ca=ca.pem \
    -ca-key=ca-key.pem \
    -config=ca-config.json \
    -profile=kubernetes \
    service-account-csr.json | docker run -u $UID -v $PWD/certs:/certs -w /certs -i --entrypoint cfssljson $DOCKER_IMAGE -bare service-account
}

# Admin
{
cat > certs/admin-csr.json <<EOF
{
  "CN": "admin",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "FR",
      "L": "Nantes",
      "O": "system:masters",
      "OU": "Kubernetes Cluster",
      "ST": "Loire-Atlantique"
    }
  ]
}
EOF

docker run -u $UID -v $PWD/certs:/certs -w /certs --entrypoint cfssl $DOCKER_IMAGE gencert \
    -ca=ca.pem \
    -ca-key=ca-key.pem \
    -config=ca-config.json \
    -profile=kubernetes \
    admin-csr.json | docker run -u $UID -v $PWD/certs:/certs -w /certs -i --entrypoint cfssljson $DOCKER_IMAGE -bare admin

}
