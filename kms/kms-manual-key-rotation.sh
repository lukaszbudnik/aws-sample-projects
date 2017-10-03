#!/bin/bash

region=eu-west-2

function print_sleep {
  end=$1
  for ((i=1; i <= end ; i++))
  do
    echo -n '.'
    sleep 1
  done
  echo ""
}

function create_key {
  description=$1
  key_material_filename=$2
  key_alias_name=$3

  key=$(aws kms create-key --description "$description" --origin EXTERNAL --region $region)
  key_arn=$(echo "$key" | jq -r '.KeyMetadata.Arn')

  echo "The $key_arn has state: PendingImport"
  aws kms describe-key --key-id $key_arn --region $region

  import_params=$(aws kms get-parameters-for-import --key-id $key_arn --wrapping-algorithm RSAES_OAEP_SHA_1 \
    --wrapping-key-spec RSA_2048 --region $region)

  import_token=$(echo $import_params | jq -r '.ImportToken')
  public_key=$(echo $import_params | jq -r '.PublicKey')

  echo $import_token | openssl enc -d -base64 -A -out import_token.bin
  echo $public_key | openssl enc -d -base64 -A -out public_key.bin

  openssl rsautl -encrypt \
                   -in $key_material_filename \
                   -oaep \
                   -inkey public_key.bin \
                   -keyform DER \
                   -pubin \
                   -out encrypted_${key_material_filename}

  valid_to=$(gdate --date "+10 days" +%s)

  aws kms import-key-material --key-id $key_arn --import-token fileb://import_token.bin \
    --encrypted-key-material fileb://encrypted_${key_material_filename} --valid-to $valid_to  --region $region

  echo "There were race conditions so I need to sleep for a minute..."
  print_sleep 60

  echo "The $key_arn has state: Enabled"
  aws kms describe-key --key-id $key_arn --region $region

  aws kms list-aliases --region $region --output text | grep $key_alias_name
  if [ $? -eq 1 ]; then
    aws kms create-alias --target-key-id $key_arn --alias-name $key_alias_name --region $region
  else
    aws kms update-alias --target-key-id $key_arn --alias-name $key_alias_name --region $region
  fi

  rm import_token.bin
  rm public_key.bin
  rm encrypted_${key_material_filename}
}

# create key material
key_alias_name='alias/lukaszbudnik/test1/master-key'
openssl rand -out plaintext_key_material.bin 32

# create 1st key

create_key 'Łukasz Budnik #1' plaintext_key_material.bin $key_alias_name

# encrypt
key_alias_arn=$(aws kms list-aliases --region $region | jq -r ".Aliases[] | select (.AliasName == \"$key_alias_name\") | .AliasArn")
key_1_id=$(aws kms list-aliases --region $region | jq -r ".Aliases[] | select (.AliasName == \"$key_alias_name\") | .TargetKeyId")

echo "This text will be encrypted using alias $key_alias_arn and key id: $key_1_id" > plaintext

echo "Original file:"
cat plaintext

encrypted=$(aws kms encrypt --key-id $key_alias_arn --plaintext fileb://plaintext --region $region --output text --query CiphertextBlob)

# decrypt
echo $encrypted | openssl enc -d -base64 -A -out encrypted.bin

decrypted_base64=$(aws kms decrypt --ciphertext-blob fileb://encrypted.bin --region $region --output text --query Plaintext)

echo $decrypted_base64 | openssl enc -d -base64 -A -out plaintext_decrypted

echo "Decrypted file:"
cat plaintext_decrypted

# create 2nd key using same key material and update alias
openssl rand -out plaintext_key_material_2.bin 32
create_key 'Łukasz Budnik #2' plaintext_key_material_2.bin $key_alias_name
key_2_id=$(aws kms list-aliases --region $region | jq -r ".Aliases[] | select (.AliasName == \"$key_alias_name\") | .TargetKeyId")
# alias now points to key 2
# decryption of the encrypted data will use 1st key (not assigned to alias but still used for the decryption of old data!)
# if you delete/disable key 1 the below command will fail with an error

decrypted_base64=$(aws kms decrypt --ciphertext-blob fileb://encrypted.bin --region $region --output text --query Plaintext)

echo $decrypted_base64 | openssl enc -d -base64 -A -out plaintext_decrypted

echo "Decrypted file:"
cat plaintext_decrypted

echo "Imported keys have expire date which you have to monitor"
period=120
end=$(gdate +%s)
start=$((end-period))

aws cloudwatch get-metric-statistics --namespace AWS/KMS --metric-name SecondsUntilKeyMaterialExpiration --dimensions Name=KeyId,Value=$key_1_id \
  --statistics Minimum --start-time $start --end-time $end --period $period --region $region
aws cloudwatch get-metric-statistics --namespace AWS/KMS --metric-name SecondsUntilKeyMaterialExpiration --dimensions Name=KeyId,Value=$key_2_id \
  --statistics Minimum --start-time $start --end-time $end --period $period --region $region

echo "Scheduling deletion of key $key_1_id"
aws kms schedule-key-deletion --key-id $key_1_id --pending-window-in-days 7 --region $region

echo "Scheduling deletion of key $key_2_id"
aws kms schedule-key-deletion --key-id $key_2_id --pending-window-in-days 7 --region $region

rm plain*
rm encrypted*
