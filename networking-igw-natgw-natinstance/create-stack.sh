#!/bin/bash

stack_prefix="VPCNetworkingTest"
stack_version=$(date +'%Y%m%d%H%M')
stack_name="$stack_prefix$stack_version"

ip=$(curl -s checkip.amazonaws.com)
keypair_name=lukasz-budnik

# well yes the template has hardcoded references to Frankfurt region...
aws cloudformation create-stack --region eu-central-1 --stack-name $stack_name \
  --parameters ParameterKey=KeyPairName,ParameterValue=$keypair_name ParameterKey=ExternalIP,ParameterValue=$ip \
  --template-body file://networking-test-vpc.template

aws cloudformation wait stack-create-complete --region eu-central-1 --stack-name $stack_name

aws cloudformation describe-stacks --region eu-central-1 --stack-name $stack_name
