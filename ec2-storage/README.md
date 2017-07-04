# ec2-storage

## EBS

Elastic Block Storage is the default storage option available for EC2. EBS offers reliable persistent storage which you can use as either root or spare disks for your EC2 instances.

In order to take a full advantage of EBS make sure to run an EBS-optimized instance. An article about EBS-optimized instances performance with a list of all supported instance types is available here: http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/EBSOptimized.html

I have a simple CloudFormation stack which creates a test VPC with an EBS-optimized instance with an explicit EBS volume attached to it. This EBS volume will later be extended from 8 GB to 20 GB on the fly.

Execute the below script. As `keypair_name` provide your SSH key and as a `stack_name` provide the stack name which you will see in CloudFormation console (can be anything really).

```
./create-instance-with-explicit-ebs.sh keypair_name stack_name
```

Upon successful completion it prints stack info.

I provided `UserData` and `cfn-init` scripts, so that the EBS is already formatted and mounted to `/mnt/safe` for you (note: root EBS is always ready for use, spare EBS disks are raw block devices which need explicit formatting & mounting).

Connect to the instance and create a large test file there:

```
$ sudo su # /mnt/safe by default accessible to root only
$ cd /mnt/safe
$ dd if=/dev/urandom of=7GB.bin bs=1G count=7 iflag=fullblock
```

7 GB is less than 8 GB so everything is just fine. Now update disk to 20 GB in the `ec2-ebs.template.yml` template and execute the update script:

```
./update-instance-with-explicit-ebs.sh keypair_name stack_name
```

in Web Console the volume size is already 20 GB and its status is:

```
in-use - optimizing (0%)
```

The 0% can actually be a non-zero already (or even 100%). The `lsblk` shows you the new disk size right away:

```
$ lsblk
NAME    MAJ:MIN RM SIZE RO TYPE MOUNTPOINT
xvda    202:0    0   8G  0 disk
└─xvda1 202:1    0   8G  0 part /
xvdb    202:16   0  20G  0 disk /mnt/safe
```

But, `df -h` still sees the old size (8 GB). And indeed trying to create new file ends with an error:

```
$ cp 7GB.bin 7GB.bin.copy
cp: error writing ‘7GB.bin.copy’: No space left on device
cp: failed to extend ‘7GB.bin.copy’: No space left on device
```

Thankfully, as Linux already sees larger device, all we need is the on-line resizing:

```
$ sudo resize2fs /dev/xvdb
resize2fs 1.42.12 (29-Aug-2014)
Filesystem at /dev/xvdb is mounted on /mnt/safe; on-line resizing required
old_desc_blocks = 1, new_desc_blocks = 1
The filesystem on /dev/xvdb is now 5242880 (4k) blocks long.
```

Copy the file again. No errors this time. All is fine. Linux disk was extended on the fly. There was no need for stopping/restarting the instance.

## EFS

EBS has some limits like you have to specify disk size and resize it when you are running out of free space. Max EBS volume size is only 16 TB. EBS volume can be attached to only one EC2 instance at the same time.

If you accept a little bit slower I/O times Amazon has a service called EFS (Elastic File System). EFS is simply an enormous size (exabytes) NFS disk. By mounting EFS disk to your EC2 instance you can have pretty much an unlimited storage. You don't need to format it and it can be mounted by multiple EC2 instances at the same time.

For a comparison of EBS and EFS check this official documentation: http://docs.aws.amazon.com/efs/latest/ug/performance.html

In order to create a test VPC with an instance with an EFS disk attached to it execute the following script prepared by me:

```
./create-instance-with-efs.sh keypair_name stack_name
```

Copy the public IP from the stack's outputs and connect to this instance. You will see an NFS drive which has a capacity of 8 EB (8.0 × 10^18 bytes):

```
$ df -h
Filesystem                                 Size  Used Avail Use% Mounted on
devtmpfs                                   489M   60K  488M   1% /dev
tmpfs                                      497M     0  497M   0% /dev/shm
/dev/xvda1                                 7.8G  976M  6.7G  13% /
fs-XXXXXXXX.efs.us-east-2.amazonaws.com:/  8.0E     0  8.0E   0% /mnt/ocean
```

## RAID 0

Other options? Yeah, you can create RAID disks on EC2. Just don't create RAID 1 as they don't make sense (EBS volume is already redundant you don't have to worry about it, RAID 1 will only incur your bill). RAID 0 allows you to create bigger disks and get better performance.

I prepared a sample CloudFormation template which setups RAID 0 backed by 3 EBS volumes. Run this script:

```
./create-instance-with-raid-0.sh keypair_name stack_name
```

Copy the public IP from the stack outputs and connect to it. You will see a RAID disk of 30 GB in size:

```
$ df -h
Filesystem      Size  Used Avail Use% Mounted on
devtmpfs        489M   76K  488M   1% /dev
tmpfs           497M     0  497M   0% /dev/shm
/dev/xvda1      7.8G  976M  6.7G  13% /
/dev/md0         30G   44M   28G   1% /mnt/exchequer
$ lsblk
NAME    MAJ:MIN RM SIZE RO TYPE  MOUNTPOINT
xvdc    202:32   0  10G  0 disk
└─md0     9:0    0  30G  0 raid0 /mnt/exchequer
xvda    202:0    0   8G  0 disk
└─xvda1 202:1    0   8G  0 part  /
xvdd    202:48   0  10G  0 disk
└─md0     9:0    0  30G  0 raid0 /mnt/exchequer
xvdb    202:16   0  10G  0 disk
└─md0     9:0    0  30G  0 raid0 /mnt/exchequer
```

Le voilà. RAID 0 in the cloud.

## Instance store

Please keep in mind that there is also an instance store type of disk. This is a disk which is ephemeral and all the data stored on it evapourate when you stop the instance. That's a serious limitation. However, there is one clear advantage: these disks are physically attached to your VM which can provide better performance for your EC2 instances.
