#!/bin/bash

#variables
source ./deploy-common.conf #Reads common variables between deploy.sh and wrapper.sh
log_verbose=1 		#whether or not to display output on terminal screen
log=/var/log/bitlancer-wrapper.log #logfile name
model="" 		#passed from strings
model_name="" 		#passed from Strings
server_list="" 		#passed from Strings
server_array=""		#Used to parse server list
server_hostname=""	#used in building command list
server_role=""		#used in building command list
server_profile=""       #used in building command list
cloud_files_credentials="" #passed from Strings
repo="" 		#passed from Strings
reposhort=""$(basename ${repo%.*})
ref="" 			#passed from Strings
validate_count=0 	#Used for validating switches
validate_string=""	#Used for validation switches
validate_param="" 	#Used for obtaining valid switches parameters
validate_success=0 	#Switch to check status of switch validity
validate_var="" 	#variable to set in script from Strings variables
OFS=$(echo $IFS)

#sourcing our models
source ./*.model #functions that build an application model
#sourcing check_model function to keep this script modular
source ./models.case



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
  #Used to grab the valid switch's parameter string
  log_string=$validate_param
  logger
  eval $validate_var='$validate_param'
  log_string="validate_var set to $validate_var"
  logger
  eval log_string=\${"${validate_var}"}
  logger
  echo
}

function validate_input {
  #Used to validate the switches coming from Strings against recognized options
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
                               validate_success=$((validate_success +1))                                                 ;;
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


function role_check {
  #Checks to see what role we're using and determines what work to do
  case "$server_role" in
    "Drupal 7 Web Server") log_string="Role is: $server_role"
                           logger
                           ;;
    "Primary MySQL Server") log_string="Role is: $server_role"
                            logger 
                            ;;
  esac
}

function check_profile () {
  #Checks to see what profiles we're using and determines what work to do
  server_profile="$1"
  echo "Checking Profile: $server_profile"
  case "$server_profile" in
    "Apache Web Server") log_string="Profile is: $server_profile"
                         logger
                         ;;
    "Base Node") log_string="Profile is: $server_profile"
                 logger
                 ;;
    "MySQL Server") log_string="Profile is: $server_profile"
                    logger
                    ;;
    *) log_string="Unrecognized Server Profile Name specified: $server_profile"
       logger
       exit 1 
         ;;
  esac
}

function create_tarball {
  #packages our repository and data for deployment
  
    #if repo switch and cloudfiles we need to combine and then tar
    
    tar -zcvf $gitrepohome$ref/$model_name.tar.gz $gitrepohome$ref/$reposhort
}

function parse_serverlist {
  #Reads server_list string and starts doing work
  IFS=';' #changed the internal field selector to 
  read -ra single_server_list <<< "$server_list"
  for i in "${single_server_list[@]}"; do
    log_string="single_server_list is: $i"
    logger
    #do work on single_server_list now that we have it
    IFS=',' #changed the internal field separator to split on comma
    read -ra item <<< "$i"  #created an array for the single_server_list items
    log_string="List by array index"
    logger
    log_string="${item[0]}"  #hostname
    logger
    log_string="${item[1]}"  #role
    logger
    log_string="${item[2]}"  #profile 1
    logger
    log_string="${item[3]}"  #profile 2
    logger
    check_profile "${item[2]}"
    #put some logic now that we have a profile and model to deploy
      #run the models profile command structure
      eval `echo "$model_name" | tr -d ' '`_`echo "$server_profile" | tr -d ' '` #this launches the .model function
    check_profile "${item[3]}"
    #put some logic now that we have a profile and model to deploy
    eval `echo "$model_name" | tr -d ' '`_`echo "$server_profile" | tr -d ' '` #this launches the .model function
    
    
  done
}


#Start Logging
log_string="--------------------------------------------------"
logger
echo >> $log
log_string="Work Received on: `date`"
logger

#Read in Variables from Strings
  #12 possible parameters
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
       #reset to 0 so loop works
       validate_success=0
    fi
  done

#set the repo shortname now that we read in variables a req't of deploy.sh GitConf func.
reposhort=$(basename ${repo%.*})
check_model #this is in models.case file and sourced at runtime
#Pull in git repo provided
../deploy.sh -c -g "$repo" -r "$reposhort" -R $ref
#wait for it
wait $!
if [[ $? -eq 0 ]]
then
    log_string="Downloaded git repository."
    logger
else
    log_string="Download of git repository failed."
    logger
    exit 5
fi
create_tarball
parse_serverlist

#Download Strings-Deploy-Toolkit from github
   #Things we need
     #temp storage spot
     #credentials or key
     #repository address


#Download Project files from gitrepo provided with deploy
   #Things we need
     #temp storage spot
     #repository address 
     #credentials or key

#Create a Payload
   #Things we need
     #temp storage spots of the strings-deploy-toolkit and application files
     #place the files together in a project path
     #tarball up the path

#Build Command List
  #function build_servers_command
   #parse server list while loop
   #write commands to a tempfile  
     #grab the log file off of the server when done
     #example: ssh root@servername 'bash -s' < commandlist.sh
     #/path/to/deploy.sh -f -g <gitrepovar> -l <path to land>

#Execute Commands against Server List
  #we need to know what the run user will be on the remote systems
  #run the command list
  #collect return code and report to log
    #greater than 0 is error in our case I have specific error codes in deploy.sh that could let us know more.

#Set the internal field separator back to what it was when we started
IFS=$OFS
echo "Set internal field separator back to: $IFS"

#Exit Clean
exit 0
