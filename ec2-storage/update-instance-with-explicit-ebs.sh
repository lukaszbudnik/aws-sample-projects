#!/bin/bash

if [ -z "$1" ] || [ -z "$2" ]; then
  >&2 echo "Usage: $0 keypair_name stack_name"
  exit 1
fi

# from params
keypair_name=$1
stack_name=$2

# dynamic
external_ip=$(curl --silent checkip.amazonaws.com)

# hardcoded, change if required
region=eu-central-1
instance_type=m4.large

change_set=$(aws cloudformation create-change-set --stack-name $stack_name \
  --region $region \
  --change-set-name ebs-extend \
  --template-body file://ec2-ebs.template.yml \
  --parameters \
    ParameterKey=KeyPairName,ParameterValue=$keypair_name \
    ParameterKey=ExternalIP,ParameterValue=$external_ip \
    ParameterKey=InstanceType,ParameterValue=$instance_type)

echo "$change_set"

echo "Giving AWS CloudFormation some time to prepare the change sets."
sleep 20

change_set_arn=$(echo $change_set | jq -r '.Id')
aws cloudformation execute-change-set --region $region --change-set-name $change_set_arn

echo "Waiting for AWS CloudFormation to update the stack."
sleep 20

aws cloudformation wait stack-update-complete --region $region \
  --stack-name $stack_name

aws cloudformation describe-stacks --region $region --stack-name $stack_name
