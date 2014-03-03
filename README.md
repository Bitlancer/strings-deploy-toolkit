Strings Deploy Toolkit
===============================

A framework for orchestrating commands against one or more servers. This 
framework is most often used for application deployments.

The framework contains enough boilerplate code to deploy a generic web
application from git.

## How it works

1) Strings executes `remoteexec.sh`

Example:

```
remoteexec.sh --exec-id 836 --type Application --name test --server-list python.dfw01.int.example-infra.net,exampleorg::role::lamp_server,stringed::profile::apache_phpfpm,stringed::profile::mysql;anaconda.dfw01.int.example-infra.net,exampleorg::role::lamp_server,stringed::profile::apache_phpfpm,stringed::profile::mysql --verbosity 4 --repo git@github.com:Bitlancer/strings-sample-app.git
```

2) Define the deploy orchestration logic within `app.inc`. 

3) Define the endpoint deploy logic within `foreign/app.inc`.

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

