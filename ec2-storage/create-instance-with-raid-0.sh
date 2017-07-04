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

aws cloudformation create-stack --stack-name $stack_name \
  --region $region \
  --template-body file://ec2-ebs-raid-0.template.yml \
  --parameters \
    ParameterKey=KeyPairName,ParameterValue=$keypair_name \
    ParameterKey=ExternalIP,ParameterValue=$external_ip \
    ParameterKey=InstanceType,ParameterValue=$instance_type

echo "Waiting for AWS CloudFormation to create the stack."
sleep 20

aws cloudformation wait stack-create-complete --region $region \
  --stack-name $stack_name

aws cloudformation describe-stacks --region $region --stack-name $stack_name
