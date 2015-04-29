# backup-instance-to-ebs
Backup an Instance Backed AMI into an EBS Backed AMI

The [AWS
docu](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/creating-an-ami-instance-store.html#Using_ConvertingS3toEBS) 
describes how to copy an Instance Stored AMI into an EBS backed AMI. 
As it is a process with several steps, split the task in two. 
______

## **Step 1**: Prepare the Instance backed AMI
We prepare the Instance backed AMI to be bundles later. This step is
only performed once. It installs EC2 API and EC2 Tools, checks vor
necessary packages (`wget, openssl, java, unzip`), installs packages
`kpartx, gdisk, grub v0.97` and prepares `/boot/grub/menu.list` and
`/etc/fstab`. 
```
$./prepare-instance.sh
```

### Prerequisites
The scripts relay on these packages to be installed on the AMI to be
copied:
* _unzip_
* _wget_
* _ruby_
* _java run time environment (default_jre)_ 
* _openssl_  

Log file `bundle-2015-04-24-10-37-19.log` remebers AWS
parameters for **Step 2**. 

## **Step 2**: Bundle and register the prepared Instance backed AMI into an EBS backed AMI
As we only bundle a paravirtualized Ubuntu 12.04 AMI, we rely on the
Instance to be prepared as in **Step 1** and hard code the bundle
parameters into the script. We bundle and unbundle the Instance backed AMI onto 
an attached EBS volume and register a snapshot and an EBS backed AMI.
We log parameters to log file `bundle-2015-04-24-10-37-19.log`
```
$./register-ebs.sh
```

### Bundling Parameter
We use the following parameter for bundling:
- **virtualization type `paravirtual`**
 * virtualization type:paravirtual


-------------
**Step 2** need some variables, which are
checked and set by the scripts:
* AWS
 + `AWS_ACCESS_KEY`="MY-ACCESS-KEY"
 + `AWS_SECRET_KEY`="My-Secret-Key"
 + `AWS_ACCOUNT_ID`="My-Account-Id"
 + `AWS_REGION`="My-Region"
 + `AWS_ARCHITECTURE`=" i386 | x86_6"
 + `AWS_CERT_PATH`="/path/to/my/x509-cert.pem"
 + `AWS_PK_PATH`="/path/to/my/x509-pk.pem"

* EC2
 + `EC2_AMITOOL_HOME`=$ami_tool
 + `EC2_HOME`=$api_tool
 + `PATH=$PATH:$EC2_AMITOOL_HOME/bin:$EC2_HOME/bin`

* JAVA: `ec2-register` is a EC2 CLI Tool written in Java and thus needs
  Java installed.
 + `JAVA_HOME=$java_home`

### X.509 Certificate and Private Key
**Step 2** needs  **X.509 Cert** and **Private Key** as
EC2 commands partly use an X.509 certificate -even self signed- to
encrypt communication. **Step 1** checks the presence of both files.
You can either optain them from the AWS
console under _Security Credentials_ or generate them by hand, after
openssl installation. To generate and self sign a certificate valid for
10 years in 2048 bit type:
```bash
openssl genrsa 2048 > private-key.pem
openssl req -new -x509 -nodes -sha1 -days 3650 -key private-key.pem
-outform PEM > certificate.pem
```
Generating the Certificate asks for information included in
the certificate. You can use the default values or input your data.
The Certificate needs to be uploaded to the AWS console, showing a
thumbprint. It is usefull to rename the cert and key file to reflect the
thumbprint. 
Both cert and private key have to be uploaded onto both AMIs.

### Scripts
 + [`aws-tools.sh`](aws-tools.sh) 
   - Installs `ec2-api-tools` and `ec2-ami-tools` 
   - checks for Java installatation and asks to install `default-jre`,
   - exports env variables for AWS credentials.
 + [`bundle-instance.sh`](bundle-instance.sh)
  - installs packages `gdisk`,`kpartx` and `grub` (legacy)
  - checks for command line kernel parameters and its counterpart in
    `/boot/grub/menu.lst` and edit them
  - checks for `efi` partitions in `/etc/fstab`
  - check and set bundle parameters
  - bundles and uploads the image and registers an AMI
 + [`convert-instance-to-ebs.sh`](convert-instance-to-ebs.sh)
  - checks for AWS environment variables
  - creates and attaches an EBS volume
  - dowloads and unbundles the previous manifest
  - creates a snapshot and registers an AMI
  - unmounts and dettaches the EBS volume
 + [`register-ebs.sh`](register-ebs.sh)
  - installs packages `gdisk`,`kpartx` and `grub` (legacy)
  - checks for command line kernel parameters and its counterpart in
    `/boot/grub/menu.lst` and edit them
  - checks for `efi` partitions in `/etc/fstab`
  - check and set bundle parameters
  - bundles the image locally
  - creates and attaches an EBS volume
  - unbundles the previous manifest
  - creates a snapshot and registers an AMI
  - unmounts and dettaches the EBS volume


### Issues 
