#!/bin/bash

TEST_ROLE_NAME=TestS3ReadOnlyAccessRole

echo "1. add AssumeAllRoles in-line policy to current user"
current_user_arn=$(aws iam get-user --query "User.Arn" --output text)
user=$(echo $current_user_arn | awk -F / '{print $2}')
aws iam put-user-policy --user-name $user --policy-name AssumeAllRoles --policy-document file://assume-all-roles-user-policy.json

echo "2. create test role"
sed s,USER_ARN_PLACEHOLDER,$current_user_arn,g role-trust-policy.json > /tmp/role-trust-policy.json
role=$(aws iam create-role --role-name $TEST_ROLE_NAME --assume-role-policy-document file:///tmp/role-trust-policy.json)
rm /tmp/role-trust-policy.json

echo "$role"

echo "3. attach AmazonS3ReadOnlyAccess policy to newly created role"
role_arn=$(echo $role | jq -r '.Role.Arn')
aws iam attach-role-policy --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess --role-name $TEST_ROLE_NAME

echo "4. give AWS some time to propagate changes... (30 seconds should do the trick)"

sleep 30

echo "5. call sts service as current user and obtain temporary credentials"
assume_role=$(aws sts assume-role --role-arn $role_arn --role-session-name S3TempRole)

echo "6. unset current user credentials"
unset AWS_SECRET_ACCESS_KEY
unset AWS_ACCESS_KEY_ID
unset AWS_SESSION_TOKEN

echo "7. no credentials set, following command ends with error"
aws s3 ls

echo "8. set temp credentials"
export AWS_ACCESS_KEY_ID=$(echo $assume_role | jq -r '.Credentials.AccessKeyId')
export AWS_SECRET_ACCESS_KEY=$(echo $assume_role | jq -r '.Credentials.SecretAccessKey')
export AWS_SESSION_TOKEN=$(echo $assume_role | jq -r '.Credentials.SessionToken')

echo "8. execute the command one more time - works with temp credentials now"
aws s3 ls | head -2

echo "9. clean-up temp credentials"
unset AWS_SECRET_ACCESS_KEY
unset AWS_ACCESS_KEY_ID
unset AWS_SESSION_TOKEN
