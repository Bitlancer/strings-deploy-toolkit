#!/bin/bash

#variables
log_verbose=1
log=/var/log/bitlancer-wrapper.log
model=""
model_name=""
server_list=""
host=""
cloud_files_credentials=""
repo=""
ref=""
validate_count=0
validate_string=""
validate_param=""
validate_success=0
validate_var=""

#Functions
function logger {
  #Used for verbose logging to console as well as logging to files.
  if [ $log_verbose -eq 1 ]
  then
     #Echo out to the console as well as write to the log file.
     echo $log_string >> $log
     echo $log_string
     #clear log_string for next instantiation
     log_string=""
  else
     #Write out to the log only.
     echo $log_string >> $log
     #clear log_string for next instantiation
     log_string=""
  fi
}

function get_parameter {
  log_string=$validate_param
  logger
  eval $validate_var=$validate_param
  log_string="validate_var set to $validate_var"
  logger
  eval log_string=\${$validate_var}
  logger
  echo
}

function validate_input {
  log_string="Validating"
  logger
  log_string="Switch $validate_string provided"
  logger
  case "$validate_string" in
    --model) log_string="model"
             logger
             validate_var="model"
             validate_count=$((validate_count +1))
             validate_success=$((validate_success +1))
             ;;
    --model-name) log_string="model-name"
                  logger
                  validate_var="model_name"
                  validate_count=$((validate_count +1))
                  validate_success=$((validate_success +1))
                  ;;
    --server-list) log_string="server-list"
                   logger
                   validate_var="server_list"
                   validate_count=$((validate_count +1))
                   validate_success=$((validate_success +1))
                   ;;
    --cloud-files-credentials) log_string="cloud-files-credentials"
                               logger
                               validate_var="cloud_files_credentials"
                               validate_count=$((validate_count +1))
                               validate_success=$((validate_success +1))                              
                               ;;
    --repo) log_string="repo"
            logger
            validate_var="repo"
            validate_count=$((validate_count +1))
            validate_success=$((validate_success +1))
            ;;
    --ref) log_string="ref"
           logger
           validate_var="ref"
           validate_count=$((validate_count +1))
           validate_success=$((validate_success +1))
           echo $validate_count
          ;;
    *) log_string="Unknown Switch"
       logger
       validate_count=$((validate_count +1))
       ;;
  esac

  #if [[ $validate_string == "--model" ]]
  #then
  #   echo "model"
  #else
  #   echo "invalid switch $validate_string"
  #fi   
}


#Start Logging
log_string="--------------------------------------------------"
logger
echo >> $log
log_string="Work Received on: `date`"
logger

while [ $validate_count -lt 11 ]; do
  validate_count=$((validate_count +1))
  eval validate_string=\${$validate_count}
  validate_input
  if [[ validate_success -eq 0 ]]
  then
      echo "You hit me with a bad bad switch"
  else
     eval validate_param=\${$validate_count}
     get_parameter
     validate_success=0
  fi

done

#Exiting Clean
exit 0
