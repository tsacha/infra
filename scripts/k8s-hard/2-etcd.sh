#!/usr/bin/env bash
set -euo pipefail
for instance in $(aws ec2 describe-instances --filters Name=instance-state-name,Values=running Name=tag:Name,Values=etcd-cluster --query "Reservations[*].Instances[*].[NetworkInterfaces[0].Ipv6Addresses[0].Ipv6Address][*][]" --output text); do
    echo $instance
    ssh ubuntu@$instance -i ~/.ssh/legacy -o StrictHostKeyChecking=no "sudo su -c 'systemctl kill --no-block etcd; rm -Rf /var/lib/etcd/*'"
    ssh ubuntu@$instance -i ~/.ssh/legacy -o StrictHostKeyChecking=no "sudo su -c 'rm -Rf /certs; mkdir /certs'"
    INSTANCE_ID=$(ssh ubuntu@$instance -i ~/.ssh/legacy -o StrictHostKeyChecking=no ec2metadata --instance-id)
    rsync --rsync-path="sudo rsync" -e "ssh -i /home/sacha/.ssh/legacy -o StrictHostKeyChecking=no" certs/ca.pem ubuntu@\[$instance\]:/certs
    rsync --rsync-path="sudo rsync" -e "ssh -i /home/sacha/.ssh/legacy -o StrictHostKeyChecking=no" certs/etcd-$INSTANCE_ID.pem ubuntu@\[$instance\]:/certs
    rsync --rsync-path="sudo rsync" -e "ssh -i /home/sacha/.ssh/legacy -o StrictHostKeyChecking=no" certs/etcd-$INSTANCE_ID-key.pem ubuntu@\[$instance\]:/certs
    ssh ubuntu@$instance -i ~/.ssh/legacy -o StrictHostKeyChecking=no "sudo su -c 'chown etcd:etcd /certs/etcd-*.pem'"
    ssh ubuntu@$instance -i ~/.ssh/legacy -o StrictHostKeyChecking=no "sudo su -c 'systemctl start --no-block etcd'"
done
