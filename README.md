# backup-instance-to-ebs
Backup an Instance Backed AMI into an EBS Backed AMI

The [AWS
docu](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/creating-an-ami-instance-store.html#Using_ConvertingS3toEBS)
describes how to copy an Instance Stored AMI into an EBS backed AMI.
As it is a process with several steps, we split the task in two. **Step 1**
prepares the AMI and **Step 2** preformace the bundle task. Assuming an
EBS volume stays attached to the instance, **Step 2** can be repeated
each time the instance was configured newly. All neccessary
configuration parameters are set in [`config.sh`](config.sh).
______

##**Step 1**: Prepare the Instance backed AMI
This step is only performed once. It installs EC2 API and EC2 Tools, checks vor
necessary packages (`wget, openssl, java, unzip`), installs packages
`kpartx, gdisk, grub v0.97` and prepares `/boot/grub/menu.list` and
`/etc/fstab`. 
```
$./prepare-instance.sh
```
Each run gets [logged](#logging) to log file `$log_file` in `$log_dir`.

##**Step 2**: Bundle and register the prepared Instance backed AMI into an EBS backed AMI
We rely on the Instance to be prepared as in **Step 1** and check the bundle
parameters by script `register-ebs.sh`. We bundle and unbundle the Instance backed AMI onto 
an attached EBS volume and register a snapshot and an EBS backed AMI.
Each run gets [logged](#logging) to log file `$log_file` in `$log_dir`.

```
$./register-ebs.sh
```
--------

###Prerequisites
The scripts relay on these packages to be installed:
* _unzip_
* _wget_
* _ruby_
* _java run time environment (default_jre)_ 
* _openssl_ 
 
* X.509 Certificate

**Step 2** also requires two X.509 files,one certificate
and one private key beeing uploaded to `$aws_cert_directory`.
Section [X.509](#x509) describes how to generate both files.

###Bundling Parameter
We use the following parameter for bundling:
 * virtualization type:paravirtual or hvm (gets checkt by
   `register-ebs.sh`)
 *  --block-device-mapping ami=sda,root=/dev/sda1 

**Step 2** needs some variables, which are
checked or set by the scripts:
* set by user input
  + `AWS_ACCESS_KEY`="MY-ACCESS-KEY"
  + `AWS_SECRET_KEY`="My-Secret-Key"
  + `AWS_ACCOUNT_ID`="My-Account-Id"
  + `AWS_CERT_PATH`="/path/to/my/x509-cert.pem"
  + `AWS_PK_PATH`="/path/to/my/x509-pk.pem"
* set by script
  + `AWS_REGION`="My-Region"
  + `AWS_ARCHITECTURE`=" i386 | x86_6"
  + `EC2_AMITOOL_HOME`=$ami_tool
  + `EC2_HOME`=$api_tool
  + `PATH=$PATH:$EC2_AMITOOL_HOME/bin:$EC2_HOME/bin`
  + `JAVA_HOME=$java_home`
 JAVA: `ec2-register` is a EC2 CLI Tool written in Java and thus needs
  Java installed (set by script)

-------------
###Scripts
 + [`prepare-instance.sh`](prepare-instance.sh)
  - install `ec2-api-tools` and `ec2-ami-tools` under `$ec2_prefix`
  - checks for Java installatation and asks to install `default-jre`,
  - install packages `gdisk`,`kpartx` and `grub` (legacy)
  - check for command line kernel parameters and its counterpart in
   `/boot/grub/menu.lst` and edit them
  - check for `efi` partitions in `/etc/fstab` and edit them
 + [`register-ebs.sh`](register-ebs.sh)
  - export env variables for AWS credentials.
  - check and set bundle parameters
  - check attached EBS volume
  - bundle the image locally
  - unbundle the image to the attached EBS volume
  - create a snapshot and registers an AMI
 + [`functions.sh`](functions.sh)
  - collection of functions used by both scripts
 + [`config.sh`](config.sh)
  - configuration variables used by both scripts

###Logging
Logfiles of each run of one of the scripts are placed under `$log_dir`
and prefixed with the script name and suffixed with the date.
The date reflexts a directory under wich to find the relevant
bundle files.

--------
###X509
**Step 2** needs  **X.509 Cert** and **Private Key** as
EC2 commands partly use an X.509 certificate -even self signed- to
encrypt communication. **Step 2** lets the user input file names
and checks the presence of both files.
You can either obtain them from the AWS
console under _Security Credentials_ or generate them by hand, after
openssl installation. To generate and self sign a certificate valid for
10 years in 2048 bit type:
```bash
openssl genrsa 2048 > private-key.pem
openssl req -new -x509 -nodes -sha1 -days 3650 -key private-key.pem
-outform PEM > certificate.pem
```
Generating the certificate asks for information included in
the certificate. You can use the default values or input your data.
The Certificate needs to be uploaded to the AWS console, showing a
thumbprint. It is usefull to rename the cert and key file to reflect the
thumbprint. Both cert and private key have to be uploaded onto the AMIs
under `$aws_cert_directory`.

#### AMIs
The following AMIs have been successfully bundled and registered:
- ami-75755545 Ubuntu 12.04, amd64, instance-store, aki-fc8f11cc
- ami-a7785897 Ubuntu 12.04, amd64, hvm;instance-store, hvm
- ami-75c09945 Ubuntu 10.04, amd64, instance-store, aki-fc8f11cc
- ami-c15379f1 Ubuntu 12.04, amd64, instance-store, aki-fc8f11cc


