Strings Deploy Toolkit
===============================

A framework for orchestrating commands against one or more servers. This 
framework is most often used for application deployments.

## How it works

Strings will execute `remoteexec.sh` passing it several parameters including
the application name and list of servers that are a member of that application. 

## Getting started

The deploy toolkit contains enough boilerplate code to deploy a generic web
application from git.

### Setup

#### Jump Server

A jump server is spun up in each target/region you are hosting servers. The
jump server serves as a staging area within your environment where Strings
will orchestrate the deploy process. Currently, this is a task that must be
completed by a Strings tech.

#### Git

In order for Strings to pull in your code during deployment, you must configure
a ssh key-pair that will permit Strings access to all of your code repositories.
If your code is hosted on Github, you likely already created a user like this
for accessing Strings Puppet repositories. You can re-use this account for
deploy by granting this user access to your code repositories.

#### Strings User

Within your Strings account you must create a user account for code deployments.
This user will be granted access to any servers you want to deploy code to with
appropriate sudo privileges.

Create a user `remoteexec` with user-level privileges within Strings. Create a
new ssh key for this user and save the private key. The Strings tech will need
this private key to setup any Jump Servers.

Create a team `remoteexec` and add the `remoteexec` user to it.

Create a sudo role `remoteexec` with the following commands:
* /bin/cp
* /bin/mv
* /bin/rm
* /bin/mkdir
* /usr/sbin/apachectl

#### Application Configuration

##### Strings Deploy User Privileges

Grant the `remoteexec` user login and sudo privileges and add the 
`remoteexec` sudo role as a sudo privilege.

##### Configure the deploy script

If you have not done so already, clone this repository into your own account
and make sure the deploy user has access to it. Next, click "Add script" on
the application page. Fill in the repository url with the ssh version of your
version of this repository. The script path should just be "remoteexec.sh".
Finally, define the parameters that will be passed to the deploy script at
runtime. For this example, you should add the following

```
--verbosity 4 --repo my-code-repo
```

where my-code-repo is the ssh version of your repository url. Setting 
verbosity to 4 (debug), will provide additional output so you can
get a better idea of what's going on behind the scenes.

Click "Save" to complete the setup.

#### Deploy

Select "Deploy" from the action menu next to the appropriate deploy script to
launch the deploy process. You will be redirected to a screen that provides the
output from the deploy script.

## Components

### remoteexec.sh

This script is responsible for orchestrating the deployment process. It is called
directly by Strings with several parameters including the application name and
server list. Its direct responsibilities include:

* Locking to prevent deployment collisions
* Building deployment packages, containing code and other data, and distributing
them to the appropriate servers
* Launching the client remote exec script on each server in the req'd order
* Error handling

### org-vars.inc

Contains any organization specific variables.

### app.inc

Contains any organization specific code related to applicaton deployment.

### git-wrapper.sh

A wrapper script that supports setting custom SSH options, such as an alternate
key file or disabling strict key checking, when executing git commands.

### libs/

Contains a number of shared "libraries" to assist with deployments.

### foreign/

Contains a separate remotexec.sh and associated includes for handling
deployments on each individual server.

