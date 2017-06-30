# cloudformation

AWS CloudFormation is a service that let's you define your infrastructure as code (as template in either JSON or YAML).
AWS CloudFormation takes care of provisioning (and rolling back upon error if required) almost all (literally almost all) AWS resources: S3, EC2 & networking (like VPC, IG, NATGW, SG, NACL, routes, subnets, LC, ASG, ELB, ALB, EC2, ESB, Route53, ECS, Lambda), databases (DynamoDB, RDS, Redshift, ElastiCache), IAM resources (users, groups, policies, roles), etc.
What is more with CloudFormation you can safely release updates to you infrastructure as change sets.

Let's see some examples.

# Updating stacks using change sets

Using change sets is the preferred way of updating a stack. You prepare a new template and ask AWS to prepare a change set. Change set describes all the changes that AWS would do in order to apply changes (remove old, update existing, add new ones). You can review the change set and either discard it or apply it.

Let's re-use a VPC which I built as a part of networking-igw-natgw-natinstance project:

```
keypair_name=XXX-YOUR-EC2-KEYPAIR-NAME-XXX
cd ../networking-igw-natgw-natinstance/
./create-stack.sh $keypair_name
```

The stack name (and a few other useful information) is printed to the output. Store stack name in `$stack_name` env variable.

Now go back to cloudformation project and create a change set to the original stack:

```
cd ../cloudformation/
./create-change-set.sh $keypair_name $stack_name
```

It will create a change set based on the changes which I made (template  `networking-test-vpc-ec2-changes.template`). The changes are:

* add RDS MySQL DB - example of adding resources
* remove both private instances - example of removing resources
* bastion instance changed to t2.small - example of updating resources

Also, in the new version of the networking stack, I'm exporting the bastion/nat instance public IP. For example, my other system is using IP whitelisting and I would like to reference that IP from another CloudFormation stack (using Export/Import feature).

You can play around with this script and for example comment out executing change set. Then you can see how AWS Web Console is showing you the changes, etc.

# Stacks with dependencies and signals

The previous example was rather simple one. When you start provisioning larger envs you may need resources to be created in an exact order. For example you want first RDS db instance to be provisioned and then information about its endpoint passed to EC2 instances. Also, it is possible that during env provisioning you may do some additional work on EC2 instances and mark resource as completed only if certain actions were executed successfully. Finally, let's also reference bastion IP from the networking VPC and allow traffic from it on port 8080 to our web server.

So take a look at `web-server-with-database.template` and especially at the `WebServerInstance` resource:

* it has `"DependsOn": "DBInstance"`
* it has `CreationPolicy` set to `ResourceSignal` meaning that the resource will tell CloudFormation whether or not it run fine
* it has `UserData` added which does 3 things:
  * updates CFN-related services and helper scripts
  * kicks off `All` change set which is configured in `Metadata` section (see below)
  * upon successful execution signals to AWS CloudFormation that resource was successfully provisioned
* it has a whole new section `Metadata` added which defines 4 change sets:
  * `Install` - installs nginx
  * `Configure` - creates CFN services configs and creates HTML page which will be served by nginx, this page prints RDS endpoint address
  * `Run` - makes sure that CFN services and nginx are running
  * `All` - which is `Install` + `Configure` + `Run`. `All` is the one which is executed from the `UserData` script.
* Security Group for port 8080 is referencing bastion IP from the above networking stack using CloudFormation `Fn::ImportValue`


```
networkig_stack_name=$stack_name
./create-stack-with-dependencies-and-signals.sh $networkig_stack_name
```

# Notes on CloudFormation Export/Import features

Export/Import looks like a really cool feature, but it also has some (serious?) limitations:

* exported value cannot be updated - in my networking example stack the bastion public IP was exported in first change set; try changing instance type of bastion one more time and re-run the `create-change-set.sh` script; bastion will be replaced with new instance type and will get new public IP (yes, I know that it should be EIP, but that was just an example stack) - the CloudFormation will start applying new change set but will fail on the last step - on updating the exported value - as a result the whole change set will be reverted
* when you try to remove the main stack whose exports are imported by other stacks, it won't work; you need to remove all dependent stacks first and only then CloudFormation will let you remove the main stack.
* (not a serious one though) name of the export cannot use functions/references to resources - this is to make the name of the exported value more like a static label (and makes sense)

If above limitations are of any concerns to you, an alternative to Export/Import could be using `CloudFormation:DescribeStacks` to read stack outputs and pass them as explicit params to other stacks.

# Notes on AWS CloudFormation capabilities

When you run CloudFormation stack it uses the callee permissions. The callee must have permissions to invoke all the actions that CloudFormation executes on his behalf.

There is additional requirement for CloudFormation stacks which create IAM resources. These types of operations can be potentially dangerous - especially when you run 3rd party stacks (which could for example create a role with admin access to all AWS services and use it to attack your account/services/resources).

In such case you need to explicitly tell CloudFormation that you want to create IAM resources. This is done by appending the following argument to `create-stack` command:

```
--capabilities CAPABILITY_IAM
```

# Next Steps?

With AWS Service Catalog you can turn your CloudFormation stacks into manageable (and versioned) products. These products can be later launched by other AWS users. This is a really nice way of organising and managing your stacks.
