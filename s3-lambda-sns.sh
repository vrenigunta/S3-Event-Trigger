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
bucket_name="s3-newbucket-vr1"
lambdaname="s3-lambdafunction"
snsname="s3-lambda-sns"
rolename="role-eventtrigger"
emailaddress="reniguntavinutha@gmail.com"



# Create and Assign all the IAM roles for s3-lambda-sns event trigger
role=$(aws iam create-role --role-name "$rolename" --assume-role-policy-document '{
	"Version": "2012-10-17",
	"Statement": [{
		"Action": "sts:AssumeRole",
		"Effect": "Allow",
		"Principal": {
			"Service": ["lambda.amazonaws.com","s3.amazonaws.com","sns.amazonaws.com"]}
}]
}')

# Extract the role ARN
role_arn=$(echo "$role" | jq -r '.Role.Arn')
echo "Role ARN: $role_arn"


# Attach Role Policy
aws iam attach-role-policy --role-name $rolename --policy-arn arn:aws:iam::aws:policy/AWSLambda_FullAccess
aws iam attach-role-policy --role-name $rolename --policy-arn arn:aws:iam::aws:policy/AmazonSNSFullAccess

# Create S3 Bucket
bucket_output=$(aws s3api create-bucket --bucket "$bucket_name" --region "$aws_region")
echo "Bucket is created: $bucket_output"

# Create a zip file to upload the lambda function
zip -r s3-lambdafunction.zip ./s3-lambdafunction

sleep 5

# Create a Lambda Function
aws lambda create-function \
--region "$aws_region" \
--function-name s3-lambdafunction \
--runtime "python3.8" \
--handler "s3-lambdafunction/s3-lambdafunction.lambda_handler" \
--memory-size 128 \
--timeout 30 \
--role "arn:aws:iam::$account_id:role/$rolename" \
--zip-file "fileb://./s3-lambdafunction.zip"

#Add Permission to S3 bucket to invoke Lambda
aws lambda add-permission \
--function-name "$lambdaname" \
--region "$aws_region" \
--statement-id "s3-lambda-permission" \
--action "lambda:InvokeFunction" \
--principal s3.amazonaws.com \
--source-arn "arn:aws:s3:::$bucket_name"

# Create S3 event triger
LambdaFunctionArn="arn:aws:lambda:$aws_region:$account_id:function:$lambdaname"
aws s3api put-bucket-notification-configuration \
--region "$aws_region" \
--bucket "$bucket_name" \
--notification-configuration '{
	"LambdaFunctionConfigurations": [{
	"LambdaFunctionArn": "'"$LambdaFunctionArn"'",
	"Events": ["s3:ObjectCreated:*"]
}]
}'

# Create an SNS and save the arn to a variable
sns_arn=$(aws sns  create-topic --name "$snsname" --region "$aws_region" --output json | jq -r '.TopicArn')
echo "SNS Topic ARN: $sns_arn"

# Add SNS publish permission to lambda
aws sns subscribe \
--topic-arn "$sns_arn" \
--protocol email \
--notification-endpoint "$emailaddress"

#Publish SNS
aws sns publish \
--topic-arn "$sns_arn" \
--subject "Object Created in S3 Bucket" \
--message "Hello, Event is triggered automatically  from S3 via Lambda"


