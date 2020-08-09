#!/usr/bin/env bash
set -euo pipefail

i=1
for instance in $(aws ec2 describe-instances --filters Name=instance-state-name,Values=running Name=tag:Name,Values=k8s-worker --query "Reservations[*].Instances[*].[NetworkInterfaces[0].Ipv6Addresses[0].Ipv6Address][*][]" --output text); do
    echo $instance

    ssh ubuntu@$instance -i ~/.ssh/legacy -o StrictHostKeyChecking=no "sudo su -c 'systemctl kill kubelet.service kube-proxy.service | true'"

    INSTANCE_ID=$(ssh ubuntu@$instance -i ~/.ssh/legacy -o StrictHostKeyChecking=no ec2metadata --instance-id)
    PUBLIC_IP=$(ssh ubuntu@$instance -i ~/.ssh/legacy -o StrictHostKeyChecking=no ec2metadata --public-ipv4)
    POD_CIDR="10.200.$i.0/24"

    rsync --rsync-path="sudo rsync" -e "ssh -i /home/sacha/.ssh/legacy -o StrictHostKeyChecking=no" certs/ca.pem ubuntu@\[$instance\]:/var/lib/kubernetes
    rsync --rsync-path="sudo rsync" -e "ssh -i /home/sacha/.ssh/legacy -o StrictHostKeyChecking=no" certs/ca-key.pem ubuntu@\[$instance\]:/var/lib/kubernetes

    rsync --rsync-path="sudo rsync" -e "ssh -i /home/sacha/.ssh/legacy -o StrictHostKeyChecking=no" certs/worker-$INSTANCE_ID.pem ubuntu@\[$instance\]:/var/lib/kubelet/pki/kubelet.crt
    rsync --rsync-path="sudo rsync" -e "ssh -i /home/sacha/.ssh/legacy -o StrictHostKeyChecking=no" certs/worker-$INSTANCE_ID-key.pem ubuntu@\[$instance\]:/var/lib/kubelet/pki/kubelet.key

    rsync --rsync-path="sudo rsync" -e "ssh -i /home/sacha/.ssh/legacy -o StrictHostKeyChecking=no" certs/worker-$INSTANCE_ID.kubeconfig ubuntu@\[$instance\]:/var/lib/kubelet/worker.kubeconfig
    rsync --rsync-path="sudo rsync" -e "ssh -i /home/sacha/.ssh/legacy -o StrictHostKeyChecking=no" certs/kube-proxy.kubeconfig ubuntu@\[$instance\]:/var/lib/kube-proxy/kubeconfig

    ssh ubuntu@$instance -i ~/.ssh/legacy -o StrictHostKeyChecking=no "sudo su -c 'sed \"s#{POD_CIDR}#${POD_CIDR}#g\" /run/cloud-init/kubelet.yaml > /var/lib/kubelet/config.yaml'"
    ssh ubuntu@$instance -i ~/.ssh/legacy -o StrictHostKeyChecking=no "sudo su -c 'sed \"s#{POD_CIDR}#${POD_CIDR}#g\" /run/cloud-init/10-bridge.conf > /etc/cni/net.d/10-bridge.conf'"
    ssh ubuntu@$instance -i ~/.ssh/legacy -o StrictHostKeyChecking=no "sudo su -c 'sed \"s#{INSTANCE_ID}#${INSTANCE_ID}#g\" /run/cloud-init/10-kubelet.conf > /etc/systemd/system/kubelet.service.d/10-kubelet.conf'"
    ssh ubuntu@$instance -i ~/.ssh/legacy -o StrictHostKeyChecking=no "sudo su -c 'sed \"s#{INSTANCE_ID}#${INSTANCE_ID}#g\" /run/cloud-init/kube-proxy.service > /etc/systemd/system/kube-proxy.service'"

    ssh ubuntu@$instance -i ~/.ssh/legacy -o StrictHostKeyChecking=no "sudo su -c 'chown root:root /var/lib/kubernetes/*.pem'"

    ssh ubuntu@$instance -i ~/.ssh/legacy -o StrictHostKeyChecking=no "sudo su -c 'systemctl daemon-reload'"
    ssh ubuntu@$instance -i ~/.ssh/legacy -o StrictHostKeyChecking=no "sudo su -c 'systemctl start --no-block kubelet.service kube-proxy.service'"

    i=$((i+1))
done
