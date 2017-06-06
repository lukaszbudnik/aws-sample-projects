# security-group-vs-nacl

Both security groups and network ACL can be used to allow/block traffic to EC2 instances. They differ quite a lot. The most important differences are listed below.

Properties of security groups are:

1. deny all traffic and only allow the one which is explicitly listed
2. are stateful (existing connections are not affected by security group changes)
3. entries may consists of either CIDR blocks or references to other security groups

Properties of network ACL:

1. can explicitly deny or allow traffic
2. are stateless (all connections are affected by network ACL changes)
3. are applied at the subnet level (can span multiple security groups)

# Prerequisites

It is assumed that you run it in your AWS test account. User (or role) invoking `test.sh` should have access to AWS EC2. For testing I was using full permissions to EC2.

This script takes no arguments. All required information is fetched from http://169.254.169.254/latest/meta-data.

However there is one assumption in place:

* security group of your EC2 instance contains a rule that allows SSH (22) traffic from CIDR: `{your-remote-ip}/32`

# Sample output

A sample output I got for my test instance (IP addresses and security groups anonymised):

```
[ec2-user@ip-192-168-3-9 ~]$ ./test.sh
Your IP is: 9.2.1.8
CIDR block used for testing is: 9.2.1.8/32

Security group matching your CIDR is: sg-1q8b1qe9
Ingress access revoked, let's double check it...
Security group matching your CIDR is: None

As you can see the SSH session is still active.
This is because security groups are stateful!

I will sleep for 15 seconds now.

You can hit [ctrl] + [c] to abort this script and try to reconnect over SSH.
Security group will prevent you from creating new connections from your IP.

Now, let's block the traffic using NACL
Deny ACL entry added, it's just a matter of seconds now...
[ec2-user@ip-192-168-3-9 ~]$ packet_write_wait: Connection to 54.1.1.1: Broken pipe```
