#!/usr/bin/env bash
set -euo pipefail

i=1
for instance in $(aws ec2 describe-instances --filters Name=instance-state-name,Values=running Name=tag:Name,Values=k8s-worker --query "Reservations[*].Instances[*].[NetworkInterfaces[0].Ipv6Addresses[0].Ipv6Address][*][]" --output text); do
    echo $instance

    INSTANCE_ID=$(ssh ubuntu@$instance -i ~/.ssh/legacy -o StrictHostKeyChecking=no ec2metadata --instance-id)
    PUBLIC_IP=$(ssh ubuntu@$instance -i ~/.ssh/legacy -o StrictHostKeyChecking=no ec2metadata --public-ipv4)
    POD_CIDR="10.200.$i.0/24"


    aws ec2 modify-instance-attribute --instance-id ${INSTANCE_ID} --no-source-dest-check
    aws ec2 create-route \
        --route-table-id "$(aws ec2 describe-route-tables --filters Name=tag:Name,Values=public-routetable | jq -r '.[][].RouteTableId')" \
        --destination-cidr-block "${POD_CIDR}" \
        --instance-id "${INSTANCE_ID}"

    i=$((i+1))
done
