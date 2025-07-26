#!/bin/bash

echo "=== View Logs ==="
echo "aws logs tail /ecs/vrush-coaching18 --follow --region ap-southeast-1"

echo -e "\n=== Service Status ==="
aws ecs describe-services --cluster vrush-coaching18-cluster --services vrush-coaching18-s3-service vrush-coaching18-sqs-service --region ap-southeast-1 --query 'services[*].{Name:serviceName,Status:status,Running:runningCount,Desired:desiredCount}' --output table