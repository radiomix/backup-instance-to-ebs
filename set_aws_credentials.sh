#!/bin/bash
#
# Set AWS credentials in this file!
#   We source this file in the calling sripts
#   to exports aws credentials to them:
#   Calling scripts:
#        - prepare-instance.sh
#        - register-ebs.sh
#
# Author: Michael Kloeckner
# Email:  mkl[at]im7[dot]de
# Date:   Dec 2015
#



######################################
## checks credentials
check_aws_credentials
