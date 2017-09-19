#!/bin/bash

stack_name=lukasz-budnik-test-1
source_region=ap-northeast-1
target_region=ap-northeast-2

echo "1. Upload to $source_region"
aws s3 cp setup-crr.sh s3://$stack_name-$source_region

sleep 5

echo "2.a. Read from $source_region - expected status COMPLETED"
aws s3api head-object --bucket $stack_name-$source_region --key setup-crr.sh
echo "2.b. Read from $target_region - expected status REPLICA"
aws s3api head-object --bucket $stack_name-$target_region --key setup-crr.sh

echo "3. Upload to $target_region"
aws s3 cp test-crr.sh s3://$stack_name-$target_region

sleep 5

echo "4.a. Read from $target_region - expected status COMPLETED"
aws s3api head-object --bucket $stack_name-$target_region --key test-crr.sh
echo "4.b. Read from $source_region - expected status REPLICA"
aws s3api head-object --bucket $stack_name-$source_region --key test-crr.sh


echo "5. Delete both files from $source_region"

aws s3 rm s3://$stack_name-$source_region/setup-crr.sh
aws s3 rm s3://$stack_name-$source_region/test-crr.sh

sleep 5

echo "6. Check that they don't exist in $target_region"

aws s3api head-object --bucket $stack_name-$target_region --key setup-crr.sh
aws s3api head-object --bucket $stack_name-$target_region --key test-crr.sh

echo "7. Delete objects with their delete markers (so that buckets are truely empty and can be removed)"

aws s3api delete-objects --bucket $stack_name-$source_region --delete "$(aws s3api list-object-versions --bucket $stack_name-$source_region | jq -M '{Objects: [.["Versions","DeleteMarkers"][]|select(.Key == "setup-crr.sh")| {Key:.Key, VersionId : .VersionId}], Quiet: false}')" > /dev/null
aws s3api delete-objects --bucket $stack_name-$target_region --delete "$(aws s3api list-object-versions --bucket $stack_name-$target_region | jq -M '{Objects: [.["Versions","DeleteMarkers"][]|select(.Key == "setup-crr.sh")| {Key:.Key, VersionId : .VersionId}], Quiet: false}')" > /dev/null

aws s3api delete-objects --bucket $stack_name-$source_region --delete "$(aws s3api list-object-versions --bucket $stack_name-$source_region | jq -M '{Objects: [.["Versions","DeleteMarkers"][]|select(.Key == "test-crr.sh")| {Key:.Key, VersionId : .VersionId}], Quiet: false}')" > /dev/null
aws s3api delete-objects --bucket $stack_name-$target_region --delete "$(aws s3api list-object-versions --bucket $stack_name-$target_region | jq -M '{Objects: [.["Versions","DeleteMarkers"][]|select(.Key == "test-crr.sh")| {Key:.Key, VersionId : .VersionId}], Quiet: false}')" > /dev/null
