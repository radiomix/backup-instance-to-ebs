
1.2.1 / 2015-10-19 
==================

 * adopt AWS credential names

1.2.0 / 2015-10-16 
==================

 * fix typo
 * use different parameter to convert hvm/paravirtual instances
 * delete output 'upload x509 files', not needed in AWS console

1.1.2 / 2015-10-16 
==================

 * use different parameter to convert hvm/paravirtual instances
 * delete output 'upload x509 files', not needed in AWS console

1.1.1 / 2015-10-16 
==================

 * sudo mount
 * sudo fsck, attach volume and wait until it is attached
 * docu update
 * pretty print output

1.1.0 / 2015-10-15 
==================

 * pretty print output
 * fix typo for X509 file variables
 * add converted AMI ids


1.0.4 / 2015-10-15 
==================

 * prevent user input in register-ebs.sh, mv file creation to prepare step
 * create function to generate x509 files, simple file check for x509 files
 * check aws credentials and create x509 files in prepare-instance.sh
 * add variables for x509 files
