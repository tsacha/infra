# Infra

Experimental lab for infrastructure projects.
Mainly based on AWS.

## bootstrap-backend subfolder

Provision Terraform dependencies :

- DynamoDB and S3 backend

## Billing module

Just a reminder.

## Compute module

Shared EC2 configuration across my different projects.
Usually a quite-aggressive ASG configuration using spot instances.

Variables:

- `name` : Group name used everywhere

- `asg_size` : number of instances to launch
- `ebs_size` : disk size (default: 30GB)
- `spot` : create AWS spot instances (default: false)
- `arch`: `amd64` or `arm64` (default: `arm64`). 
- `type`: EC2 instance type, `t4g` are not available on `eu-west-3` :(

- `cloud_config`: Cloud-config template
- `public_key`: SSH key
- `instance_profile_policy`: IAM instance profile
- `zone_id`: Route53 zone ID
- `srv_records`: SRV records if necessary. ETCD Example:

```
  srv_records = [
    {"label": "_etcd-client-ssl", "port": 2379, "proto": "tcp"},
    {"label": "_etcd-server-ssl", "port": 2380, "proto": "tcp"},
  ]
```
### DNS

ALB is really expensive, so I’m trying to live without it.
A lambda function is deployed to creates some DNS records:

```
<instance_id>.<name>.zone.tld. IN A/AAAA <IP>

<name>.zone.tld.               IN A/AAAA <IP>
                                         <IP>
                                         ...
                             

# If SRV record variable is filled:
<srv_label>._<proto>.zone.tld. IN SRV 0 0 <port> <instance_id>.<name>.zone.tld.
                                                 <instance_id>.<name>.zone.tld.
                                                 ...
```
 
## KKKT

- Dedicated servers for games.
- Discord Bot

For Valheim, the cloud-init quick-and-dirty script fetch its data and configuration from my S3 bucket. 
I’m using this Docker image : https://github.com/CM2Walki/Valheim ♥


```yaml
version: "3.3"
services:
  valheim:
    image: cm2network/valheim
    network_mode: host
    ports:
      - "2456:2456/udp"
      - "2456:2456/tcp"
      - "2467:2467/tcp"      
    volumes:
      - valheim-data:/home/steam/valheim-dedicated
      - steamcmd:/home/steam/steamcmd
    environment:
      - SERVER_PW=blabla
      - SERVER_NAME="blabla"
      - SERVER_WORLD_NAME=blabla
volumes:
  valheim-data:
  steamcmd:

```

### k8s-hard

Experimentation to launch K8S from scratch on AWS.

A mix of this:

- https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/setup-ha-etcd-with-kubeadm/
- https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/high-availability/
- https://github.com/kelseyhightower/kubernetes-the-hard-way
- https://github.com/prabhatsharma/kubernetes-the-hard-way-aws

#### Post-install:

When Terraform is deployed (with `asg_size` > 0):

- Launch in order scripts in `scripts/k8s-hard/`
- Apply in order with kubectl YAML files stored in `scripts/kube/`
- Install CoreDNS `kubectl apply -f https://storage.googleapis.com/kubernetes-the-hard-way/coredns-1.8.yaml`

