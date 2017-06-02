#!/bin/bash

mac=$(curl -s http://169.254.169.254/latest/meta-data/network/interfaces/macs/)

vpc_id=$(curl -s http://169.254.169.254/latest/meta-data/network/interfaces/macs/$mac/vpc-id)

rds=$(aws rds describe-db-instances)

address=$(echo $rds | jq -r "select(.DBInstances[].DBSubnetGroup.VpcId == \"$vpc_id\") | .DBInstances[].Endpoint.Address")
instance_id=$(echo $rds | jq -r "select(.DBInstances[].DBSubnetGroup.VpcId == \"$vpc_id\") | .DBInstances[].DBInstanceIdentifier")
instance_class=$(echo $rds | jq -r "select(.DBInstances[].DBSubnetGroup.VpcId == \"$vpc_id\") | .DBInstances[].DBInstanceClass")
engine=$(echo $rds | jq -r "select(.DBInstances[].DBSubnetGroup.VpcId == \"$vpc_id\") | .DBInstances[].Engine")
engine_version=$(echo $rds | jq -r "select(.DBInstances[].DBSubnetGroup.VpcId == \"$vpc_id\") | .DBInstances[].EngineVersion")

ip_before=$(dig $address | grep -v ';' | grep 'IN A' | awk '{print $5}' | xargs)

echo "First option - reboot instance with force failover set to true."
echo
echo "This operation is fast. This script will loop max 10 times with a sleep of 10 seconds each. Usually 4 iterations are enough."
echo

aws rds reboot-db-instance --db-instance-identifier $instance_id --force-failover > /dev/null

echo "$address ip before failover: $ip_before"
echo
for i in {1..10}
do
   ip_after=$(dig $address | grep -v ';' | grep 'IN A' | awk '{print $5}' | xargs)
   if [ "$ip_before" != "$ip_after" ]; then
     echo
     echo "$address ip after failover: $ip_after"
     break
   fi
   echo "Waiting for new ip..."
   sleep 10
done

echo
echo
echo "Note: need to sleep for 60 seconds before doing another test - just to be sure the first failover is complete..."
echo
echo

sleep 60

all_multi_az_classes=$(aws rds describe-orderable-db-instance-options --engine $engine --vpc --engine-version $engine_version | jq -r "select(.OrderableDBInstanceOptions[].MultiAZCapable == true) | .OrderableDBInstanceOptions[].DBInstanceClass" | sort | uniq)
new_class=$(echo "$all_multi_az_classes" | grep -v $instance_class | head -1)

echo "Second option - scale DB instance from $instance_class to $new_class"
echo
echo "This operation is slow. First standby is promoted and only then DNS records are updated. This script will loop max 20 times with a sleep of 60 seconds each. Number of loops depends on instance types used for the test."
echo

aws rds modify-db-instance --db-instance-identifier $instance_id --db-instance-class $new_class --apply-immediately > /dev/null

ip_before=$ip_after
echo "$address ip before failover: $ip_before"
echo

for i in {1..20}
do
   ip_after=$(dig $address | grep -v ';' | grep 'IN A' | awk '{print $5}' | xargs)
   if [ "$ip_before" != "$ip_after" ]; then
     echo
     echo "$address ip after failover: $ip_after"
     break
   fi
   echo "Waiting for new ip..."
   sleep 60
done
