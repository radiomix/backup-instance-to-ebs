# backup-instance-to-ebs
Backup an Instance Backed AMI into an EBS Backed AMI

The [AWS
docu](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/creating-an-ami-instance-store.html#Using_ConvertingS3toEBS)
describes how to copy an Instance Stored AMI into an EBS backed AMI.
As it is a process with several steps, we split the task in two. **Step 1**
prepares the AMI and **Step 2** performs the bundle task. Assuming a 
snapshot volume stays attached to the instance, **Step 2** can be repeated
each time the instance was configured newly. All neccessary
configuration parameters are set in [`config.sh`](config.sh).
Each run of either step gets [logged](#logging) to log file `$log_file` in `$log_dir`.

______

##Usage
Attach an EBS volume with a file system to device `$aws_snapshot_device`,
adjust `$aws_snapshot_volume_id` to reflect the volume id and other parameters
in `config.sh`. You are ready to convert your instance backed AMI into
an EBS backed AMI:


###**Step 1** `prepare-instance.sh`
**This step is only performed once on the machine**. 
It installs EC2 API and EC2 Tools, checks vor
necessary packages (`wget, openssl, java, unzip, pv`), installs packages
`kpartx, gdisk, grub v0.97` and prepares `/boot/grub/menu.list` and
`/etc/fstab`.
```
$./prepare-instance.sh
```
It also genreates X509 files to bundle the new AMI.

**User input may be required**.

###**Step 2** `register-ebs.sh`
**This step could be performed on a regular basis**. 
It bundles the prepared instance and registers it as an EBS backed AMI.
We rely on the Instance to be prepared as in **Step 1** and check the bundle
parameters by script `register-ebs.sh`. We bundle and unbundle the Instance backed AMI ont 
an attached snapshot volume and register a snapshot and an EBS backed AMI. 

**No user input should required**.

```
$./register-ebs.sh
```
--------

##Prerequisites
The scripts relay on these packages to be installed:
* _unzip_
* _wget_
* _ruby_
* _java run time environment (default_jre)_ 
* _openssl_ 
* pv

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
  - generates X509 files 
 + [`register-ebs.sh`](register-ebs.sh)
  - export env variables for AWS credentials.
  - check and set bundle parameters
  - check attached snapshot volume
  - bundle the image locally
  - unbundle the image to the attached snapshot volume
  - create a snapshot and registers an AMI
 + [`functions.sh`](functions.sh)
  - collection of functions used by both scripts
 + [`config.sh`](config.sh)
  - configuration variables used by both scripts
 + [`select_pvgrub_kernel.sh`](select_pvgrub_kernel.sh)
  - select the proper PVGRUB [AKI kernel](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/UserProvidedKernels.html#configuringGRUB) accroding to AWS region and architecture

###Logging
Logfiles of each run of one of the scripts are placed under `$log_dir`
and prefixed with the script name and suffixed with the date.
The date reflexts a directory under wich to find the relevant
bundle files.

--------
###X509
**Step 1 generates X.509 Cert and Private Key**.
EC2 commands partly use an X.509 certificate -even self signed- to
encrypt communication. You can obtain the files from the AWS
console under _Security Credentials_ or let **Step 1** generate them.
```bash
openssl genrsa 2048 > private-key.pem
openssl req -new -x509 -nodes -sha1 -days 3650 -key private-key.pem
-outform PEM > certificate.pem
```
You will be asked for information included in
the certificate. You can use the default values or input your data.
The Certificate needs to be uploaded to the AWS console, showing a
thumbprint. It is usefull to rename the cert and key file to reflect the
thumbprint. Both files have to be present onto the AMI you want to
bundle named `$aws_pk_path` and `$aws_cert_path`.

#### AMIs
The following AMIs have been successfully bundled and registered:
- [ami-75755545](http://thecloudmarket.com/image/ami-75755545--ubuntu-images-ubuntu-precise-12-04-amd64-server-20150227) Ubuntu 12.04, amd64, instance-store, aki-fc8f11cc
- [ami-a7785897](http://thecloudmarket.com/image/ami-a7785897--ubuntu-images-hvm-instance-ubuntu-precise-12-04-amd64-server-20150227) Ubuntu 12.04, amd64, hvm;instance-store, hvm
- [ami-75c09945](http://thecloudmarket.com/image/ami-75c09945--ubuntu-images-ubuntu-lucid-10-04-amd64-server-20150127) Ubuntu 10.04, amd64, instance-store, aki-fc8f11cc
- [ami-47ebf177](http://https://cloud-images.ubuntu.com/locator/ec2/) Ubuntu 12.04, amd64, instance-store, aki-fc8f11cc
- [ami-7de3f94d](http://https://cloud-images.ubuntu.com/locator/ec2/) Ubuntu 12.04, amd64,  hvm:instance-store



