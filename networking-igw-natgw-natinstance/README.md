# networking-igw-natgw-natinstance

There are three ways you can use to connect EC2 instances to the Internet.

1. Instances in public network can connect directly to Internet Gateway
2. Instances in private network can connect to NAT Instance (which runs in public network and is connected to Internet Gateway)
3. Instances in public/private network can connect to NAT Gateway (NAT as a service)

# Prerequisites

It is assumed that you run it in your AWS test account. User (or role) invoking `create-stack.sh` should have access to AWS CloudFormation & AWS EC2. For testing I was using full permissions to CloudFormation & EC2.

This script takes one argument: name of the key pair which will be assigned to EC2 instances.

```
$ ./create-stack.sh XXX
```

It will create 3 `t2.micro` instances using AWS Linux NAT image (for bastion/NAT instance in public subnet) and AWS Linux image (for 2 instances in private subnets).

# Testing VPC networking

Let's assume you have 2 variables set:

```
key_path=/home/YYY/.ssh/XXX.pem
bastion_ip=A.B.C.D
```

Upload private key from `$key_path` as `key.pem` to `$bastion_ip`:

```
scp -i $key_path $key_path ec2-user@$bastion_ip:/home/ec2-user/key.pem
```

## Instance in public network

Bastion/NAT instance is attached directly to Internet Gateway.
You can call `traceroute` a couple of items and you may see different first hops:

```
$ ssh -i $key_path ec2-user@$bastion_ip
$ traceroute -m 1 checkip.amazonaws.com
traceroute to checkip.amazonaws.com (50.19.227.215), 1 hops max, 60 byte packets
 1  ec2-54-93-0-0.eu-central-1.compute.amazonaws.com (54.93.0.0)  0.304 ms ec2-54-93-0-70.eu-central-1.compute.amazonaws.com (54.93.0.70)  18.872 ms ec2-54-93-0-6.eu-central-1.compute.amazonaws.com (54.93.0.6)  0.333 ms
$ traceroute -m 1 checkip.amazonaws.com
traceroute to checkip.amazonaws.com (50.19.97.123), 1 hops max, 60 byte packets
 1  ec2-54-93-0-4.eu-central-1.compute.amazonaws.com (54.93.0.4)  0.314 ms ec2-54-93-0-66.eu-central-1.compute.amazonaws.com (54.93.0.66)  14.627 ms ec2-54-93-0-68.eu-central-1.compute.amazonaws.com (54.93.0.68)  15.050 ms
$ traceroute -m 1 checkip.amazonaws.com
traceroute to checkip.amazonaws.com (23.21.70.163), 1 hops max, 60 byte packets
 1  ec2-54-93-0-68.eu-central-1.compute.amazonaws.com (54.93.0.68)  12.028 ms ec2-54-93-0-2.eu-central-1.compute.amazonaws.com (54.93.0.2)  0.378 ms ec2-54-93-0-66.eu-central-1.compute.amazonaws.com (54.93.0.66)  21.745 ms
```

If you execute the following command:

```
$ curl checkip.amazonaws.com
52.X.Y.Z
```

You will get public IP address of the bastion/nat instance.

This is how Internet Gateway works.

## Instance in private network behind NAT Gateway

In the CloudFormation I have hardcoded private IPs so just copy & paste it on bastion host:

```
$ ssh -i key.pem ec2-user@192.168.2.8
$ traceroute -m 1 checkip.amazonaws.com
traceroute to checkip.amazonaws.com (23.21.70.163), 1 hops max, 60 byte packets
 1  192.168.3.13 (192.168.3.13)  0.176 ms  0.178 ms  0.181 ms
```

The first hop (`192.168.3.13`) is the private IP of NAT gateway.
You can execute `traceroute` a couple of times and it will always return this IP.

If you execute the following command:

```
$ curl checkip.amazonaws.com
35.A.B.C
```

You will get public IP address of the NAT gateway.

## Instance in private network behind NAT Instance

In the CloudFormation I have hardcoded private IPs so just copy & paste it on bastion host:

```
$ ssh -i key.pem ec2-user@192.168.1.4
$ traceroute -m 1 checkip.amazonaws.com
traceroute to checkip.amazonaws.com (50.19.97.123), 1 hops max, 60 byte packets
 1  192.168.3.9 (192.168.3.9)  1.151 ms  1.167 ms  1.288 ms
```

The first hop (`192.168.3.9`) is the private IP of the bastion/NAT instance.
You can execute `traceroute` a couple of times and it will always return this IP.

If you execute the following command:

```
$ curl checkip.amazonaws.com
52.X.Y.Z
```

You will get public IP address of the bastion/NAT instance.
