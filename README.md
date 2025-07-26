To test the services
Run the test_services.sh to ensure that the services are running and note the public ip.

For testing S3 service
http://s3_service_public_ip/upload

After uploading check the S3 bucket to see if the file exists.

For testing SQS service
http://sqs_service_public_ip/send

After sending the message check the message in the SQS queue under "send & receive" and poll new messages.
