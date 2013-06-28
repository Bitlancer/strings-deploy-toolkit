#!/bin/bash


#variables
log="/var/log/bitlancer-deploy.log" #log path
host="" #used for deploying to a host or many hosts
gitrepo=""
giturl=""
gitclone=0
oscontainer="" #openstack/rackspace storage container
osuser=""
oskey=""
osauthurl=""
ospath=""
gitrepobranch=""
gitrepobranchflag=0
gitversion=$(git --version)
gitbinpath=$(which git)
gitcurrentbranch=""
log_string=""
log_verbose=0
PullSelectorFlag=0 #used with getopts cases.  We check this later for 1 or 0
ConfSelectorFlag=0 #used with getopts cases.  We check this later for 1 or 0
gitrepoflag=0 #used with getopts cases. We check this later for 1 or 0 with PullSelector and ConfSelector fucntions.
gitbranchflag=0 #used with getopts cases. We check this later for 1 or 0 with PullSelector and ConfSelector fucntions.
giturlflag=0 #used with getopts cases. We check this later for 1 or 0 with PullSelector and ConfSelector fucntions.
ConfSelGit=0 #Set by ConfSelector function.  Used for configuring git repos.
ConfSelSwift=0 #Set by ConfSelector function.  Used for configuring swift containers.
PullSelGit=0 #Set by PullSelector function.  Used for pulling git repos.
PullSelSwift=0 #Set by PullSelector function. Used for pulling swift containers.
gitremoteexist=0 #Set by GitRemoteCheck function. Used in various places as a verification mechanism.
dirpath="" #Needs to be set by directory check functions for use with CreateDir function
dirsuccess=0 #Set by CreateDir function and used for verification in GitConf and SwiftConf.
gitrepohome=~/deploy/repodata/ #Where working repos live.
datahome=~/deploy/osdata/ #Where cached openstack swift/cloud files live.
landinghome="/var/www/html/" #Where you want the data to land; if using virtual hosts specify -l and the path on the command line
scriptdebugflag=0
operationsuccess=0
operationfail=0

#Setup Logging
  echo "------------------------------------------------------------------------------------------" >> $log #run separator
  date >> $log

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

#Script Usage output function.  Use this to spit out a canned response on how to use this script.
function script_usage {
  echo "Script Usage:"
  echo "deploy.sh <option> <argument>"
  echo "Global Script Options:"
  echo "-e Debug Mode"
  echo "-v Verbose: Provides status in console."
  echo
  echo "Git Usage:"
  echo "  Cloning a git repository and deploying to your landing directory:"
  echo "  deploy.sh -f -g <arg> [-b <arg> -l <arg>]"
  echo "  Configuring git for storing of repository:"
  echo "  deploy.sh -c -g <arg> -r <arg>"
  echo "  See Git Related Options for further details."
  echo "  Updating code with git remote repository after configuration:"
  echo "  deploy.sh -p -r <arg> (-b <arg> optional)"
  echo "  See Git Related Options for further details."
  echo "Git Related Options:"
  echo "-f Completes a full git clone (-g required (-b -l optional))"
  echo "-c Configures git (-g -r required)"
  echo "-p Pulls git repository (-r required)"
  echo "-r <Git Repository/Project Shortname>"
  echo "-g <Git HTTPS/SSH URL>"
  echo "-b <Git Repository Branch>"
  echo "-h <host> or \"<host(s)>\" <--Multiple hosts must be within quotes and separated by spaces"
  echo
  echo
  echo "Global Script Options:"
  echo "-e Debug Mode"
  echo "-v Verbose: Provides status in console."
  echo "-L <landing path> Final destination of your repository code/files. Default is /var/www/html/.  This will override default."
  }  

function script_debug {
#Debugging.  Use this to obtain some debugging information from the script. Activated by -d flag. 
#spits all the varible values into the log and if verbose is selected it will spit to the console.
#add this before exits in functions or anywhere that you want to obtain more information on script processing.
if [ $scriptdebugflag -eq 1 ]
then
   log_string="log=$log"
   logger
   log_string="host=$host"
   logger
   log_string="gitrepo=$gitrepo="
   logger
   log_string="giturl=$giturl"
   logger
   log_string="gitclone=$gitclone"
   logger
   log_string="oscontainer=$oscontainer"
   logger
   log_string="osuser=$osuser="
   logger
   log_string="oskey=$oskey"
   logger
   log_string="osauthurl=$osauthurl"
   logger
   log_string="ospath=$ospath"
   logger
   log_string="gitrepobranch=$gitrepobranch"
   logger
   log_string="gitrepobranchflag=$gitrepobranchflag"
   logger
   log_string="gitversion=$gitversion"
   logger
   log_string="gitbinpath=$gitbinpath"
   logger
   log_string="gitcurrentbranch=$gitcurrentbranch"
   logger
   log_string="log_verbose=$log_verbose"
   logger
   log_string="PullSelectorFlag=$PullSelectorFlag"
   logger
   log_string="ConfSelectorFlag=$ConfSelectorFlag"
   logger
   log_string="gitrepoflag=$gitrepoflag"
   logger
   log_string="gitbranchflag=$gitbranchflag"
   logger
   log_string="giturlflag=$giturlflag"
   logger
   log_string="ConfSelGit=$ConfSelGit"
   logger
   log_string="ConfSelSwift=$ConfSelSwift"
   logger
   log_string="PullSelGit=$PullSelGit"
   logger
   log_string="PullSelSwift=$PullSelSwift"
   logger
   log_string="gitremoteexist=$gitremoteexist"
   logger
   log_string="dirpath=$dirpath"
   logger
   log_string="dirsuccess=$dirsuccess"
   logger
   log_string="gitrepohome=$gitrepohome"
   logger
   log_string="datahome=$datahome"
   logger
   log_string="landinghome=$landinghome"
   logger
   log_string="scriptdebugflag=$scriptdebugflag"
   logger
   log_string="operationsuccess=$operationsuccess"
   logger
   log_string="operationfail=$operationfail"
   logger
fi
}

function GitExistCheck {
#Checks that git is installed and at a good version (if we want to go that far.)
  if [[ $gitversion != *git* ]]
  then
     #We could do an install of git here if desired
     log_string="Error: Git not installed"
     logger
     exit 1
  fi
}

function GitRepoHomeCheck {
#checks to see if the gitrepohome exists
if [ -d $gitrepohome ]
then
   log_string="Repository home: $gitrepohome exists."
   logger
else
   log_string="Repository home: $gitrepohome does not exist."
   logger
   #create the directory
   dirpath=${gitrepohome}
   CreateDir   
fi
}

function GitBranchCheck {
#Checks what the current branch is set to by setting variable gitcurrentbranch to the value.
gitcurrentbranch=$(git rev-parse --abbrev-ref HEAD)
 log_string="Current git working branch is: $gitcurrentbranch."
 logger
}

function GitBranchChange {
#Changes Branches based on user's input and current selected branch.
log_string="Attempting to change git working branch."
logger
if [ -z $gitrepobranch ]
then 
   log_string="Git working branch not specified, assuming master."
   logger
   gitrepobranch="master"
fi
if [[ $gitrepobranch != $gitcurrentbranch ]]
then
   log_string="The current branch $gitcurrentbranch is not set to the desired working branch $gitrepobranch."
   logger
   log_string="Changing branch from $gitcurrentbranch to $gitrepobranch."
   logger
   git checkout $gitrepobranch 2>&1>>$log
   if [ $? -eq 0 ]
      then
         GitBranchCheck
      else
         log_string="Branch change failed."
         logger
         exit 1
   fi
else
   log_string="No need to change branches, master already active."
   logger
fi
}

function CreateDir {
#creates a new directory and verifies.
   log_string="Creating missing directory."
   logger
   mkdir -p $dirpath 2>&1>>$log
   if [ $? -eq 0 ]
   then
      log_string="Directory created."
      logger
      dirsuccess=1
   else
      log_string="Directory failed to be created.  Check directory permissions."
      logger
      dirsuccess=0
   fi
}

function GitRemoteCheck {
#Checks for the existance of a repository based on the gitrepo passed from the user.
log_string="Checking for specified repository."
logger
#Check for presence of the repository directory
if [ -d "$gitrepohome$gitrepo" ]
then
   log_string="A directory exists with the name $gitrepohome$gitrepo."
   logger
   #turn on gitremoteexist variable based on results.
   gitremoteexist=2
else
   gitremoteexist=0
fi
#Check for git remote, verify 2 otherwise we have no way to check for existance of the remote from the git conf
if [ $gitremoteexist -eq 2 ]
then
   log_string="Checking for existing git remote."
   logger
   cd $gitrepohome$gitrepo
   git remote | grep $gitrepo 2>&1>>$log
   if [ $? -eq 0 ]
   then 
      log_string="git remote shortname exists."
      logger
      #turn on gitremoteexist variable based on results
      gitremoteexist=$((gitremoteexist + 1))
   else
      log_string="git remote shortname not detected."
   fi
else
   log_string="No directory exists with the specified git shortname, and therefore unable to read project's git configurtion to search for specified remote."
   logger
fi
}

function LandingHomeCheck {
#checks for valid landinghome
log_string="Checking for landing path $landinghome"
logger
if [ -d $landinghome ]
then
   log_string="landing path exists."
   logger
else
   #we could choose to just create the path instead
   log_string="landing path does not exist."
   logger
   exit 1
fi
}

function CodeMove {
#Takes pulled code from Git and moves into proper web directory
log_string="Attempting to move code into place."
logger
#Check that the landinghome exists
LandingHomeCheck
#move code from repodir to live landing dir
rsync -av --progress $gitrepohome$gitrepo/* $landinghome --exclude .git 2>&1>>$log
#Check if it went well
if [ $? -eq 0 ]
then
   log_string="Moved code into place."
   logger
   operationsuccess=$((operationsuccess + 1))
else
   log_string="Failed to move code into place."
   logger
   operationfail=$((operationfail + 1))
fi
}

function DataMove {
#Takes pulled data from Swift and moves into proper web directory
echo
#move code from cacheddir to landing dir
}


function GitConf {
if [ $ConfSelGit -eq 1 ]
then
  log_string="Configuring Git..."
  logger
  #Change to the gitrepohome directory
  cd $gitrepohome
  pwd 2>&1>>$log
  #Clone the repo
  log_string="Configuring Git..."
  logger
  #Change to the gitrepohome directory
  cd $gitrepohome
  #Clone the repo
  git clone $giturl 2>&1>>$log &
  #wait for it
  wait $!
  #Validate successful clone
  if [ $? -eq 0 ]
  then
      #Set permissions on the new directory
      chmod 755 $gitrepohome$gitrepo 2>&1>>$log
      #Change to the new directory
      cd $gitrepohome$gitrepo
      #Change the repo name from origin to match the project name - will keep systems with many repos from getting confusing
      log_string="Changing origin to match the project name"
      logger
      git remote rename origin $gitrepo 2>&1>>$log
      #Re-check that the repo was created; for verification that work was completed properly
  else
      log_string="git clone returned non zero exit code."
      logger
  fi
  GitRemoteCheck
  #Check for a 3 which means the directory and remote both exist matching the specified reponame
  if [ $gitremoteexist -eq 3 ]
  then
      log_string="Configured new git repository $gitrepo successfully."
      logger
      #increment operationsuccess if successful
      operationsuccess=$((operationsuccess + 1))
      #Shut off the configuration selector for git so we don't try and re-configure
      ConfSelGit=0
  else
      log_string="Failed to configure git repository $gitrepo."
      logger
      operationfail=$((operationfail +1))
  fi
else
   log_string="Git configuration was not qualified.  Check $log for more details."
   logger
fi
}


function GitPull {
#Pulls Git repo from remote to local repo. Checks that the repo and branch exist locally.
if [ $PullSelGit -eq 1 ]
then
   #change to the proper repo dir
   cd $gitrepohome$gitrepo
   #change to user specified branch; master assumed on null
   GitBranchChange
   #Pull in the code
   git pull $gitrepo $gitrepobranch 2>&1>>$log &
   #wait for it
   wait $!
   #Validate pull
   if [ $? -eq 0 ]
   then
      log_string="Pulled code from remote."
      logger
   else
      log_string="Error on code pull from remote."
      logger
      exit 1
   fi
   #make sure the branch is exactly the same as remote
   git reset --hard $gitrepo/$gitrepobranch 2>&1>>$log
   #Validate reset
   if [ $? -eq 0 ]
   then
      log_string="Hard reset on local git repository successful."
      logger
   else
      log_string="Hard reset on local git repository unsuccessful."
      logger
      exit 1
   fi
   #Move the code into place
   CodeMove
else
   log_string="Git pull was not qualified. Check $log for more details."
   logger
fi
}




function SwiftPull {
#Pulls stored data from Openstack or Rackspace
echo
#increment operation success if successful
}

function GitRepoValidate {
#Makes sure the user didn't specify a gitrepo variable that has a "/" in it
echo $gitrepo | grep / > /dev/null
if [ $? -eq 0 ]
then 
   log_string="Bad git repository shortname/project due to "/" in name."
   logger
   gitrepoflag=0
else
   log_string="git repository shortname/project looks OK."
   logger
fi
}

function PullSelector {
#Figures out what we need to pull based on variables passed
log_string="Pull flag was specified."
logger
log_string="Determining what to pull..."
logger
#Start checking for git pull
log_string="Checking for git pull parameters."
logger
log_string="Checking for an existing repository home: $gitrepohome"
logger
GitRepoHomeCheck
log_string="Validating specified git repository shortname/project."
logger
GitRepoValidate
#Check for presence of git required variables
if [[ $PullSelectorFlag -eq 1 && $gitrepoflag -eq 1 ]]
then
   #Pre-qualifying the pull of gitrepo after variable verification
   #Check if git is installed
   GitExistCheck
   #Check if the repo is configured
   GitRemoteCheck
   #Gather Results from GitRemoteCheck
   if [ $gitremoteexist -eq 3 ]
   then
      #We have a valid directory and remote configured so we want to perform the pull
      PullSelGit=1
   else
      case $gitremoteexist in
        0) #Neither the directory or the remote are there
           log_string="No directory or remote present on the system.  Please use the configure flag first."
           logger
           PullSelGit=0
        ;;
        1) #Won't happen
           log_string="Pull Selector case 1 error..."
           logger
           PullSelGit=0
        ;;
        2) #directory exists but no remote configured
           log_string="The directory is present, but the remote shortname/project is not configured.  Re-run this script with the configure flag."
           logger
           PullSelGit=0
        ;;
      esac
   fi
   #Try and do a git pull now that we've validated everything. It will fail if variables are not set properly after this validation
   GitPull
   #Check for presence of swift required variables
else
   log_string="Missing arguments to pull a git repository."
   logger
fi
#Done with git
#Start checking for swift

#Done swift
   #turn off the Pull Selector Flag
   PullSelectorFlag=0
   log_string="Nothing more to pull."
   logger
}

function GitClone {
#Clones a git repo, moves the data into place, and then cleans up.
log_string="git clone flag was specified."
logger
GitRepoHomeCheck
GitExistCheck
#Check for required variables.
if [[ $gitclone -eq 1 && $giturlflag -eq 1 ]]
then
   log_string="Git will be cloned with the following parameters:"
   logger
   log_string="Repository URL: $giturl"
   logger
   log_string="Repository Branch: $gitrepobranch"
   logger
   log_string="Cloning Git..."
   logger
   #Change to the gitrepohome directory
   cd $gitrepohome
   #Clone the repo
   git clone $giturl 2>&1>>$log &
   #wait for it
   wait $!
   #Figure out what the repo directory is by separating the project name from the URL - **was a pain
   gitrepo=$(basename ${giturl%.*})
   #Set permissions on the new directory
   chmod 755 $gitrepohome$gitrepo 2>&1>>$log
   #Change to the new directory
   cd $gitrepohome$gitrepo
   #Check what branch we're in
   GitBranchCheck
   #Change to the proper branch we want to deploy
   GitBranchChange 
   #Move the code into the landinghome
   CodeMove
   #Cleanup
   cd $gitrepohome
   rm -rf $gitrepohome$gitrepo 2>&1>>$log
   if [ $? -eq 0 ]
   then
       log_string="Removed temporary repository data."
       logger
   else
       log_string="Unable to remove repository data."
       logger
       exit 1
   fi
   log_string="git clone process completed successfully."
   logger
   exit 0
else
   log_string="Missing parameter for Git URL."
   logger
   exit 5
fi
}

function ConfSelector {
#Figures out what we need to configure based on variables passed
log_string="Configuration flag was specified."
logger
log_string="Determining what to configure..."
logger
log_string="Trying git configuration."
logger
#Check if the gitrepohome exists
log_string="Checking for an existing gitrepohome path: $gitrepohome"
logger
GitRepoHomeCheck
#Check if the gitrepo variable has a slash in it
log_string="Validating specified git repository shortname/project."
logger
GitRepoValidate
#Check for presence of git required variables
if [[ $ConfSelectorFlag -eq 1 && $giturlflag -eq 1 && $gitrepoflag -eq 1 ]]
then
 #Pre-qualifying the configuration of git repos after variable verification
  #Check if Git is installed
  GitExistCheck
  #Check if the repo already exists
  GitRemoteCheck
  #Gather results from GitRemoteCheck and process
  case $gitremoteexist in
   0) #git remote and gitrepo directory don't exist, good condition
       log_string="Git will be configured with the following parameters:"
       logger
       log_string="Repositry Local Path: $gitrepohome$gitrepo"
       logger
       log_string="Repository URL: $giturl"
       logger
       log_string="Repository Shortname: $gitrepo"
       logger
       #Switch on the ConfSelGit variable to enable the configuration of the repo
       ConfSelGit=1
       #Configure the repo
     ;;
   1) #git remote exists but not the directory
      log_string="git remote detected, but no repository directory matching the specified repository shortname $gitrepo."
      logger
      log_string="This case would only occur if this deploy script is running in an existing git repo. No other work to do."
      logger
      ConfSelGit=0
     ;;
   2) #git directory exists that matches specified gitrepo
      log_string="The repository specified has an existing directory, but there is no matching remote."
      logger
      #check if the directory is empty
      log_string="Checking if the directory found is empty."
      logger
      if [ ! -e $gitrepo/* ]
      then
         log_string="Directory is empty. Removing."
         logger
         #code efficiency to reuse createdir function - remove the directory
         rmdir $gitrepohome$gitrepo 2>&1>>$log
         ConfSelGit=1
      else
         log_string="The repository specified matches an existing directory $gitrepohome$gitrepo.  It is not empty and we will not configure your repository here."
         logger
         ConfSelGit=0
      fi
     ;;
   3) #both git remote and git directory exist.  Don't configure.
       log_string="The specified repository $gitrepo already exists on this system. Skipping configuration."
       logger
       ConfSelGit=0
     ;;
  esac
else
   log_string="Missing arguments to configure a git repository."
   logger
fi
#Try to configure Git after all validation has occurred
GitConf
#Check for presence of swift required variables

   #Turn on ConfSelSwift switch based on results

ConfSelectorFlag=0
log_string="Nothing more to configure."
logger
}

#Pulling in options from shell.  Using getopts instead of getopt
#Capturing options and suppressing getopts errors (leading : in getopts string) for our own error handling
while getopts ":r:g:C:U:K:L:b:h:vdpcf-:" flag
  do
#    echo "$flag" $OPTIND $OPTARG #for testing; will remove later
    #Error handling on missing arguments
    if [ $flag = : ]
    then
       log_string="Option $OPTARG Missing Argument."
       logger
       script_usage
       exit 5
    fi
    #Error handling on invalid option
    if [ $flag = ? ]
    then
       log_string="Option $OPTARG Not Recognized."
       logger
       script_usage
       exit 5
    fi
    #Error handling on missing argument followed by another flag
    #Example deploy.sh -r -b, -b will be picked up as -r's argument.  This will handle it and notify the user.
    if [[ $OPTARG = -* ]]
    then
       log_string="Option $flag Missing Argument."
       logger
       script_usage
       exit 5
    fi
    #Handling getopts flags 
    case $flag in
       -)#parsing long option names
          case $OPTARG in
             config) #Configures a git repo locally to be able to later only pull in changes.
                  ConfSelectorFlag=1;OPTIND=$(( $OPTIND + 1 ))
             ;;
             pull) #Pulls data based on variables fed.
                  PullSelectorFlag=1;OPTIND=$(( $OPTIND + 1 ))
             ;;
             clone) #Completes a temporary git clone moves the code into place and then deletes the directory created.
                  gitclone=1;OPTIND=$(( $OPTIND + 1 ))
             ;;
             project) #same as a git remote shortname
                  gitrepo="${!OPTIND}";gitrepoflag=1;OPTIND=$(( $OPTIND + 1 ))
             ;;
             shortname) #same as a git project name
                  gitrepo="${!OPTIND}";gitrepoflag=1#;OPTIND=$(( $OPTIND + 1 ))
             ;;
             branch) #git branch name to deploy.
                  gitrepobranch="${OPTIND}";gitrepobranchflag=1;OPTIND=$(( $OPTIND + 1 ))
             ;;
             url) #git URL to a repository.  may be ssh or https style
                  giturl="${!OPTIND}";giturlflag=1;OPTIND=$(( $OPTIND + 1 ));script_debug
             ;;
             container)#openstack swift container
                  OPTIND=$(( $OPTIND + 1 ))
             ;;
             osauthurl)#openstack authentication URL
                  OPTIND=$(( $OPTIND + 1 ))
             ;;
             osuser)#openstack user
                  OPTIND=$(( $OPTIND + 1 ))
             ;;
             oskey)#openstack api key
                  OPTIND=$(( $OPTIND + 1 ))
             ;;
             ospath)#openstack path to directory or file -- requirement of a container variable as well
                  OPTIND=$(( $OPTIND + 1 ))
             ;;
             debug)#spits debugging into log
                  scriptdebugflag=1;OPTIND=$(( $OPTIND + 1 ))
             ;;
             verbose)#directs echo output to console
                  log_verbose=1;OPTIND=$(( $OPTIND + 1 ))
             ;;
             *) #unknown command
                  log_string="Unrecognized long flag or argument";logger;exit 5
             ;;
          esac
          ;;
       r) gitrepo=$OPTARG;gitrepoflag=1;;
       g) giturl=$OPTARG;giturlflag=1;;
       C) oscontainer=$OPTARG;;
       U) osuser=$OPTARG;;
       K) oskey=$OPTARG;;
       A) osauthurl=$OPTARG;;
       P) ospath=$OPTARG;;
       L) landinghome=$OPTARG;;
       b) gitrepobranch=$OPTARG;gitrepobranchflag=1;;
       h) host=$OPTARG;;
       d) scriptdebugflag=1;;
       v) log_verbose=1;;
       p) PullSelectorFlag=1;;
       c) ConfSelectorFlag=1;;
       f) gitclone=1;;
       *) log_string="Unrecognized flag or argument";logger;exit 5;;
    esac
  #Ending getopts capturing and handling
  done

    #Test Example Handling multiple hosts
    for hosts in $host;
    do
      echo $hosts
    done


#Start work
#Check for multiple pull/clone type options and exit if so.
if [[ $ConfSelectorFlag -eq 1 && $PullSelectorFlag -eq 1 && $gitclone -eq 1 ]]
then
   log_string="You have specified the clone flag, pull flag, and configure flag. These are redundant. Too many options specified. Exiting..."
   logger
   log_string="You are able to do a Configure and Pull, but not a configure, pull, and clone."
   logger
   exit 1
fi

#Do configuration first
#Check for configuration option for a scenario where we want the repo stored
if [ $ConfSelectorFlag -eq 1 ]
then
   #Use ConfSelector Function to figure out what we need to configure
   ConfSelector
fi

#Do Pull Second
#check for pull flag
if [ $PullSelectorFlag -eq 1 ]
then
   #Use PullSelector Function to figure out what we need to pull
   PullSelector
fi

#Do a stand-alone clone Third
#check for the gitclone flag
if [ $gitclone -eq 1 ]
then
   #Do a git clone
   GitClone
fi

#Check for success and exit with appropriate error code
if [ $operationfail -gt 0 ]
then
    log_string="There were $operationfail failures during the run."
    logger
    log_string="There were $operationsuccess successes during the run."
    logger
    log_string="Exited with error because of any single failure."
    logger
    #exiting cleanly, no errors occurred
    exit 1
else
    log_string="There were $operationfail failures during the run."
    logger
    log_string="There were $operationsuccess successes during the run."
    logger
    log_string="Exited clean, because there were no errors during the run."
    logger
    exit 0
fi
