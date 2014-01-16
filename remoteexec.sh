#!/bin/bash
# vim: set filetype=sh

# Includes
source libs/logging.inc
source libs/common.inc

# Global variables

## Organization specific vars
source org-vars.inc

## Default verbosity, can be overriden by argument
verbosity=$log_level_debug

## Remote execution lock file
remoteexeclockfile=~/remoteexec.lck

## Array of callbacks to be exec'd on exit
typeset -a on_exit_callbacks

## Whether to execute exit callbacks
## Very helpful for debugging
exec_exit_callbacks=1

## Map of roles => servers
typeset -A role_servers_map

## Map or profiles => servers
typeset -A profile_servers_map

## Default ssh options appended to each ssh or scp exec
ssh_options="-q -o StrictHostKeyChecking=no"

# Main

## Register the exit trap
trap clean_exit EXIT

## Parse input that is generic to all remote exec actions
new_verbosity=$(get_input_value "--verbosity" "$@")
if [ $? -eq 0 ]; then
  verbosity=$new_verbosity
fi

exec_id=$(get_input_value "--exec-id" "$@")
if [ $? -ne 0 ] || [ -z "$exec_id" ]; then
  error "Required argument --exec-id is missing."
  exit 1
fi

re_type=$(get_input_value "--type" "$@")
if [ $? -ne 0 ] || [ -z "$re_type" ]; then
  error "Required argument --type is missing."
  exit 1
fi

name=$(get_input_value "--name" "$@")
if [ $? -ne 0 ] || [ -z "$name" ]; then
  error "Required argument --name is missing."
  exit 1
fi

server_list=$(get_input_value "--server-list" "$@")
if [ $? -ne 0 ] || [ -z "$server_list" ]; then
  error "Required argument --server-list is missing."
  exit 1
fi
parse_server_list "$server_list"

## Acquire the remoteexec lock
notify "Acquiring remote exec lock"
acquire_lock $remoteexeclockfile
if [ $? -ne 0 ]; then
  error "Failed to acquire remoteexec lock."
  exit 1
fi
register_exit_callback "rm $remoteexeclockfile && notify 'Releasing remote exec lock'"

## Decide what to do
if [ $re_type == "Application" ] || [ $re_type == "a" ]; then
  app_name=$name
  notify "Deploying application $app_name"
  source app.inc
  deploy_app $@
  exit $?
else
  error "Unexpected type $re_type"
  exit 1
fi

