#!/bin/bash

keypair_name=$1
stack_name=$2

if [ -z "$keypair_name" ]; then
  >&2 echo "Please provide your EC2 key pair name as first argument"
  exit 1
fi

if [ -z "$stack_name" ]; then
  >&2 echo "Please provide CloudFormation stack name as second argument"
  exit 1
fi

ip=$(curl -s checkip.amazonaws.com)

change_set=$(aws cloudformation create-change-set --region eu-central-1 \
  --stack-name $stack_name --change-set-name ec2-changes \
  --parameters ParameterKey=KeyPairName,ParameterValue=$keypair_name ParameterKey=ExternalIP,ParameterValue=$ip \
  --template-body file://networking-test-vpc-ec2-changes.template)

echo $change_set

echo "Give AWS CloudFormation some time to prepare the change sets. Sleep for 20 seconds"
sleep 20

change_set_arn=$(echo $change_set | jq -r '.Id')

change_set_details=$(aws cloudformation describe-change-set --region eu-central-1 \
  --change-set-name $change_set_arn)

status=$(echo $change_set_details | jq -r '.Status')
execution_status=$(echo $change_set_details | jq -r '.ExecutionStatus')

if [ "$status" == "CREATE_COMPLETE" ] && [ "$execution_status" == "AVAILABLE" ]; then
  echo "Change set looks good. Execute it."
  aws cloudformation execute-change-set --region eu-central-1 \
    --change-set-name $change_set_arn
  sleep 10
  echo "Wait for stack to update."
  aws cloudformation wait stack-update-complete --region eu-central-1 \
    --stack-name $stack_name
  aws cloudformation describe-stacks --region eu-central-1 --stack-name $stack_name
fi
