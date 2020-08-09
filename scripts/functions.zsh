export AWS_DEFAULT_REGION=eu-west-3
export AWS_DEFAULT_PROFILE=sacha
function quickconnect() {
	n=$(($2 - 1))
	ip=$(aws ec2 describe-instances --filters Name=instance-state-name,Values=running Name=tag:Name,Values=$1 --query "Reservations[*].Instances[*].[LaunchTime,NetworkInterfaces[0].Ipv6Addresses[0].Ipv6Address] | [] | sort_by(@, &[0]) | [$n][1]" --output text)
	ssh ubuntu@$ip -i ~/.ssh/legacy -o StrictHostKeyChecking=no
}
