# kms

This folder contains a lot of interesting examples of using AWS KMS.

## kms-test.sh

This script uses CloudFormation to create an AWS KMS master key. For encrypting data it generates data key using the master key. The data key is then used to encrypt and decrypt the data.

The key created by my CloudFormation template is:

* AWS-managed
* has rotation enabled
* has alias created (it is a best practice to use aliases and not key ids)
* appends explicit administrator policy
* appends explicit user policy

This script expects 2 positional parameters: the first is principal ARN of the administrator of the key and the second one is the principal ARN of the key user.

Example:

```
./kms-test.sh arn:aws:iam::000000000007:user/lukaszbudnik arn:aws:iam::000000000007:user/lukaszbudnik-test
```

The script deletes the stack at the end (which includes scheduling deletion of created key using the default 30 days wait period).

## kms-manual-key-rotation.sh

This is a more complex example which shows you how to import customer-managed key into AWS KMS. This script is not using CloudFormation because importing keys is not supported by CloudFormation (probably because of security reasons), instead it uses aws cli.

Info: you don't have to have customer-managed/imported keys to do the manual key rotation. I just wanted to make the example a little bit more interesting :)

This script shows you how to:

* import key material into AWS KMS
* monitor expiration time of imported keys using AWS CloudWatch (you have to do this for customer-managed keys)
* rotate keys (thanks to use of key aliases rotation is seamless for end users)
* schedule keys for deletion using the minimum wait period (7 days)

By using aliases to do the encryption there are no changes required to the application: encryption will always use key alias which does not change. The KMS encrypted data contain metadata with a pointer to the key id used to encrypt it (not the key alias!). In order to be able to decrypt the old data you must not delete the old key after the rotation. You must manage all your keys yourself in this case.

Example:

```
./kms-manual-key-rotation.sh
```

It does not expect any params. The created keys will have default policies.

This script:

1. creates first key and imports key material, creates key alias
2. encrypts data using key alias
3. creates second key and imports different key material, updates key alias
4. decrypts the data
5. schedules deletion of both keys after 7 days
