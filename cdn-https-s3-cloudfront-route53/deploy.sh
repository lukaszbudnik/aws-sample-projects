#!/bin/bash

BUCKET_NAME=XXX
DNS_ZONE_NAME=YYY

echo "1. create bucket for CDN"
aws s3api create-bucket --bucket ${BUCKET_NAME} --acl public-read

echo "2. assign global read policy to bucket"
sed s/BUCKET_NAME_PLACEHOLDER/${BUCKET_NAME}/g config/bucket-policy.json > /tmp/${BUCKET_NAME}-bucket-policy.json
aws s3api put-bucket-policy --bucket ${BUCKET_NAME} --policy file:///tmp/${BUCKET_NAME}-bucket-policy.json
rm /tmp/${BUCKET_NAME}-bucket-policy.json

echo "3. enable website hosting"
aws s3 website s3://${BUCKET_NAME} --index-document index.html --error-document error.html

echo "4. deploy the contents"
aws s3 cp . s3://${BUCKET_NAME} --recursive --exclude "config/*" --exclude deploy.sh

echo "5. create bucket for CloudFront logs"
aws s3api create-bucket --bucket ${BUCKET_NAME}-logs

echo "6. create cloudfront distribution"

# find ACM Certificate
acm_cert_arn=$(aws acm list-certificates --query "CertificateSummaryList[?contains(DomainName, '$DNS_ZONE_NAME')]|[0].CertificateArn" --output text)

sed s,BUCKET_NAME_PLACEHOLDER,${BUCKET_NAME},g config/distribution-config.json > /tmp/${BUCKET_NAME}-distribution-config.json
sed -i s,DNS_ZONE_NAME_PLACEHOLDER,${DNS_ZONE_NAME},g /tmp/${BUCKET_NAME}-distribution-config.json
sed -i s,ACM_CERT_ARN_PLACEHOLDER,${acm_cert_arn},g /tmp/${BUCKET_NAME}-distribution-config.json
distribution_response=$(aws cloudfront create-distribution --distribution-config file:///tmp/${BUCKET_NAME}-distribution-config.json)
rm /tmp/${BUCKET_NAME}-distribution-config.json

echo "$distribution_response"

echo "7. wait for distribution to complete"

distribution_id=$(echo $distribution_response | jq -r '.Distribution.Id')
distribution_domain=
while true; do
  progress=$(aws cloudfront get-distribution --id ${distribution_id})
  status=$(echo "$progress" | jq -r '.Distribution.Status')
  if [ "$status" == "InProgress" ]; then
    echo "Status of distribution $distribution_id is $status. Sleeping for 60 seconds"
    sleep 60
  else
    echo "Finished. Distribution is ready."
    distribution_domain=$(echo "$progress" | jq -r '.Distribution.DomainName')
    break
  fi
done

echo "8. add Route53 DNS entry"

hosted_zone_id=$(aws route53 list-hosted-zones-by-name --dns-name $DNS_ZONE_NAME --query "HostedZones[0].Id" --output text | cut -d'/' -f 3)
sed s/DNS_ZONE_NAME_PLACEHOLDER/${DNS_ZONE_NAME}/g config/change-resource-record-sets.json > /tmp/${DNS_ZONE_NAME}-change-resource-record-sets.json
sed -i s/DISTRIBUTION_DOMAIN_PLACEHOLDER/${distribution_domain}/g /tmp/${DNS_ZONE_NAME}-change-resource-record-sets.json
aws route53 change-resource-record-sets --hosted-zone-id $hosted_zone_id --change-batch file:///tmp/${DNS_ZONE_NAME}-change-resource-record-sets.json
rm /tmp/${DNS_ZONE_NAME}-change-resource-record-sets.json
