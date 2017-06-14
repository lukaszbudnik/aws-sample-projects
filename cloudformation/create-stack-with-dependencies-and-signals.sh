#!/bin/bash

networkig_stack_name=$1

if [ -z "$networkig_stack_name" ]; then
  >&2 echo "Please provide CloudFormation networking stack name from which new stack will import bastion IP"
  exit 1
fi

stack_prefix="StackWithDependencies"
stack_version=$(date +'%Y%m%d%H%M')
stack_name="$stack_prefix$stack_version"

region=eu-central-1

db_name=test
db_user=user
db_password=MusiBycTrudne01

aws cloudformation create-stack --region $region \
  --stack-name $stack_name \
  --template-body file://web-server-with-database.template \
  --parameters \
  ParameterKey=NetworkingStackName,ParameterValue=$networkig_stack_name \
  ParameterKey=DBUser,ParameterValue=$db_user \
  ParameterKey=DBPassword,ParameterValue=$db_password \
  ParameterKey=DBName,ParameterValue=$db_name
