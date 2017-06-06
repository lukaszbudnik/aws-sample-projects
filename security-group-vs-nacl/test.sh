#!/bin/bash

remote_ip=$(echo $SSH_CONNECTION | awk '{ print $1 }' | xargs)
cidr_block=$remote_ip/32

mac=$(curl -s http://169.254.169.254/latest/meta-data/network/interfaces/macs/)
subnet_id=$(curl -s http://169.254.169.254/latest/meta-data/network/interfaces/macs/$mac/subnet-id)
security_group_ids=$(curl -s http://169.254.169.254/latest/meta-data/network/interfaces/macs/$mac/security-group-ids | tr '\n' ' ')

echo "Your IP is: $remote_ip"
echo "CIDR block used for testing is: $cidr_block"
echo

matching_security_group_id=$(aws ec2 describe-security-groups --group-ids $security_group_ids --filters \
  Name=ip-permission.from-port,Values=22 \
  Name=ip-permission.to-port,Values=22 \
  Name=ip-permission.cidr,Values="$cidr_block" \
  --query SecurityGroups[0].GroupId \
  --output text)

echo "Security group matching your CIDR is: $matching_security_group_id"

aws ec2 revoke-security-group-ingress --group-id $matching_security_group_id \
  --protocol tcp --port 22 --cidr $cidr_block

echo "Ingress access revoked, let's double check it..."

matching_security_group_id=$(aws ec2 describe-security-groups --group-ids $security_group_ids --filters \
  Name=ip-permission.from-port,Values=22 \
  Name=ip-permission.to-port,Values=22 \
  Name=ip-permission.cidr,Values="$cidr_block" \
  --query SecurityGroups[0].GroupId \
  --output text)

echo "Security group matching your CIDR is: $matching_security_group_id"

echo
echo "As you can see the SSH session is still active."
echo "This is because security groups are stateful!"
echo
echo "I will sleep for 15 seconds now."
echo
echo "You can hit [ctrl] + [c] to abort this script and try to reconnect over SSH."
echo "Security group will prevent you from creating new connections from your IP."
echo

sleep 15


echo "Now, let's block the traffic using NACL"

nacl_id=$(aws ec2 describe-network-acls --filters Name=association.subnet-id,Values=$subnet_id --query NetworkAcls[0].NetworkAclId --output text)

# rules are processed in ascending order, so deny rule must come before default 100 allow all one
aws ec2 create-network-acl-entry --network-acl-id $nacl_id \
  --rule-number 90 \
  --protocol 6 \
  --rule-action deny \
  --ingress \
  --port-range From=22,To=22 \
  --cidr-block $cidr_block

echo "Deny ACL entry added, it's just a matter of seconds now..."
