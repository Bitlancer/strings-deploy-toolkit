#!/bin/bash


#variables
log="/var/log/bitlancer-deploy.log" #log path
host="" #used for deploying to a host or many hosts
gitrepo="" #git repostitory specified by user at runtime
giturl="" #git repository url specified by user at runtime
gitcloneflag=0 #turned on with getopts option
oscontainer="" #openstack/rackspace storage container
osuser="" #openstack swift username specified by user at runtime
oskey="" #openstack swift api key specified by user at runtime
osauthurl="" #openstack swift authentication url specified by user at runtime
ospath="" #openstack swift path to file or directory within container specified by user at runtime
osuserflag=0 #openstack swift user flag turned on by getopts option
oskeyflag=0 #openstack swift api key flag turned on by getopts option
osauthurlflag=0 #openstack swift authentication url flag turned on by getopts option
ospathflag=0 #openstack swift path to file or directory within container flag turned on by getopts option
oscontainerflag=0 #openstack container flag turned on by getopts option
oscontainerexist=0 #openstack container exists switch turned on if exit code 0 from swift cli listing a specified container
osauthpass=0 #openstack authentication switch. turned on after a successful authentication attempt by swift cli stat with return code 0.
gitrepobranch="" #git repository branch to clone or pull from specified by user at runtime.
gitrepobranchflag=0 #git repository branch flag turned on by getopts option
gitversion=$(git --version) #git binary version
gitbinpath=$(which git) #git binary path
osswiftversion=$(swift --version) #openstack swift cli version
osswiftbinpath=$(which swift) #openstack swift cli binary path
gitcurrentbranch="" #git current working branch - used by GitBranchChange function
log_string="" #For logging to log and for verbose logging. used for interaction with logger function
log_verbose=0 #Switch used for verbose logging turned on by getopts option
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
gitlandinghome="/var/www/vhosts/" #Where you want the data to land if using virtual hosts specify -l and the path on the command line
oslandinghome="/var/www/vhosts/"
landinghome="" #used prior to doing DataMove by each pull/clone function
scriptdebugflag=0
operationsuccess=0
operationfail=0
tararchive="" #file to deploy
tarextractflag=0 #Gets turned on by getopts
tarlandinghome="" #where the file should deploy to
servicename="" #service to restart
staginghome="" #where to stage the files prior to deployment
lock="/var/lock/deploy"
ref="" #reference 
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

function script_usage {
  #Script Usage output function.  Use this to spit out a canned response on how to use this script.
  echo "deploy.sh - Script Usage:"
  echo "deploy.sh <option> <argument>"
  echo "Global Script Options:"
  echo "-d Debug Mode"
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
  echo "Git Related Option flag descriptions:"
  echo "-f Completes a full git clone (-g required (-b -l optional))"
  echo "-c Configures git for local storage (used prior to pull option) (-g -r required)"
  echo "-p Pulls git repository (-r required)"
  echo "-r <Git Repository/Project Shortname>"
  echo "-g <Git HTTPS/SSH URL>"
  echo "-b <Git Repository Branch>"
  echo "-l <landing path> Defaults to /var/www/html/"
  echo 
  echo
  echo "Openstack Swift Usage:"
  echo "  Example:"
  echo "  deploy.sh -p -A <arg> -U <arg> -K <arg> -C <arg> [ -P <arg> -L <arg> ]"
  echo "  Pulling a openstack swift container, and moving it to a landing path:"
  echo "  deploy.sh -p -A <arg> -U <arg> -K <arg> -C <arg> -L <arg>"
  echo "  Pulling a file or directory from within an openstack swift container"
  echo "  deploy.sh -p -A <arg> -U <arg> -K <arg> -C <arg> -P <arg> [ -L <arg> ]"
  echo "Openstack Swift Related Option flag descriptions:"
  echo "-p Pulls the specified container and file or directory from openstack swift (required)"
  echo "-A <Authentication URL> openstack Authentication URL (required)"
  echo "-U <Username> openstack swift username (required)"
  echo "-K <API Key> openstack swift API key (required)"
  echo "-C <Container Name> openstack swift container name (required)"
  echo "-P <path to file or directory within openstack swift container> openstack swift file or directory path"
  echo "-L <Landing Path> openstack swift landing path. Defaults to /var/www/html/"
  echo 
  echo
  echo "Tar/Tar.gz Usage"
  echo "  Example:"
  echo "  deploy.sh -t -a <arg> -S <arg> [ -R <arg> ]"
  echo "Tar/Tar.gz Related Option flag descriptions:"
  echo "-a <Archive Path> (required)"
  echo "-S <Staging Path> (required)"
  echo "-R <Reference ID>"
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
      log_string="gitrepo=$gitrepo"
      logger
      log_string="giturl=$giturl"
      logger
      log_string="gitcloneflag=$gitcloneflag"
      logger
      log_string="oscontainer=$oscontainer"
      logger
      log_string="osuser=$osuser"
      logger
      log_string="oskey=$oskey"
      logger
      log_string="osauthurl=$osauthurl"
      logger
      log_string="ospath=$ospath"
      logger
      log_string="osuserflag=$osuserflag"
      logger
      log_string="oskeyflag=$oskeyflag"
      logger
      log_string="osauthurlflag=$osauthurlflag"
      logger
      log_string="ospathflag=$ospathflag"
      logger
      log_string="oscontainerflag=$oscontainerflag"
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


function chk_running {
  if [[ -f $lock ]]
    then
        log_string="Error: Script is already running."
	logger
	log_string="Time of Error: `date`"
        logger
        exit 5
  fi
}


function GitExistCheck {
  #Checks that git is installed and at a good version (if we want to go that far.)
  if [[ $gitversion != *git* ]]
  then
     #We could do an install of git here if desired
     log_string="Error: Git is not installed"
     logger
     rm_lock
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
      git checkout $gitrepobranch 2>&1&>>$log
      if [ $? -eq 0 ]
      then
          GitBranchCheck
      else
          log_string="Branch change failed."
          logger
          rm_lock
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
  mkdir -p $dirpath 2>&1&>>$log
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
      git remote | grep $gitrepo 2>&1&>>$log
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

function GitLandingHomeCheck {
  #checks for valid landinghome
  log_string="Checking for landing path $gitlandinghome"
  logger
  if [ -d $gitlandinghome ]
  then
      log_string="landing path exists."
      logger
  else
      #we could choose to just create the path instead
      log_string="landing path does not exist."
      logger
      rm_lock
      exit 1
  fi
}

function OSSwiftLandingHomeCheck {
  #checks for valid landinghome
  log_string="Checking for landing path $oslandinghome"
  logger
  if [ -d $oslandinghome ]
  then
      log_string="openstack swift landing path exists."
      logger
  else
      #we could choose to just create the path instead
      log_string="landing path does not exist."
      logger
      rm_lock
      exit 1
  fi
}

function OSSwiftDataHomeCheck {
  #Checks for a valid temporary directory to store downloaded files prior to moving into place.
  log_string="Checking for temporary data home $datahome."
  logger
  if [ -d $datahome ]
  then
     log_string="Data Home exists at $datahome."
     logger
  else
     #create it
     dirpath=${datahome}
     CreateDir
  fi
}

function DataMove {
  #Takes pulled code/data moves into proper web directory
  #Set your gitlandinghome or oslandinghome to landinghome and then use this.
  log_string="Attempting to move data into place."
  logger
  #move code from repodir to live landing dir
  rsync -av --progress $dirpath* $landinghome --exclude ".gitosmanifest.lst" 2>&1&>>$log
  #clear dirpath just in case 
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
  dirpath=""
}



function GitConf {
  if [ $ConfSelGit -eq 1 ]
  then
      log_string="Configuring Git..."
      logger
      #Change to the gitrepohome directory
      cd $gitrepohome
      log_string="In Directory:"
      logger
      pwd 2>&1&>>$log
      #Clone the repo
      log_string="Configuring Git..."
      logger
      #Change to the gitrepohome directory
      cd $gitrepohome
      #Clone the repo
      git clone $giturl 2>&1&>>$log &
      #wait for it
      wait $!
      #Validate successful clone
      if [ $? -eq 0 ]
      then
          #Set permissions on the new directory
          chmod 755 $gitrepohome$gitrepo 2>&1&>>$log
          #Change to the new directory
          cd $gitrepohome$gitrepo
          #Change the repo name from origin to match the project name - will keep systems with many repos from getting confusing
          log_string="Changing origin to match the project name"
          logger
          git remote rename origin $gitrepo 2>&1&>>$log
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
      log_string="Git configuration was not qualified.  Check log $log for more details."
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
      #Check the landing path exists before we bother pulling it will fail if it doesn't
      GitLandingHomeCheck
      #Pull in the code
      git pull $gitrepo $gitrepobranch 2>&1&>>$log &
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
          rm_lock
          exit 1
      fi
      #make sure the branch is exactly the same as remote
      git reset --hard $gitrepo/$gitrepobranch 2>&1&>>$log
      #Validate reset
      if [ $? -eq 0 ]
      then
          log_string="Hard reset on local git repository successful."
          logger
      else
          log_string="Hard reset on local git repository unsuccessful."
          logger
          rm_lock
          exit 1
      fi
      #Move the code into place
      landinghome=${gitlandinghome}
      log_string="Set landing to $landinghome"
      logger
      #set dirpath for datamove
      dirpath="$gitrepohome$gitrepo/" # slash needed here
      log_string="Trying to move data from $dirpath"
      logger
      #set dirpath for datamove
      dirpath="$gitrepohome$gitrepo/"
      log_string="Attempting to move data from $dirpath"
      logger
      DataMove
  else
      log_string="Git pull was not qualified. Check $log for more details."
      logger
  fi
}


function OSSwiftContainerCheck {
  #Does a swift stat to see if we can get access to the account
  log_string="Checking that specified openstack swift container exists."
  logger
  swift -A $osauthurl -U $osuser -K $oskey list $oscontainer > /dev/null
  if [ $? -eq 0 ]
  then
     log_string="Container $oscontainer exists."
     logger
     oscontainerexist=1
  else
     log_string="Container $oscontainer does not exist."
     logger
     oscontainerexist=0
  fi
}


function OSSwiftAuthCheck {
  log_string="Checking openstack swift client credentials"
  logger
  swift -A $osauthurl -U $osuser -K $oskey stat > /dev/null
  if [ $? -eq 0 ]
  then
     log_string="Credentials working."
     logger
     osauthpass=1
  else
     log_string="Credentials not working, check your openstack authentication URL, username, and key for errors."
     logger
     osauthpass=0
  fi
}

function OSSwiftExistCheck {
  #Checks if swift is installed
  if [[ $osswiftversion != *swift* ]]
  then
     #We could do an install of git here if desired
     log_string="Error: openstack swift not installed"
     logger
     rm_lock
     exit 1
  else
     log_string="swift exists: $osswiftversion"
     logger
  fi
}

function OSSwiftDirectoryPull {
 if [ $PullSelSwift -eq 1 ]
  then
      #Make sure swift exists
      OSSwiftExistCheck
      #Make sure oslanding exists
      OSSwiftLandingHomeCheck
      #Make sure datahome exists
      OSSwiftDataHomeCheck
      #Test openstack credentials
      OSSwiftAuthCheck
      if [ $osauthpass -eq 1 ]
      then
         #Make sure container exists
         OSSwiftContainerCheck
         if [ $oscontainerexist -eq 1 ]
         then
             #Make a directory to match the container name, we'll use the CreateDir function for validation
             #Set the variables for function use
             dirpath="$datahome$oscontainer"
             log_string="Attempting to create directory $dirpath"
             logger
             CreateDir
             #Change to the container directory
             cd $datahome$oscontainer
             #Complete the container pull
             log_string="Performing a pull of openstack swift container $oscontainer path $ospath"
             logger
             #list the contents into a file
             swift -A $osauthurl -U $osuser -K $oskey list $oscontainer -p $ospath > "$datahome$oscontainer/osmanifest.lst"
             #do while reading in the osmanifest.lst file names pull down the filename
             log_string="Swift Directory Downloader:"
             logger
             #read the manifest.lst to figure out what to download from the folder
             cat "$datahome$oscontainer/osmanifest.lst" | while read FILENAME 
               do
                 log_string="Attempting openstack swift download of: $FILENAME"
                 logger
                 swift -A $osauthurl -U $osuser -K $oskey download $oscontainer "$FILENAME" 2>&1&>>$log
                 #Check if the download happened properly
                 if [ $? -eq 0 ]
                 then
                     log_string="$FILENAME downloaded from swift container $oscontainer."
                     logger
                 else
                     log_string="$FILENAME failed to download from swift container $oscontainer"
                     logger
                     rm_lock
                     exit 1
                 fi
               done
             #Move the data into place
               #Set the landinghome to openstack landing home specified
               landinghome=${oslandinghome}
               log_string="Landing home set to $landinghome."
               logger
               dirpath="$datahome$oscontainer/"
               log_string="Attempting to move data from $dirpath"
               logger
               DataMove
             #Cleanup
             rm -f $landinghome/osmanifest.lst
             log_string="Cleaning up temporary files/directories."
             logger
             cd $datahome
             log_string="Current Directory:"
             logger
             log_string="$(pwd)"
             logger
             rm -rf $datahome$oscontainer 2>&1&>>$log
         else
             log_string="No valid openstack swift container file to pull."
             logger
             operationfail=$((operationfail + 1))
         fi
      else
         log_string="Can't pull from openstack swift with bad credentials."
         logger
         operationfail=$((operationfail + 1))
      fi
  else
      log_string="openstack swift pull was not qualified. See log file $log for more details."
      logger
  fi
}

function OSSwiftFilePull {
echo
 if [ $PullSelSwift -eq 1 ]
  then
      #Make sure swift exists
      OSSwiftExistCheck
      #Make sure oslanding exists
      OSSwiftLandingHomeCheck
      #Make sure datahome exists
      OSSwiftDataHomeCheck
      #Test openstack credentials
      OSSwiftAuthCheck
      if [ $osauthpass -eq 1 ]
      then
         #Make sure container exists
         OSSwiftContainerCheck
         if [ $oscontainerexist -eq 1 ]
         then
             #Make a directory to match the container name, we'll use the CreateDir function for validation
             #Set the variables for function use
             dirpath="$datahome$oscontainer"
             log_string="Attempting to create directory $dirpath"
             logger
             CreateDir
             #Change to the container directory
             cd $datahome$oscontainer
             #Complete the container pull
             log_string="Performing a pull of openstack swift container $oscontainer path $ospath"
             logger
             #list the file to see if it exists
             swift -A $osauthurl -U $osuser -K $oskey list $oscontainer -p $ospath > "$datahome$oscontainer/osmanifest.lst"
             if [ $? -eq 0 ]
             then
                 log_string="Swift File Downloader:"
                 logger
                 log_string="Attempting openstack swift download of: $ospath"
                 logger
                 swift -A $osauthurl -U $osuser -K $oskey download $oscontainer "$ospath" 2>&1&>>$log
                 #Check if the download happened properly
                 if [ $? -eq 0 ]
                 then
                     log_string="$ospath downloaded from swift container $oscontainer."
                     logger
                 else
                     log_string="$ospath failed to download from swift container $oscontainer"
                     logger
                     rm_lock
                     exit 1
                 fi
               #Move the data into place
               #Set the landinghome to openstack landing home specified
               landinghome=${oslandinghome}
               log_string="Landing home set to $landinghome."
               logger
               dirpath="$datahome$oscontainer/"
               log_string="Attempting to move data from $dirpath"
               logger
               DataMove
             #Cleanup
             rm -f $landinghome/osmanifest.lst
             log_string="Cleaning up temporary files/directories."
             logger
             cd $datahome
             log_string="Current Directory:"
             logger
             log_string="$(pwd)"
             logger
             rm -rf $datahome$oscontainer 2>&1&>>$log
             fi
         else
             log_string="No valid openstack swift container file to pull."
             logger
             operationfail=$((operationfail + 1))
         fi
      else
         log_string="Can't pull from openstack swift with bad credentials."
         logger
         operationfail=$((operationfail + 1))
      fi
  else
      log_string="openstack swift pull was not qualified. See log file $log for more details."
      logger
  fi

}  

function OSSwiftPathPullSelector {
  #Pulls in a openstack swift file or entire directory path
   if [ $PullSelSwift -eq 1 ]
   then
       lastchar="${ospath: -1:1}" #used to check for a forward slash denoting a direcory
       if [ $scriptdebugflag -eq 1 ]
       then
           log_string="lastchar=$lastchar"
           logger
       fi
       directory=0 #switch set based on results of validation in this function
       file=0
       #check if the path is a directory or a file
       if [[ $lastchar == / ]]
       then
           directory=1
           file=0
           log_string="The openstack swift path is a directory."
           logger
       else
           directory=0
           file=1
           log_string="The openstack swift path is a file."
           logger
       fi
       if [ $directory -eq 1 ]
       then
           OSSwiftDirectoryPull
       else
           OSSwiftFilePull
       fi
   else 
       #easter egg
       log_string="Help me I'm stoned....."
       logger
       rm_lock
       exit 420
   fi
}

function OSSwiftContainerPull {
  #Pulls stored data from Openstack or Rackspace
  log_string="Attempting to pull openstack swift container."
  logger
  if [ $PullSelSwift -eq 1 ]
  then
      #Make sure swift exists
      OSSwiftExistCheck  
      #Make sure oslanding exists
      OSSwiftLandingHomeCheck 
      #Make sure datahome exists
      OSSwiftDataHomeCheck
      #Test openstack credentials
      OSSwiftAuthCheck
      if [ $osauthpass -eq 1 ]
      then
         #Make sure container exists
         OSSwiftContainerCheck
         if [ $oscontainerexist -eq 1 ]
         then
             #Make a directory to match the container name, we'll use the CreateDir function for validation
             #Set the variables for function use
             dirpath="$datahome$oscontainer"
             log_string="Attempting to create directory $dirpath"
             logger
             CreateDir
             #Change to the container directory
             cd $datahome$oscontainer
             #Complete the container pull
             log_string="Swift Download:"
             logger
             swift -A $osauthurl -U $osuser -K $oskey download $oscontainer 2>&1&>>$log
             #wait for it
             wait $!
             #Move the data into place
               #Set the landinghome to openstack landing home specified
               landinghome=${oslandinghome}
               log_string="Landing home set to $landinghome."
               logger
               dirpath="$datahome$oscontainer"
               log_string="Attempting to move data from $dirpath"
               logger
               DataMove
             #Cleanup
             log_string="Cleaning up temporary files/directories."
             logger
             cd $datahome
             log_string="Current Directory:"
             logger
             log_string="$(pwd)"
             logger
             rm -rf $datahome$oscontainer 2>&1&>>$log
             
         else
             log_string="No valid openstack swift container to pull."
             logger
             operationfail=$((operationfail + 1))
         fi
      else
         log_string="Can't pull from openstack swift with bad credentials."
         logger
         operationfail=$((operationfail + 1))
      fi
  else
      log_string="openstack swift pull was not qualified. See log file $log for more details."
      logger
  fi
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
  #Check for presence of git required variables
  if [[ $PullSelectorFlag -eq 1 && $gitrepoflag -eq 1 ]]
  then
      log_string="Checking for an existing repository home: $gitrepohome"
      logger
      GitRepoHomeCheck
      log_string="Validating specified git repository shortname/project."
      logger
      GitRepoValidate
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
  else
     log_string="Missing arguments to pull git a git repository."
     logger
  fi
  #Done with git
  #Start checking for openstack swift
  #Check for all required swift options 
  log_string="Checking for openstack swift parameters."
  logger
  if [[ $PullSelectorFlag -eq 1 && $osauthurlflag -eq 1 && $osuserflag -eq 1 && $oskeyflag -eq 1 && $oscontainerflag -eq 1 ]]
  then
      #Did the user specify an openstack path
      if [ $ospathflag -eq 1 ]
      then
          #pull the specified openstack swift object
          #turns on the pull selector switch for openstack
          PullSelSwift=1
          if [ $scriptdebugflag -eq 1 ]
          then
              log_string="PullSelSwift=$PullSelSwift"
              logger
          fi
          OSSwiftPathPullSelector
      else
          #pull the entire container down
          #turns on the pull selector switch for openstack
          PullSelSwift=1
          OSSwiftContainerPull
      fi
  else
      #Missing openstack swift parameters 
      log_string="Missing arguments to pull from openstack swift."
      logger
  fi
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
  if [[ $gitcloneflag -eq 1 && $giturlflag -eq 1 ]]
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
      #Check that the landing path exists before we bother cloning.  It will fail if it doesn't
      GitLandingHomeCheck
      #Clone the repo
      git clone $giturl 2>&1&>>$log &
      #wait for it
      wait $!
      #Figure out what the repo directory is by separating the project name from the URL - **was a pain
      gitrepo=$(basename ${giturl%.*})
      #Set permissions on the new directory
      chmod 755 $gitrepohome$gitrepo 2>&1&>>$log
      #Change to the new directory
      cd $gitrepohome$gitrepo
      #Check what branch we're in
      GitBranchCheck
      #Change to the proper branch we want to deploy
      GitBranchChange 
      #Move the code into the landinghome
      landinghome=${gitlandinghome}
      #Set dirpath for datamove
      dirpath="$gitrepohome$gitrepo/"
      log_string="Attempting to move data from $dirpath"
      logger
#Gotta move this stuff out and figure out more to make wrapper work right -12-10-13-ajh
      DataMove
      #Cleanup
      cd $gitrepohome
      rm -rf $gitrepohome$gitrepo 2>&1&>>$log
      if [ $? -eq 0 ]
      then
          log_string="Removed temporary repository data."
          logger
      else
          log_string="Unable to remove repository data."
          logger
          rm_lock
          exit 1
      fi
      log_string="git clone process completed successfully."
      logger
  else
      log_string="Missing parameter for Git URL."
      logger
      rm_lock
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
  #Check for presence of required git configuration switches
  if [[ $ConfSelectorFlag -eq 1 && $giturlflag -eq 1 && $gitrepoflag -eq 1 ]]
  then
      #Check if the gitrepohome exists
      log_string="Checking for an existing gitrepohome path: $gitrepohome"
      logger
      GitRepoHomeCheck
      #Check if the gitrepo variable has a slash in it
      log_string="Validating specified git repository shortname/project."
      logger
      GitRepoValidate
      #Check for presence of git required variables
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
                #so we return proper error codes with CreateDir function
                rmdir $gitrepohome$gitrepo 2>&1&>>$log
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
      script_usage
      rm_lock
      exit 5
  fi
  #Try to configure Git after all validation has occurred
  GitConf
  #Check for presence of openstack swift required variables

  #Turn on ConfSelSwift switch based on results

  ConfSelectorFlag=0
  log_string="Nothing more to configure."
  logger
}

function rm_lock {
 #remove lock file
      rm -f $lock
      if [[ $? -eq 0 ]]
      then
          log_string="Lock file removed successfully."
          logger
      else
          log_string="Lock file was unable to be removed."
          logger
      fi
}

function ServiceStop () {
  #Stops the specified service
  soyvis=$1
  echo "Trying to stop: $soyvis"
  if [ -z "$soyvis" ]
  then
      log_string="No Service provided to stop."
      logger
  else
      /etc/init.d/$soyvis stop
      if [[ $? -eq 0 ]]
      then
          log_string="Service $soyvis was stopped."
          logger
      else
          log_string="Service $soyvis could not be stopped."
          logger
          rm_lock
          exit 5
      fi
  fi
}


function ServiceStart () {
  #Starts the specified service
  soyvis=$1
  echo "Trying to stop: $soyvis"
  if [ -z "$soyvis" ]
  then 
      log_string="No Service provided to start."
      logger
  else
      /etc/init.d/$soyvis start
      if [[ $? -eq 0 ]]
      then
          log_string="Service $soyvis was started."
          logger
      else
          log_string="Service $soyvis could not be started."
          logger
          rm_lock
          exit 5
      fi
  fi
}

function ExtractTarball {
#Extracts a tarfile 
  #extract the file to staging
  if [[ "$staginghome" != "" && "$tararchive" != "" ]]
  then
      #Check for Staging Directory to exist
      if [ ! -d $staginghome$ref ]
      then
          #Create Staging Directory to Extract to
          dirpath="$staginghome""$ref"/
          CreateDir
      fi
      log_string="Extracting Tar."
      logger
      tar -xvf $tararchive --directory "$staginghome""$ref"/ 2>&1&>>$log
      #check the error code
      if [[ $? -eq 0 ]]
      then
          log_string="Extracted Tar successfully."
          logger
          operationsuccess=$((operationsuccess + 1))
      else
          log_string="Extraction of Tar failed."
          logger
          rm_lock
          exit 5
          operationfail=$((operationsuccess + 1))
      fi
  else
      script_usage
      rm_lock
      exit 5
  fi
}


#Pulling in options from shell.  Using getopts instead of getopt
#Capturing options and suppressing getopts errors (leading : in getopts string) for our own error handling
while getopts ":r:g:a:s:S:A:C:U:K:P:L:R:b:h:l:vtdpcf-:" flag
  do
    #debugging getopts loop
    if [ $scriptdebugflag -eq 1 ]
    then
        log_string="getopts loop settings:"
        logger
#        log_string=$(echo "flag="$flag" OPTIND="$OPTIND" OPTARG="$OPTARG"")
        logger
    fi
    #Error handling on missing arguments
    if [ $flag = : ]
    then
       log_string="Option $OPTARG Missing Argument."
       logger
       script_usage
       rm_lock
       exit 5
    fi
    #Error handling on invalid option
    if [ $flag = ? ]
    then
       log_string="Option $OPTARG Not Recognized."
       logger
       script_usage
       rm_lock
       exit 5
    fi
    #Error handling on missing argument followed by another flag
    #Example deploy.sh -r -b, -b will be picked up as -r's argument.  This will handle it and notify the user.
    if [[ $OPTARG = -* ]]
    then
       log_string="Option $flag Missing Argument."
       logger
       script_usage
       rm_lock
       exit 5
    fi
    #Handling getopts flags 
    case $flag in
# "--long-type" options I don't have stable yet
#       -)#parsing long option names
#          case $OPTARG in
#             config) #Configures a git repo locally to be able to later only pull in changes.
#                  ConfSelectorFlag=1;OPTIND=$(( $OPTIND + 1 ))
#             ;;
#             pull) #Pulls data based on variables fed.
#                  PullSelectorFlag=1;OPTIND=$(( $OPTIND + 1 ))
#             ;;
#             clone) #Completes a temporary git clone moves the code into place and then deletes the directory created.
#                  gitcloneflag=1;OPTIND=$(( $OPTIND + 1 ))
#             ;;
#             project) #same as a git remote shortname
#                  gitrepo="${!OPTIND}";gitrepoflag=1;OPTIND=$(( $OPTIND + 1 ))
#             ;;
#             shortname) #same as a git project name
#                  gitrepo="${!OPTIND}";gitrepoflag=1#;OPTIND=$(( $OPTIND + 1 ))
#             ;;
#             branch) #git branch name to deploy.
#                  gitrepobranch="${OPTIND}";gitrepobranchflag=1;OPTIND=$(( $OPTIND + 1 ))
#             ;;
#             url) #git URL to a repository.  may be ssh or https style
#                  giturl="${!OPTIND}";giturlflag=1;OPTIND=$(( $OPTIND + 1 ));script_debug
#             ;;
#             container)#openstack swift container
#                  OPTIND=$(( $OPTIND + 1 ))
#             ;;
#             osauthurl)#openstack authentication URL
#                  OPTIND=$(( $OPTIND + 1 ))
#             ;;
#             osuser)#openstack user
#                  OPTIND=$(( $OPTIND + 1 ))
#             ;;
#             oskey)#openstack api key
#                  OPTIND=$(( $OPTIND + 1 ))
#             ;;
#             ospath)#openstack path to directory or file -- requirement of a container variable as well
#                  OPTIND=$(( $OPTIND + 1 ))
#             ;;
#             debug)#spits debugging into log
#                  scriptdebugflag=1;OPTIND=$(( $OPTIND + 1 ))
#             ;;
#             verbose)#directs echo output to console
#                  log_verbose=1;OPTIND=$(( $OPTIND + 1 ))
#             ;;
#             *) #unknown command
#                  log_string="Unrecognized long flag or argument";logger;rm_lock;exit 5
#             ;;
#          esac
#          ;;
       r) gitrepo=$OPTARG;gitrepoflag=1;;
       g) giturl=$OPTARG;giturlflag=1;;
       C) oscontainer=$OPTARG;oscontainerflag=1;;
       U) osuser=$OPTARG;osuserflag=1;;
       K) oskey=$OPTARG;oskeyflag=1;;
       A) osauthurl=$OPTARG;osauthurlflag=1;;
       P) ospath=$OPTARG;ospathflag=1;;
       L) oslandinghome=$OPTARG;;
       l) gitlandinghome=$OPTARG;tarlandinghome=$OPTARG;;
       b) gitrepobranch=$OPTARG;gitrepobranchflag=1;;
       h) host=$OPTARG;;
       d) scriptdebugflag=1;echo "Script Debugging specified";echo "Script Debugging specified" >> $log;;
       v) log_verbose=1;echo "Verbose Logging specified";echo "Verbose Logging specified" >> $log;;
       p) PullSelectorFlag=1;;
       c) ConfSelectorFlag=1;;
       f) gitcloneflag=1;;
       t) tarextractflag=1;;
       a) tararchive=$OPTARG;;
       s) servicename="$OPTARG";;
       S) staginghome=$OPTARG;;
       R) ref="$OPTARG";;
       *) log_string="Unrecognized flag or argument";logger;rm_lock;exit 5;;
    esac
  #Ending getopts capturing and handling
  done

    #Test Example Handling multiple hosts
    for hosts in $host;
    do
      echo $hosts
    done


#Start work

#see if the script is already running
chk_running

#Not running so create the lock File
date > $lock


#Check for multiple pull/clone type options and exit if so.
if [[ $ConfSelectorFlag -eq 1 && $PullSelectorFlag -eq 1 && $gitcloneflag -eq 1 ]]
then
    log_string="You have specified the clone flag, pull flag, and configure flag. These are redundant. Too many options specified. Exiting..."
    logger
    log_string="You are able to do a Configure and Pull, but not a configure, pull, and clone."
    logger
    rm_lock
    exit 1
fi

#Try configuration first
#Check for configuration option for a scenario where we want the repo stored
if [ $ConfSelectorFlag -eq 1 ]
then
    #Use ConfSelector Function to figure out what we need to configure
    ConfSelector
fi

#Try pull second
#check for pull flag
if [ $PullSelectorFlag -eq 1 ]
then
    #Use PullSelector Function to figure out what we need to pull
    PullSelector
fi

#Try a stand-alone clone third
#check for the gitcloneflag
if [ $gitcloneflag -eq 1 ]
then
    #Do a git clone
    GitClone
fi

#Try a tarextract fourth
if [[ $tarextractflag -eq 1 ]] #-z $staginghome && -z $tararchive ]]
then 
    #Extract the tar
    ExtractTarball
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
    #exiting with errors
      #remove lock file
      rm_lock
      exit 1
else
    log_string="There were $operationfail failures during the run."
    logger
    log_string="There were $operationsuccess successes during the run."
    logger
    log_string="Exited clean, because there were no errors during the run."
    logger
    #Exiting with no errors
     #remove lock file
     rm_lock
    exit 0
fi
