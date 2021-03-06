#!/bin/bash
#
# set variables in this file!
#
# Author: Michael Kloeckner
# Email:  mkl[at]im7[dot]de
# Date:   Sept 2015
#
######################################

## user input
declare input

## log message
declare log_msg

## date as YYYY-MM-DD-hh-mm-ss
date_fmt=$(date '+%F-%H-%M')

## exclude from bundle/snapshot jenkins home
jenkins_home="/var/lib/jenkins"

## bundle location
bundle_location="/mnt/ami-bundle/"

## bundle directory, should be on a partition with lots of space
## create a new directory for each bundle run
bundle_dir="$bundle_location/$date_fmt/"

## log directory we log one up bundle-dir
log_dir=$bundle_location

## we expect an EBS volume to be attached
## because we write unbundled image to this device
aws_snapshot_device=/dev/xvdi

## the id of the EBS volume to bundle this machine to
## should be attached to this machine under $aws_snapshot_device
aws_snapshot_volume_id=vol-365192d0

## the directory where we mount the $aws_ebs_device
## to check it
aws_snapshot_mount_point=/mnt/ami-snapshot

## needed commands
command_list="curl wget ruby unzip openssl java pv"

## services to stop/start while bundeling
services="jenkins rabbitmq-server redis-server jpdm revealcloud"

## AWS CREDENTIALS needed, those are tested
aws_credentials="aws_access_key_id aws_access_secret_key aws_account_id"

## X509 file path
aws_cert_path="/tmp/x509-cert.pem"
aws_pk_path="/tmp/x509-pk.pem"

## project as prefix
project="jenkins"

# EC2 install dir
ec2_prefix="/usr/local/ec2/"

## we assume x86_64
aws_architecture="x86_64"

######################################
# These Things get set by the machine
######################################

# aws availability zone and region
aws_avail_zone=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone/)
aws_region=${aws_avail_zone::-1}

# AMI and Instance ID we are bundling (This one!)
current_ami_id=$(curl -s http://169.254.169.254/latest/meta-data/ami-id)
current_instance_id=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
