#!/bin/bash
#
# collect functions in this file!
#
# Author: Michael Kloeckner
# Email:  mkl[at]im7[dot]de
# Date:   Sept 2015
#

######################################
## checks config var $aws_credentials
check_aws_credentials(){
#declare credentials
for credential in ${aws_credentials}; do
found=0
set +euf
  val=$(env | grep $credential| cut -d '=' -f 2)
set +euf
  if [[ "$val" == "" ]]; then
    found=1
    log_msg=" ERROR Variable $credential not set! EXIT!"
    log_output
  else
    log_msg=" Variable $credential set!"
    log_output
  fi
done
if [[ "$found" == "1" ]]; then
    exit -30
fi
## disguise user input
aws_access_key=${AWS_ACCESS_KEY:0:3}********${AWS_ACCESS_KEY:${#AWS_ACCESS_KEY}-3:3}
aws_account_id=${AWS_ACCOUNT_ID:0:3}********${AWS_ACCOUNT_ID:${#AWS_ACCOUNT_ID}-3:3}
}

######################################
## sets config var $aws_credentials
set_aws_credentials(){
for credential in ${aws_credentials}; do
  echo -n "Enter your $credential:"
  read val
  eval "export $credential=\"$val\""
  #eval "$credential=\"$val\""
done
}

######################################
## x509-pd/cert file path.
set_aws_x509_path(){
log_msg=" We expect the x509 certificate"
log_output

if [[ "$AWS_CERT_PATH" == "" ]]; then
  echo -n "Enter /path/to/x509-cert.pem: "
  read input
  if [ ! -f "$input"  ]; then
    log_msg=" ERROR: AWS X509 CERT FILE:$input NOT FOUND!"
    log_output
    exit -20
  fi
  export AWS_CERT_PATH=$input
  #AWS_CERT_PATH=$input
fi

if [[ "$AWS_PK_PATH" == "" ]]; then
  echo -n "Enter /path/to/x509-pk.pem: "
  read input
  if [  ! -f "$input" ]; then
    error_msg=" ERROR: AWS X509 PK FILE:$input NOT FOUND!"
    echo "$error_msg"
    exit
  fi
  export AWS_PK_PATH=$input
  #AWS_PK_PATH=$input
fi

}

######################################
## check if these commands in $command_list
## are present or exit
check_commands(){
for command in ${command_list}; do
found=0
  set +euf
  bin=$(which $command)
  set -euf
  if [[ "$bin" == "" ]]; then
    found=1
    log_msg=" ERROR: Command \"$command\" not found! Please install \"$command\"! "
    log_output
  else
    log_msg=" Found command \"$command\" OK!"
    log_output
  fi
done
if [[ "$found" == "1" ]]; then
    exit -10
fi
}

######################################
## set JAVA_HOME and EC2 in PATH
check_ec2_tools(){
  ######################################
  # set java path used by ec-tools
  log_msg=" *** SETTING JAVA PATH"
  log_output
  java_bin=$(which java)
  java_path=$(readlink -f $java_bin)
  echo $java_bin  $java_path
  java_home=${java_path/'/bin/java'/''}
  ### set java home path
  export JAVA_HOME=$java_home
  log_mesg=" JAVA_HOME set to  \"$java_home\""
  log_output
  $JAVA_HOME/bin/java -version
  
  ######################################
  ## put EC2 install path in $PATH..
  ## we expect EC2 to be installed under /usr/local/ec2
  log_msg=" Checking AWS TOOL PATH in $ec2_prefix"
  log_output

  ami_tool=$(ls $ec2_prefix | grep ami)
  api_tool=$(ls $ec2_prefix | grep api)

  export EC2_AMITOOL_HOME=$ec2_prefix$ami_tool
  export EC2_HOME=$ec2_prefix$api_tool
  PATH=$EC2_AMITOOL_HOME/bin:$EC2_HOME/bin:$PATH

  ### check if sudo ec2-path is ok:
  sudo -E $EC2_HOME/bin/ec2-version
  sudo -E $EC2_AMITOOL_HOME/bin/ec2-ami-tools-version

  log_msg=" EC2_HOME installed to \"$EC2_HOME\"
*** EC2_AMITOOL_HOME installed to \"$EC2_AMITOOL_HOME\""
  log_output
return
}

######################################
## write $log_msg to stdout and to $log_file
log_output(){
  log_message="[$(date)]$log_msg"
	echo "$log_message"
	echo "$log_message" >> $log_file
}

######################################
## prepare log file with some messages
## we log in $bundle_dir, attach date
## to caller script name e.g.: prepare-instance-2015-09-22-23-55-59.log
start_logging(){
  # check if log file directory is writable
  if [[ ! -d $bundle_dir ]]; then
      sudo mkdir -p $bundle_dir
  fi
  result=$(sudo test -w $bundle_dir && echo yes)
  if [[ $result != yes ]]; then
    log_msg=" ERROR: Directory $bundle_dir to bundle the image is not writable by user root!! "
    log_output
    exit -3
  fi
  # log file
  base=$(basename $0)
  caller=${base::-3}
  log_file=$log_dir$caller"-"$date_fmt.log
  echo "Logging to file $log_file" && sleep 2
  sudo touch $log_file
  sudo chown $(whoami) $log_file
  date >> $log_file
  log_msg=" Script called by user "$(whoami)
  log_output
}

######################################
## let user reset services to be
## stopped/started during bundle proces
set_start_stop_servie(){
  log_msg=" These services can be stopped during bundling:
 \"$services\""
  log_output
  echo -n "Do you want to stop services \"$services\" [n|Y]".
  read input
  if [[ "$input" == "n" ]];then
    log_msg="You can type in services you want to stop, each seperated by white space."
    log_output
    echo -n "Please type the services that you want to stop:"
    read services
    log_msg=" These services will be stopped during bundling:
 \"$services\""
  log_output
  fi
}

######################################
## start/stop every service in $services
## according to $start_stop_command
start_stop_service(){
	for daemon in ${services[*]}; do
		sudo service  $daemon $start_stop_command
	done
}
