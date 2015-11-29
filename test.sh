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

DIR="${BASH_SOURCE/*}"
if [[ ! -d "$DIR" ]]; then DIR="$PWD"; fi

echo "i am $0"

echo "ME: $BASH_SOURCE"
