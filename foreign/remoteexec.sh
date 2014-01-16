#!/bin/bash
# vim: set filetype=sh

# Includes
source ./libs/logging.inc
source ./libs/common.inc

# Global variables

## Organization specific vars
source org-vars.inc

## Default verbosity, can be overriden by argument
verbosity=$log_level_debug

## Array of callbacks to be exec'd on exit
typeset -a on_exit_callbacks

## Whether to execute exit callbacks
## Very helpful for debugging
exec_exit_callbacks=1

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

class_type=$(get_input_value "--class-type" "$@")
if [ $? -ne 0 ] || [ -z "$class_type" ]; then
  error "Required argument --class-type is missing."
  exit 1
fi

class_name=$(get_input_value "--class-name" "$@")
if [ $? -ne 0 ] || [ -z "$class_name" ]; then
  error "Required argument --class-name is missing."
  exit 1
fi

undo=$(get_input_value "--undo" "$@")
if [ -z "$undo" ]; then
  undo=0
fi

## Decide what to do
if [ $re_type == "Application" ] || [ $re_type == "a" ]; then
  if [ $undo -eq 0 ]; then
    notify "Setting up application $name"
  else
    notify "Reverting application $name"
  fi
  app_name=$name
  source app.inc
  deploy_app $@
  exit $?
else
  error "Unexpected type $re_type"
  exit 1
fi

