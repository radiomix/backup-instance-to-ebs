#!/bin/bash
# Bundle Instance backed AMI, which was configured, to be registered as a new EBS backed AMI
#  http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/creating-an-ami-instance-store.htm
#
# Prerequisite:
#    THE FOLLOWING IS USUMED:
#   - X509-cert-key-file.pem on this machine under: /tmp/cert/
#   - X509-pk-key-file.pem on this machine assuming under: /tmp/cert/
#   - AWS_ACCESS_KEY, AWS_SECRET_KEY and AWS_ACCOUNT_ID is known to the caller 
#   - AWS API/AMI tools installed under /user/local/ec2 and in $PATH
#   - JAVA installed
#   - Package kpart and gdisk are installed
#   - Package grub is of version <= 0.97
########## ALL THIS IS DONE BY SCRIPT prepare-aws-tools.sh ###################
#   - we need the instance ID we want to convert $as aws_instance_id
#   - some commands need sudo rights
# What we do
#   - install grub legacy version 0.9x or smaller
#   - install gdisk, kpartx to partition
#   - adjust kernel command line parameters in /boot/grub/menu.lst
#   - bundle the AMI locally (is there enough space on this machine?)
#   - upload the AMI
#   - register the AMI
#   - delete the local bundle

#######################################
## config variables
cwd=$(pwd)

## read functions and config
source $(dirname $0)/functions.sh
source $(dirname $0)/config.sh
set -euf
set -o pipefail

start_logging

## check config var $command_list or exit
check_commands

## check java/ec2 tools
check_ec2_tools

######################################
## aws credentials
set_aws_credentials
check_aws_credentials
set_aws_x509_path



# ami descriptions and ami name
aws_ami_description="$project $current_instance_id of $date_fmt "
aws_ami_name="$project-bundle-instance-$date_fmt"

# image file prefix
prefix="bundle-instance-"$date_fmt

# access key from env variable, needed for authentification
aws_access_key=$AWS_ACCESS_KEY

# secrete key from env variable, needed for authentification
aws_secret_key=$AWS_SECRET_KEY

# descriptions
aws_snapshot_description="$project AMI: "$current_instance_id", Snapshot to register new EBS AMI"

## services to stop/start while bundeling
services="jenkins rabbitmq-server redis-server jpdm revealcloud"
log_msg=" These services will stop/start during bundle process:\"$service\""

## end config variables
######################################

#######################################
### what virtualization type are we?
### we check curl -s http://169.254.169.254/latest/meta-data/profile/
### returning [default-paravirtual|default-hvm]
meta_data_profile=$(curl -s http://169.254.169.254/latest/meta-data/profile/ | grep "default-")
profile=${meta_data_profile##default-}
### used in ec2-bundle-volume
virtual_type="--virtualization-type "$profile" "

echo "*** Found virtualization type $profile"
## on paravirtual AMI every thing is fine here
partition=""
## for hvm AMI we set partition mbr
if  [[ "$profile" == "hvm" ]]; then
  partition="  --partition mbr "
fi

#######################################
### do we need --block-device-mapping for ec2-bundle-volume ?
echo -n "Do you want to bundle with parameter \"--block-device-mapping \"? [y|N]:"
read blockDevice
if  [[ "$blockDevice" == "y" ]]; then
  echo "Root device is set to \"$root_device\". Select root device [xvda|sda] in device mapping:[x|S]"
  read blockDevice
  if  [[ "$blockDevice" == "x" ]]; then
    blockDevice="  --block-device-mapping ami=xvda,root=/dev/xvda1 "
  else
    blockDevice="  --block-device-mapping ami=sda,root=/dev/sda1 "
  fi
else
    blockDevice=""
fi
#######################################
## check if mount point exists
if [[ ! -d $aws_ebs_mount_point ]]; then
  sudo mkdir $aws_ebs_mount_point
fi
result=$(sudo test -w $aws_ebs_mount_point && echo yes)
if [[ $result != yes ]]; then
  log_msg=" ERROR: directory $aws_ebs_mount_point to mount the image is not writable!! "
  log_output
  exit -12
fi
log_msg=" Checking EBS mount point $aws_ebs_mount_point OK"
log_output

#######################################
## check EBS Volume
set +euf
input=$(lsblk | grep aws_ebs_device)
set +euf
if [[ "$inpu" == "" ]]; then
  log_msg=" ERROR: No volume attached to device $aws_ebs_device !! "
  log_output
  exit -12
fi
log_msg=" Checking EBS volume $aws_ebs_device OK
*** $input"
log_output

#######################################
log_msg="
***
*** Using AWS_ACCESS_KEY:   \"$aws_access_key\"
*** Using AWS_ACCOUNT_ID:   \"$aws_account_id\"
*** Using AWS_REGION:       \"$aws_region\"
*** Using AWS_ARCHITECTURE: \"$aws_architecture\"
*** Using x509-cert.pem \"$AWS_CERT_PATH\"
*** Using x509-pk.pem \"$AWS_PK_PATH\""
log_output

ec2_api_version=$(sudo -E $EC2_HOME/bin/ec2-version)
input=$(sudo -E $EC2_AMITOOL_HOME/bin/ec2-ami-tools-versio)
ec2_ami_version=${input:16:0}
log_msg="***
*** Using partition:$partition
*** Using virtual_type:$virtual_type
*** Using block_device:$blockDevice
*** Using EC2 API version:$ec2_api_version
*** Using EC2 AMI TOOL version:$ec2_ami_version
*** Using device:$aws_ebs_device to copy the unbundled image to
*** Using mount point:$aws_ebs_mount_point to mount the unbundled image
*** Logging into file: \"$log_file\""
log_output
sleep 3
start=$SECONDS

#################################################################################
echo -n "Do you want to bundle with these parameters?[y|N]"
read input
if [[ "$input" == "y" ]]; then
  log_msg=" Aborting bundle proccess due to user input. EXIT"
  log_output
  exit -999
else
  log_msg=" Starting bundle proccess due to user input. "
  log_output
fi
#################################################################################

#######################################
log_msg=" Bundleing AMI, this may take several minutes "
log_output
log_msg="sudo -E $EC2_AMITOOL_HOME/bin/ec2-bundle-vol -k $AWS_PK_PATH -c $AWS_CERT_PATH -u $AWS_ACCOUNT_ID -r x86_64 -e /tmp/cert/ -d $bundle_dir -p $prefix  $blockDevice $partition --no-filter --batch"
log_output
sleep 2

## start services
start_stop_command=start
start_stop_service

export AWS_MANIFEST=$prefix.manifest.xml

## manifest of the bundled AMI
manifest=$AWS_MANIFEST

## get the kernel image (aki) 
source select_pvgrub_kernel.sh
echo "*** Using kernel:$AWS_KERNEL"

## profiling
end=$SECONDS
period=$(($end - $start))
log_msg="***  
*** PARAMETER USED:
*** Root device:$root_device
*** Grub version:$(grub --version)
*** Bundle folder:$bundle_dir
*** Block device mapping:$blockDevice
*** Partition flag:$partition
*** Virtualization:$virtual_type
*** Manifest:$prefix.manifest.xml
*** Region:$aws_region
***
*** Bundled AMI:$current_instance_id of AMI:$current_ami_id in $period seconds"
log_output

######################################
## extract image name and copy image to EBS volume
image=${manifest/.manifest.xml/""}
size=$(du -sb $bundle_dir/$image | cut -f 1)
log_msg=" Copying $bundle_dir/$image of size $size to $aws_ebs_device.
***  This may take several minutes!"
log_output
#sudo dd if=$bundle_dir/$image of=$aws_ebs_device bs=1M
size=$(du -sb $bundle_dir/$image | cut -f 1)
sudo dd if=$bundle_dir/$image | pv -s $size | sudo dd of=$aws_ebs_device bs=1M

log_msg="*** Checking partition $aws_ebs_device"
log_output
sudo partprobe $aws_ebs_device

######################################
## check /etc/fstab on EBS volume
## mount EBS volume
sudo mount -o rw $aws_ebs_device $aws_ebs_mount_point
## edit /etc/fstab to remove ephimeral partitions
ephimeral=$(grep ephimeral $aws_ebs_mount_point/etc/fstab)
if [[ "$ephimeral" != "" ]]; then
    echo "Edit $aws_ebs_mount_point/etc/fstab to remove ephimeral partitions"
    sleep 5
    sudo vi $aws_ebs_mount_point/etc/fstab
fi
# unmount EBS volume
sudo umount $aws_ebs_device

#######################################
## create a snapshot and verify it
log_msg=" Creating Snapshot from Volume:$aws_bundle_volume_id.
 This may take several minutes"
log_output
log_msg=$($EC2_HOME/bin/ec2-create-snapshot $aws_bundle_volume_id --region $aws_region -d "$aws_snapshot_description" -O $AWS_ACCESS_KEY -W $AWS_SECRET_KEY )
aws_snapshot_id=$(echo $log_msg| cut -d ' ' -f 2)
log_output
echo -n "*** Using snapshot:$aws_snapshot_id. Waiting to become ready . "

#######################################
## wait until snapshot is compleeted
completed=""
while [[ "$completed" == "" ]]
do
    completed=$($EC2_HOME/bin/ec2-describe-snapshots $aws_snapshot_id --region $aws_region | grep completed)
    echo -n ". "
    sleep 3
done
echo ""
log_msg=$($EC2_HOME/bin/ec2-describe-snapshots $aws_snapshot_id --region $aws_region | grep completed)
log_output

#######################################
## register a new AMI from the snapshot
output=$($EC2_HOME/bin/ec2-register -O $AWS_ACCESS_KEY -W $AWS_SECRET_KEY --region $aws_region -n "$aws_ami_name" -s $aws_snapshot_id -a $AWS_ARCHITECTURE --kernel $AWS_KERNEL)
echo $output
echo $output >> $log_file
aws_registerd_ami_id=$(echo $output | cut -d ' ' -f 2)
output=$($EC2_HOME/bin/ec2-create-tags $aws_registerd_ami_id --region $aws_region --tag Name="$aws_ami_description" --tag Project=$project)
log_msg=" Registerd new AMI:$aws_registerd_ami_id"
log_output

######################################
## unmount and detach EBS volume
log_msg=" Detaching EBS Volume:$aws_bundle_volume_id"
log_output
$EC2_HOME/bin/ec2-detach-volume $aws_bundle_volume_id --region $aws_region -O $AWS_ACCESS_KEY -W $AWS_SECRET_KEY

#######################################
cd $cwd
log_msg=" Finished! Created AMI: $aws_registerd_ami_id ***"
log_output
date >> $log_file

