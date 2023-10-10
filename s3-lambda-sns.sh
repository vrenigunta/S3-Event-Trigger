#!/bin/bash

#####################
# Author: Vinutha 
# Date: 10-oct-2023
# Version: v1
# Project: S3-Lambda-SNS Event trigger with IAM roles.
####################

# To run the script in debug mode
set -x

# Storing the AWS account ID in a variable
account_id=$(aws sts get-caller-identity --query 'Account' --output text)

echo "AWS Account ID is: $account_id"

# Storing variables 
aws_region="us-east-1"
bucketname="s3-bucket"
lambdaname="lambda-function"
snsname="s3-lambda-sns"
rolename="role-eventtrigger"
emailaddress="reniguntavinutha@gmail.com"

# Create and Assign all the IAM roles for s3-lambda-sns event trigger
role=$(aws iam create-role --role-name $rolename --assume-role-policy-document '{
	"Version": "2012-10-17",
	"Statement": [{
		"Action": "sts:AssumeRole",
		"Effect": "Allow",
		"Principal": {
			"Service": ["lambda.amazonaws.com","s3.amazonaws.com","sns.amazonaws.com"]}
}]
}')

# Attach Role Policy
aws iam attach-role-policy --role-name $rolename --policy-arn arn:aws:iam::aws:policy/AWSLambda_FullAccess
aws iam attach-role-policy --role-name $rolename --policy-arn arn:aws:iam::aws:policy/AmazonSNSFullAccess

# Create S3 Bucket
bucket_output=$(aws s3api create-bucket --bucket $bucketname --region $aws_region)
echo "Bucket is created: $bucket_output

# Create a zip file to upload the lambda function
zip -r s3-lambdafunction.zip ./s3-lambdafunction

sleep 5

# Create a Lambda Function
aws lambda create-function \
--region $aws_region
--function-name $lambdaname \
--runtime "python3.8" \
--handler "lambdafunction/lambdafunction.lambda_handler" \
--memory-size 128 \
--timeout 30 \
--role "arn:aws:iam::$account_id:role/$rolename" \
--zip file "fileb://s3-lambdafunction.zip"

#Add Permission to S3 bucket to invoke Lambda
aws lambda add-permission
--function-name $lambdaname \
--statement-d "s3-lambda-permission" \
--action "lambda:InvokeFunction" \
--principal s3.amazonaws.com \
--source-arn "arn:aws:s3:::$bucketname"

# Create S3 event triger
LambdaFunctionArn="arn:aws:lambda:$aws_region:$account_id:function:$lambdaname"
aws s3api put-bucket-notification-configuration \
--region $aws_region \
--bucket $bucketname \
--notification-configuration '{
	TopicConfiguration": [{
	"TopicArn": "'"$LambdaFunctionArn"'"
	"Events": [s3:objectCreated:*"]
}]
}'

# Create an SNS and save the arn to a variable
sns_arn=$(aws sns create-topic --name $snsname --output json |jq -r '.TopicArn')
ech "SNS Topic ARN: $sns_arn"

# Add SNS publish permission to lambda
aws sns subscribe \
--topic-arn "$sns_arn" \
--protocol email \
--notification-endpoint "$emailaddress

#Publish SNS
aws sns publish \
--topic-arn "$sns_arn" \
--subject "Object Created in S# Bucket" \
--message "Hello, Event is triggered automatically  from S3 via Lambda"


