#!/bin/bash

stack_name=lukasz-budnik-test-1
source_region=ap-northeast-1
target_region=ap-northeast-2

function create_bucket {
  region=$1

  aws cloudformation create-stack --region $region \
    --stack-name $stack_name \
    --template-body file://s3-bucket.template.yml \
    --parameters ParameterKey=BucketNamePrefix,ParameterValue=$stack_name

    aws cloudformation wait stack-create-complete --region $region --stack-name $stack_name

    aws cloudformation describe-stacks --region $region --stack-name $stack_name
}

function update_bucket {
  source_region=$1
  target_region=$2
  role_arn=$3

  change_set=$(aws cloudformation create-change-set --region $source_region \
    --stack-name $stack_name \
    --change-set-name "update-bucket-add-replication" \
    --template-body file://s3-bucket-with-replication.template.yml \
    --parameters \
    ParameterKey=BucketNamePrefix,ParameterValue=$stack_name \
    ParameterKey=ReplicationRoleArn,ParameterValue=$role_arn \
    ParameterKey=TargetRegion,ParameterValue=$target_region)

    sleep 10

    change_set_arn=$(echo $change_set | jq -r '.Id')

    aws cloudformation execute-change-set --region $source_region \
      --change-set-name $change_set_arn

    sleep 10

    aws cloudformation wait stack-update-complete --region $source_region --stack-name $stack_name

    aws cloudformation describe-stacks --region $source_region --stack-name $stack_name
}


echo "1. create bucket 1 in $source_region"

create_bucket $source_region

echo "2. create bucket 2 in $target_region"

create_bucket $target_region

echo "3. setup replication role"

aws cloudformation create-stack --region $source_region \
  --stack-name "$stack_name-replication-role" \
  --capabilities CAPABILITY_IAM \
  --template-body file://s3-replication.template.yml \
  --parameters \
  ParameterKey=BucketNamePrefix,ParameterValue=$stack_name \
  ParameterKey=SourceRegion,ParameterValue=$source_region \
  ParameterKey=TargetRegion,ParameterValue=$target_region

aws cloudformation wait stack-create-complete --region $source_region --stack-name "$stack_name-replication-role"

stack_info=$(aws cloudformation describe-stacks --region $source_region --stack-name "$stack_name-replication-role")

role_arn=$(echo $stack_info | jq -r '.Stacks[0].Outputs[0].OutputValue')

echo "4. setup $source_region -> $target_region replication"

update_bucket $source_region $target_region $role_arn

echo "5. setup $target_region -> $source_region replication"

update_bucket $target_region $source_region $role_arn
