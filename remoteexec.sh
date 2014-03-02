#!/bin/bash
# vim: set filetype=sh

# Includes
source libs/logging.inc
source libs/common.inc

# Global variables

## Organization specific vars
source org-vars.inc

VERBOSITY=$LOG_LEVEL_DEBUG

## Remote execution lock file
REMOTE_EXEC_LOCK_FILE=~/remoteexec.lck

## Whether to execute exit callbacks
## Very helpful for debugging
#EXEC_EXIT_CALLBACKS=1

## Map of roles => servers
typeset -A ROLE_SERVERS_MAP

## Map or profiles => servers
typeset -A PROFILE_SERVERS_MAP

## Default ssh options appended to each ssh or scp exec
SSH_OPTIONS="-q -o StrictHostKeyChecking=no"

# Main

## Register the exit trap
trap clean_exit EXIT

## Parse input that is generic to all remote exec actions
NEW_VERBOSITY=$(get_input_value "--verbosity" "$@")
if [ $? -eq 0 ]; then
  VERBOSITY=$NEW_VERBOSITY
fi

debug "Arguments: $*"

EXEC_ID=$(get_input_value "--exec-id" "$@")
if [ $? -ne 0 ] || [ -z "$EXEC_ID" ]; then
  error "Required argument --exec-id is missing."
  exit 1
fi

RE_TYPE=$(get_input_value "--type" "$@")
if [ $? -ne 0 ] || [ -z "$RE_TYPE" ]; then
  error "Required argument --type is missing."
  exit 1
fi

NAME=$(get_input_value "--name" "$@")
if [ $? -ne 0 ] || [ -z "$NAME" ]; then
  error "Required argument --name is missing."
  exit 1
fi

SERVER_LIST=$(get_input_value "--server-list" "$@")
if [ $? -ne 0 ] || [ -z "$SERVER_LIST" ]; then
  error "Required argument --server-list is missing."
  exit 1
fi
parse_server_list "$SERVER_LIST"

## Acquire the remoteexec lock
notify "Acquiring remote exec lock"
acquire_lock $REMOTE_EXEC_LOCK_FILE
if [ $? -ne 0 ]; then
  error "Failed to acquire remoteexec lock."
  exit 1
fi
register_exit_callback "rm $REMOTE_EXEC_LOCK_FILE && notify 'Releasing remote exec lock'"

## Decide what to do
if [ $RE_TYPE == "Application" ] || [ $RE_TYPE == "a" ]; then
  notify "Deploying application $NAME"
  source app.inc
  deploy_app $@
  exit $?
else
  error "Unexpected type $RE_TYPE"
  exit 1
fi

