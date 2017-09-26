# s3-cross-region-replication

This folder contains 2 scripts for setting up and testing bi-directional cross region replication in AWS S3.

## setup-crr.sh

This script is responsible for setting up AWS S3 bi-directional cross region replication. Under the hood it uses AWS CloudFormation to provision all resources. The script does the following:

1. creates source bucket
2. creates target bucket
3. creates replication role with source to target and target to source permissions
4. enables cross region replication from source to target bucket using role from point 3
5. enables cross region replication from target to source bucket using role from point 3

## test-crr.sh

This script is used for testing bi-directional cross region replication. It does creates, deletes, and reads to/from both buckets to prove that data get replicated in both directions.
