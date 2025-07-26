#!/bin/bash

# Set variables
CLUSTER_NAME="vrush-coaching18-cluster"
REGION="ap-southeast-1"

echo "=== ECS Service Status ==="
aws ecs describe-services --cluster $CLUSTER_NAME --services vrush-coaching18-s3-service vrush-coaching18-sqs-service --region $REGION --query 'services[*].{Name:serviceName,Status:status,Running:runningCount,Desired:desiredCount}' --output table

echo -e "\n=== Getting Task Public IPs ==="
# Get S3 service task IP
S3_TASK_ARN=$(aws ecs list-tasks --cluster $CLUSTER_NAME --service-name vrush-coaching18-s3-service --region $REGION --query 'taskArns[0]' --output text)
if [ "$S3_TASK_ARN" != "None" ]; then
    S3_ENI=$(aws ecs describe-tasks --cluster $CLUSTER_NAME --tasks $S3_TASK_ARN --region $REGION --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' --output text)
    S3_IP=$(aws ec2 describe-network-interfaces --network-interface-ids $S3_ENI --region $REGION --query 'NetworkInterfaces[0].Association.PublicIp' --output text)
    echo "S3 Service IP: $S3_IP:5001"
fi

# Get SQS service task IP
SQS_TASK_ARN=$(aws ecs list-tasks --cluster $CLUSTER_NAME --service-name vrush-coaching18-sqs-service --region $REGION --query 'taskArns[0]' --output text)
if [ "$SQS_TASK_ARN" != "None" ]; then
    SQS_ENI=$(aws ecs describe-tasks --cluster $CLUSTER_NAME --tasks $SQS_TASK_ARN --region $REGION --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' --output text)
    SQS_IP=$(aws ec2 describe-network-interfaces --network-interface-ids $SQS_ENI --region $REGION --query 'NetworkInterfaces[0].Association.PublicIp' --output text)
    echo "SQS Service IP: $SQS_IP:5002"
fi

