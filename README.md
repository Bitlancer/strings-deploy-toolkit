Strings Deploy Toolkit
===============================

Framework for orchestrating commands against one or more servers. Currently used
almost exclusively for application deployments.

## Components

### org-vars.inc

Contains any organization specific variables.

### remoteexec.sh

This script is responsible for orchestrating the deployment process. It is called
directly by strings with several parameters including the application name and
server list. Its direct responsibilities include:

* Locking to prevent deployment collisions
* Building deployment packages, containing code and other data, and distributing
them to the appropriate servers
* Launching the client remote exec script on each server in the req'd order
* Error handling

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
