strings-deploy-toolkit
======================

Bitlancer Strings Deploy Framework Toolkit

## Remote Execution

**Remote execution** is the term given to the Strings process for remotely executing a distributed script. This process is currently used almost exclusively for deploying code.

### Callback scripts

The remote execution process includes two-callbacks, "pre-exec.sh" and "post-exec.sh", which are called before and after execution of the customer's script.

**pre-exec.sh**

This script is executed before the customer's script is executed. It is responsible for:
* Managing a LOCK file to prevent two scripts from being executed simultaneously
* Downloading the customer script from the source

The script is passed several parameters
* --source-type Indicates where the script is going to pulled from. (ex: git)
* --url The respository url (ex: git@github.com:Bitlancer/strings-deploy-toolkit.git)
* --path The relative path to the script within the repository

**post-exec.sh**

This script is executed after the customer's script is executed. It is responsible for:
* Cleaning up (deleting the content downloaded as part of the customer's script)
* Removing the LOCK file

### Customer script

#### Parameters

The customer's script is passed any parameters the customer supplied when configuring the script in the dashboard. Additionally
the script will passed a parameter "--server-list" containing a list of servers and server attributes which are associated with
script.

**--server-list**



### Jump server configuration

* A user "remoteexec", set in the API configuration, must be created on the jump server. The account will be used by the API to execute the script on the customer's behalf.
* Create a "deploy" directory within the remoteexec's home directory.
* Pull down the pre and post execution template scripts and put them in the "deploy" directory



* Managing a LOCK file to prevent two scripts from being executed simultaneously
  * Downloading the customer script from the source
