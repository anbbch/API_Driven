import boto3
import json
import os

def lambda_handler(event, context):
    action = event.get("queryStringParameters", {}).get("action", "status")
    instance_id = os.environ.get("INSTANCE_ID")

    ec2 = boto3.client(
        "ec2",
        region_name="us-east-1",
        endpoint_url="http://172.17.0.1:4566",
        aws_access_key_id="test",
        aws_secret_access_key="test"
    )

    if action == "start":
        ec2.start_instances(InstanceIds=[instance_id])
        message = "Instance " + instance_id + " demarree"
    elif action == "stop":
        ec2.stop_instances(InstanceIds=[instance_id])
        message = "Instance " + instance_id + " stoppee"
    else:
        result = ec2.describe_instances(InstanceIds=[instance_id])
        state = result["Reservations"][0]["Instances"][0]["State"]["Name"]
        message = "Instance " + instance_id + " - Etat : " + state

    return {
        "statusCode": 200,
        "body": json.dumps({"message": message})
    }
