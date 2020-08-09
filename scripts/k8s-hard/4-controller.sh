#!/usr/bin/env bash
set -euo pipefail

ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)
ETCD_SERVERS=https://$(aws ec2 describe-instances --filters Name=instance-state-name,Values=running Name=tag:Name,Values=etcd-cluster --query  "Reservations[*].Instances[].InstanceId"  | jq -r '.|join(".etcd-cluster.tsacha.fr:2379,https://")')".etcd-cluster.tsacha.fr:2379"
APISERVER_COUNT=$(aws ec2 describe-instances --filters Name=instance-state-name,Values=running Name=tag:Name,Values=k8s-controller --query  "Reservations[*].Instances[*].InstanceId" --output text | wc -l)

for instance in $(aws ec2 describe-instances --filters Name=instance-state-name,Values=running Name=tag:Name,Values=k8s-controller --query "Reservations[*].Instances[*].[NetworkInterfaces[0].Ipv6Addresses[0].Ipv6Address][*][]" --output text); do
    echo $instance

    ssh ubuntu@$instance -i ~/.ssh/legacy -o StrictHostKeyChecking=no "sudo su -c 'systemctl kill kube-apiserver.service  kube-controller-manager.service kube-scheduler.service | true'"

    INSTANCE_ID=$(ssh ubuntu@$instance -i ~/.ssh/legacy -o StrictHostKeyChecking=no ec2metadata --instance-id)
    PUBLIC_IP=$(ssh ubuntu@$instance -i ~/.ssh/legacy -o StrictHostKeyChecking=no ec2metadata --public-ipv4)
    rsync --rsync-path="sudo rsync" -e "ssh -i /home/sacha/.ssh/legacy -o StrictHostKeyChecking=no" certs/ca.pem ubuntu@\[$instance\]:/var/lib/kubernetes
    rsync --rsync-path="sudo rsync" -e "ssh -i /home/sacha/.ssh/legacy -o StrictHostKeyChecking=no" certs/ca-key.pem ubuntu@\[$instance\]:/var/lib/kubernetes

    rsync --rsync-path="sudo rsync" -e "ssh -i /home/sacha/.ssh/legacy -o StrictHostKeyChecking=no" certs/service-account.pem ubuntu@\[$instance\]:/var/lib/kubernetes
    rsync --rsync-path="sudo rsync" -e "ssh -i /home/sacha/.ssh/legacy -o StrictHostKeyChecking=no" certs/service-account-key.pem ubuntu@\[$instance\]:/var/lib/kubernetes

    rsync --rsync-path="sudo rsync" -e "ssh -i /home/sacha/.ssh/legacy -o StrictHostKeyChecking=no" certs/kube-proxy.pem ubuntu@\[$instance\]:/var/lib/kubernetes
    rsync --rsync-path="sudo rsync" -e "ssh -i /home/sacha/.ssh/legacy -o StrictHostKeyChecking=no" certs/kube-proxy-key.pem ubuntu@\[$instance\]:/var/lib/kubernetes

    rsync --rsync-path="sudo rsync" -e "ssh -i /home/sacha/.ssh/legacy -o StrictHostKeyChecking=no" certs/kube-scheduler.pem ubuntu@\[$instance\]:/var/lib/kubernetes
    rsync --rsync-path="sudo rsync" -e "ssh -i /home/sacha/.ssh/legacy -o StrictHostKeyChecking=no" certs/kube-scheduler-key.pem ubuntu@\[$instance\]:/var/lib/kubernetes

    rsync --rsync-path="sudo rsync" -e "ssh -i /home/sacha/.ssh/legacy -o StrictHostKeyChecking=no" certs/kube-controller-manager.pem ubuntu@\[$instance\]:/var/lib/kubernetes
    rsync --rsync-path="sudo rsync" -e "ssh -i /home/sacha/.ssh/legacy -o StrictHostKeyChecking=no" certs/kube-controller-manager-key.pem ubuntu@\[$instance\]:/var/lib/kubernetes

    rsync --rsync-path="sudo rsync" -e "ssh -i /home/sacha/.ssh/legacy -o StrictHostKeyChecking=no" certs/controller-$INSTANCE_ID.pem ubuntu@\[$instance\]:/var/lib/kubernetes
    rsync --rsync-path="sudo rsync" -e "ssh -i /home/sacha/.ssh/legacy -o StrictHostKeyChecking=no" certs/controller-$INSTANCE_ID-key.pem ubuntu@\[$instance\]:/var/lib/kubernetes

    rsync --rsync-path="sudo rsync" -e "ssh -i /home/sacha/.ssh/legacy -o StrictHostKeyChecking=no" certs/kube-controller-manager.kubeconfig ubuntu@\[$instance\]:/var/lib/kubernetes
    rsync --rsync-path="sudo rsync" -e "ssh -i /home/sacha/.ssh/legacy -o StrictHostKeyChecking=no" certs/kube-scheduler.kubeconfig ubuntu@\[$instance\]:/var/lib/kubernetes
    rsync --rsync-path="sudo rsync" -e "ssh -i /home/sacha/.ssh/legacy -o StrictHostKeyChecking=no" certs/admin.kubeconfig ubuntu@\[$instance\]:/var/lib/kubernetes

    ssh ubuntu@$instance -i ~/.ssh/legacy -o StrictHostKeyChecking=no "sudo su -c 'chown root:root /var/lib/kubernetes/*.pem'"

    ssh ubuntu@$instance -i ~/.ssh/legacy -o StrictHostKeyChecking=no "sudo su -c 'sed \"s#{ENCRYPTION_KEY}#${ENCRYPTION_KEY}#g\" /run/cloud-init/encryption-config.yaml > /var/lib/kubernetes/encryption-config.yaml'"
    ssh ubuntu@$instance -i ~/.ssh/legacy -o StrictHostKeyChecking=no "sudo su -c 'sed \"s#{INSTANCE_ID}#${INSTANCE_ID}#g\" /run/cloud-init/kube-apiserver.service > /etc/systemd/system/kube-apiserver.service'"
    ssh ubuntu@$instance -i ~/.ssh/legacy -o StrictHostKeyChecking=no "sudo su -c 'sed -i \"s#{PUBLIC_IP}#${PUBLIC_IP}#g\" /etc/systemd/system/kube-apiserver.service'"
    ssh ubuntu@$instance -i ~/.ssh/legacy -o StrictHostKeyChecking=no "sudo su -c 'sed -i \"s#{APISERVER_COUNT}#${APISERVER_COUNT}#g\" /etc/systemd/system/kube-apiserver.service'"
    ssh ubuntu@$instance -i ~/.ssh/legacy -o StrictHostKeyChecking=no "sudo su -c 'sed -i \"s#{ETCD_SERVERS}#${ETCD_SERVERS}#g\" /etc/systemd/system/kube-apiserver.service'"

    ssh ubuntu@$instance -i ~/.ssh/legacy -o StrictHostKeyChecking=no "sudo su -c 'systemctl daemon-reload'"
    ssh ubuntu@$instance -i ~/.ssh/legacy -o StrictHostKeyChecking=no "sudo su -c 'systemctl restart --no-block kube-apiserver.service  kube-controller-manager.service kube-scheduler.service'"
done
