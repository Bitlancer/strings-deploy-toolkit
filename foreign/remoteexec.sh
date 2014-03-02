#!/bin/bash
# vim: set filetype=sh

# Includes
source ./libs/logging.inc
source ./libs/common.inc

# Global variables

## Organization specific vars
source org-vars.inc

## Default verbosity, can be overriden by argument
VERBOSITY=$LOG_LEVEL_DEBUG

## Whether to execute exit callbacks
## Very helpful for debugging
#EXEC_EXIT_CALLBACKS=1

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

CLASS_TYPE=$(get_input_value "--class-type" "$@")
if [ $? -ne 0 ] || [ -z "$CLASS_TYPE" ]; then
  error "Required argument --class-type is missing."
  exit 1
fi

CLASS_NAME=$(get_input_value "--class-name" "$@")
if [ $? -ne 0 ] || [ -z "$CLASS_NAME" ]; then
  error "Required argument --class-name is missing."
  exit 1
fi

UNDO=$(get_input_value "--undo" "$@")
if [ -z "$UNDO" ]; then
  UNDO=0
fi

## Decide what to do
if [ $RE_TYPE == "Application" ] || [ $RE_TYPE == "a" ]; then
  if [ $UNDO -eq 0 ]; then
    notify "Setting up application $NAME"
  else
    notify "Reverting application $NAME"
  fi
  source app.inc
  deploy_app $@
  exit $?
else
  error "Unexpected type $RE_TYPE"
  exit 1
fi

