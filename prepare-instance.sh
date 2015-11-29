#!/bin/bash
#
# Prepare an AMI with the AWS API/AMI tools
#   http://docs.aws.amazon.com/AWSEC2/latest/CommandLineReference/set-up-ec2-cli-linux.html
#   http://docs.aws.amazon.com/AWSEC2/latest/CommandLineReference/set-up-ami-tools.html
#  Prerequisites:
#   - we check for ruby, unzip, wget, openssl
#            and default-jre (for command ec2-register (CLI Tools need JAVA), thus we check for an installed version
#   - install kpart,gdisk,  grub legacy v 0.97
#   - check on root device for /boot/grub/menu.lst and boot command line parameter
#   - check for efi/uefi entries in /etc/fstab
#       http://docs.aws.amazon.com/AWSEC2/latest/CommandLineReference/set-up-ec2-cli-linux.html
#
# Author: Michael Kloeckner
# Email:  mkl[at]im7[dot]de
# Date:   Sept 2015
#
#######################################
## config variables

## read functions and config
source $(dirname $0)/functions.sh
source $(dirname $0)/config.sh
set -euf
set -o pipefail

start_logging

## check config var $command_list or exit
check_commands

## check AWS credentials or exit
check_aws_credentials
## generate x509 files
set_aws_x509_path

######################################
## install api/ami tools under /usr/local/ec2
echo "*** Installing AWS TOOLS"
if [[ -d $ec2_prefix ]]; then
  log_msg=" Directory $ec2_prefix exists, reinstall latest version!"
  sudo rm -rf $ec2_prefix
fi
sudo mkdir -p $ec2_prefix
sudo rm -rf $ec2_prefix/*
rm -f ec2-ami-tools.zip ec2-api-tools.zip

wget http://s3.amazonaws.com/ec2-downloads/ec2-api-tools.zip
wget http://s3.amazonaws.com/ec2-downloads/ec2-ami-tools.zip
sudo unzip -q ec2-api-tools.zip -d /usr/local/ec2/
sudo unzip -q ec2-ami-tools.zip  -d /usr/local/ec2/

######################################
# set java path used by ec-tools
log_msg="*** SETTING JAVA PATH"
log_output
java_bin=$(which java)
java_path=$(readlink -f $java_bin)
echo $java_bin  $java_path
java_home=${java_path/'/bin/java'/''}
### set java home path
JAVA_HOME=$java_home
log_msg="*** JAVA_HOME set to  \"$java_home\""
log_output
$JAVA_HOME/bin/java -version

######################################
## prepare bundling

## packages needed anyways
log_msg=" Installing packages 'gdisk kpartx'"
log_output
sudo apt-get update
sudo apt-get install -y --force-yes gdisk kpartx.

#######################################
## check grub version, we need grub legacy
log_msg=" Installing grub verions 0.9x"
log_output
sudo grub-install --version
sudo apt-get install -y grub
grub_version=$(grub --version)
log_msg=" Grub version:$grub_version."
log_output

#######################################
### show boot cmdline parameter and adjust /boot/grub/menu.lst
log_msg=" Checking for boot parameters"
log_output
echo ""
log_msg=" Next line holds BOOT COMMAND LINE PARAMETERS:"
log_output
cat /proc/cmdline
cat /proc/cmdline >> $log_file
log_msg=" Next line holds KERNEL PARAMETERS in /boot/grub/menu.lst:"
log_output
set +euf
grep ^kernel /boot/grub/menu.lst
grep ^kernel /boot/grub/menu.lst >> $log_file
set -euf
echo
log_msg="If first entry differs from BOOT COMMAND LINE PARAMETER, please edit /boot/grub/menu.list "
log_output
echo -n "Do you want to edit /boot/grub/menu.list to reflect command line? [y|N]:"
read input
if  [[ "$input" == "y" ]]; then
    cat /boot/grub/menu.lst | sudo tee -a $log_file
    log_msg=" Editing /boot/grub/menu.lst"
    log_output
    sudo vi /boot/grub/menu.lst
    cat /boot/grub/menu.lst | sudo tee -a $log_file
fi

#######################################
### remove evi entries in /etc/fstab if exist
log_msg=" Checking for efi/uefi partitions in /etc/fstab"
log_output
set +euf
efi=$(grep -i efi /etc/fstab)
set -euf
if [[ "$efi" != "" ]]; then
  echo "Please delete these UEFI/EFI partition entries \"$efi\" in /etc/fstab"
  sleep 4
  cat /etc/fstab |sudo  tee -a $log_file # cat old /etc/fstab to log file
  log_msg=" Editing /etc/fstab"
  log_output
  sudo vi /etc/fstab
  cat /etc/fstab |sudo  tee -a $log_file # cat old /etc/fstab to log file
else
  log_msg=" Non UEFI/EFI partiton entries found in /etc/fstab."
  log_output
fi


#######################################
log_msg="
*** You can now run ./register-ebs.sh to copy $current_instance_id into an EBS AMI.
*** FINISHED TO PREPARE AMI $current_instance_id"
log_output
log_msg=" "
log_output
echo 
echo "Logfile of this run: $log_file "
echo 
