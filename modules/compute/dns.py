#!/usr/bin/env python3

import os
import json
import boto3
from botocore.config import Config
from botocore.exceptions import ParamValidationError


route53_client = boto3.client("route53")
ec2_client = boto3.client("ec2")
asg_client = boto3.client("autoscaling")

compute_name = os.environ["compute_name"]
zone_id = os.environ["zone_id"]
srv_records = json.loads(os.environ["srv_records"])
zone_name = route53_client.get_hosted_zone(Id=zone_id)["HostedZone"]["Name"]


def fetch_ec2_ips(asg_name, ec2_id):
    records = {}

    filters = [{"Name": "tag:aws:autoscaling:groupName", "Values": [asg_name]}]
    paginator = ec2_client.get_paginator("describe_instances")
    page_iterator = paginator.paginate(Filters=filters)
    ec2 = []
    for page in page_iterator:
        for i in page["Reservations"]:
            for instance in i["Instances"]:
                ec2.append(instance)

    for instance in ec2:
        if instance["InstanceId"] == ec2_id:
            return (
                instance["NetworkInterfaces"][0]["PrivateIpAddresses"][0][
                    "Association"
                ]["PublicIp"],
                instance["NetworkInterfaces"][0]["Ipv6Addresses"][0]["Ipv6Address"],
            )


def update_records(asg_name=None, compute_name=None, zone_id=None):
    changes = []
    ec2_asg = {}
    for ec2 in asg_client.describe_auto_scaling_groups(
        AutoScalingGroupNames=[asg_name]
    )["AutoScalingGroups"][0]["Instances"]:
        if ec2["LifecycleState"] == "InService":
            ec2_asg[ec2["InstanceId"]] = {}

    # If ASG is empty, flush records
    if not len(ec2_asg):
        delete_records(compute_name + "." + zone_name, zone_id=zone_id)
        for rec in srv_records:
            delete_records(
                "{}._{}.{}".format(rec["label"], rec["proto"], zone_name),
                zone_id=zone_id,
            )

    # <ec2_id>.<compute_name>.zone.tld IN A/AAAA <EC2 IP>
    for ec2_id, ec2_records in ec2_asg.items():
        ec2_records["ipv4"], ec2_records["ipv6"] = fetch_ec2_ips(asg_name, ec2_id)
        changes.append(
            {
                "Action": "UPSERT",
                "ResourceRecordSet": {
                    "Name": ec2_id + "." + compute_name + "." + zone_name,
                    "Type": "A",
                    "TTL": 300,
                    "ResourceRecords": [{"Value": ec2_records["ipv4"]}],
                },
            }
        )
        changes.append(
            {
                "Action": "UPSERT",
                "ResourceRecordSet": {
                    "Name": ec2_id + "." + compute_name + "." + zone_name,
                    "Type": "AAAA",
                    "TTL": 300,
                    "ResourceRecords": [{"Value": ec2_records["ipv6"]}],
                },
            }
        )

    # <compute_name>.zone.tld IN A/AAAA [<EC2 IP>, <EC2 IP>, ...]
    changes.append(
        {
            "Action": "UPSERT",
            "ResourceRecordSet": {
                "Name": compute_name + "." + zone_name,
                "Type": "A",
                "TTL": 300,
                "ResourceRecords": [
                    {"Value": ec2_records["ipv4"]} for _, ec2_records in ec2_asg.items()
                ],
            },
        }
    )
    changes.append(
        {
            "Action": "UPSERT",
            "ResourceRecordSet": {
                "Name": compute_name + "." + zone_name,
                "Type": "AAAA",
                "TTL": 300,
                "ResourceRecords": [
                    {"Value": ec2_records["ipv6"]} for _, ec2_records in ec2_asg.items()
                ],
            },
        }
    )

    # Append custom SRV records
    for rec in srv_records:
        changes.append(
            {
                "Action": "UPSERT",
                "ResourceRecordSet": {
                    "Name": "{}._{}.{}".format(rec["label"], rec["proto"], zone_name),
                    "Type": "SRV",
                    "TTL": 300,
                    "ResourceRecords": [
                        {
                            "Value": "0 0 {} {}.{}.{}".format(
                                rec["port"], ec2_id, compute_name, zone_name
                            )
                        }
                        for ec2_id, _ in ec2_asg.items()
                    ],
                },
            }
        )

    # Apply changes
    route53_client.change_resource_record_sets(
        HostedZoneId=zone_id,
        ChangeBatch={
            "Comment": "Update %s" % (compute_name),
            "Changes": changes,
        },
    )


def delete_records(record_name, zone_id=None):
    for record in route53_client.list_resource_record_sets(
        HostedZoneId=zone_id,
    )["ResourceRecordSets"]:
        if record["Name"] != record_name:
            continue

        route53_client.change_resource_record_sets(
            HostedZoneId=zone_id,
            ChangeBatch={
                "Comment": "Delete record %s" % (record_name),
                "Changes": [
                    {
                        "Action": "DELETE",
                        "ResourceRecordSet": {
                            "Name": record_name,
                            "Type": record["Type"],
                            "TTL": 300,
                            "ResourceRecords": record["ResourceRecords"],
                        },
                    }
                ],
            },
        )


def lambda_handler(event, context):
    print(event)

    asg_name = event["detail"]["AutoScalingGroupName"]
    ec2_id = event["detail"]["EC2InstanceId"]

    try:
        update_records(
            asg_name=asg_name,
            compute_name=compute_name,
            zone_id=zone_id,
        )
    except ParamValidationError:
        pass

    if event["detail-type"] == "EC2 Instance Terminate Successful":
        delete_records(
            ec2_id + "." + compute_name + "." + zone_name,
            zone_id=zone_id,
        )
