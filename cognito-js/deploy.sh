#!/bin/bash

AWS_DEFAULT_REGION=us-east-1

echo "1. reading variables from config/config.json"

CONFIG=$(cat config/config.json)
BUCKET=$(echo $CONFIG | jq -r '.bucket')
USER_POOL=$(echo $CONFIG | jq -r '.userPool.name')
USERNAME=$(echo $CONFIG | jq -r '.user.username')
EMAIL=$(echo $CONFIG | jq -r '.user.email')
TEMPORARY_PASSWORD=$(echo $CONFIG | jq -r '.user.temporaryPassword')
IDENTITY_POOL_NAME=$(echo $CONFIG | jq -r '.identityPool.name')
COGNITO_AUTHENTICATED_USER_ROLE=$(echo $CONFIG | jq -r '.identityPool.authenticatedRole')

echo "2. create bucket $BUCKET"
aws s3api create-bucket --bucket $BUCKET

echo "3. create Cognito IDP user pool $USER_POOL"
user_pool=$(aws cognito-idp create-user-pool --pool-name $USER_POOL)
user_pool_id=$(echo $user_pool | jq -r '.UserPool.Id')
echo $user_pool_id

user_pool_id=us-east-1_D03pQAMmn

echo "4. create user pool client"
user_pool_client=$(aws cognito-idp create-user-pool-client --user-pool-id $user_pool_id --client-name js-application --no-generate-secret)
user_pool_client_id=$(echo $user_pool_client | jq -r '.UserPoolClient.ClientId')
echo $user_pool_client_id

user_pool_client_id=6mfh2n4pusr0vdps5nc67tu90b

echo "5. create user $USERNAME"
aws cognito-idp admin-create-user --user-pool-id $user_pool_id --username $USERNAME --temporary-password $TEMPORARY_PASSWORD \
  --user-attributes Name=email,Value=$EMAIL

echo "6. create Cognito Identity Pool $IDENTITY_POOL_NAME"
identity_pool=$(aws cognito-identity create-identity-pool --identity-pool-name $IDENTITY_POOL_NAME --no-allow-unauthenticated-identities \
  --cognito-identity-providers ProviderName=cognito-idp.$AWS_DEFAULT_REGION.amazonaws.com/$user_pool_id,ClientId=$user_pool_client_id,ServerSideTokenCheck=true)
identity_pool_id=$(echo $identity_pool | jq -r '.IdentityPoolId')
echo $identity_pool_id

echo "7. create test role"
sed s,COGNITO_IDENTITY_ID_PLACEHOLDER,$identity_pool_id,g config/cognito-trust-relationship-role.json > /tmp/cognito-trust-relationship-role.json
role=$(aws iam create-role --role-name $COGNITO_AUTHENTICATED_USER_ROLE --assume-role-policy-document file:///tmp/cognito-trust-relationship-role.json)
rm /tmp/cognito-trust-relationship-role.json

role_arn=$(echo $role | jq -r '.Role.Arn')

echo "7.1. attach default cognito permissions"
aws iam put-role-policy --role-name $COGNITO_AUTHENTICATED_USER_ROLE --policy-name DefaultCognitoPermissions --policy-document file://config/cognito-default-role.json

echo "7.2. attach S3 cognito per user permission"
sed s,BUCKET_NAME_PLACEHOLDER,$BUCKET,g config/s3-cognito-per-user-policy.json > /tmp/s3-cognito-per-user-policy.json
aws iam put-role-policy --role-name $COGNITO_AUTHENTICATED_USER_ROLE --policy-name S3CognitoPermissions --policy-document file:///tmp/s3-cognito-per-user-policy.json
rm /tmp/s3-cognito-per-user-policy.json

echo "8. set identity pool role to $role_arn"
aws cognito-identity set-identity-pool-roles --identity-pool-id $identity_pool_id \
  --roles authenticated=$role_arn

echo "9. update config/config.js with user & identity pool configs"
CONFIG=$(echo $CONFIG | jq -r ".identityPool.id = \"$identity_pool_id\"")
CONFIG=$(echo $CONFIG | jq -r ".identityPool.authenticatedRoleArn = \"$role_arn\"")
CONFIG=$(echo $CONFIG | jq -r ".userPool.id = \"$user_pool_id\"")
CONFIG=$(echo $CONFIG | jq -r ".userPool.clientId = \"$user_pool_client_id\"")

echo $CONFIG > config/config.json
