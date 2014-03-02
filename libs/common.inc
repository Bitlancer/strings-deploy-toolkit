# vim: set filetype=sh:

## Array of callbacks to be exec'd on exit
typeset -a ON_EXIT_CALLBACKS

## Whether to execute exit callbacks
EXEC_EXIT_CALLBACKS=1

function run_foreign_remoteexec {
  # Execute the remoteexec script on each server.

  local remote_run_dir="$1"
  local class_type="$2"
  local class_name="$3"
  local servers="$4"

  notify "Running remoteexec on [${servers[@]}]"
  local failed=0
  for server in $servers; do
    scp -r $SSH_OPTIONS foreign/* $server:$remote_run_dir/
    if [ $? -ne 0 ]; then
      error "Failed to copy remoteexec scripts to $server"
      failed=1
      break;
    fi
    local cmd="cd $remote_run_dir; ./remoteexec.sh --verbosity $VERBOSITY --exec-id $EXEC_ID --type $RE_TYPE --name '$NAME' --class-type $class_type --class-name '$class_name'"
    ssh $SSH_OPTIONS $server "$cmd"
    if [ $? -ne 0 ]; then
      error "Remoteexec failed on $server."
      failed=1
      break
    fi
  done

  return $failed
}

function revert_foreign_remoteexec {
  # Try to undo the actions performed by the supplied remoteexec

  local remote_run_dir="$1"
  local class_type="$2"
  local class_name="$3"
  local servers="$4"

  notify "Trying to revert [${servers[@]}] to their previous state ($exec_id~1)"
  for server in $servers; do
    ssh $SSH_OPTIONS $server "cd $remote_run_dir; [ -f remoteexec.sh ]"
    if [ $? -eq 0 ]; then # Only need to revert if the remoteexec script exists
      cmd="cd $remote_run_dir; ./remoteexec.sh --verbosity $VERBOSITY --undo 1 --exec-id $EXEC_ID --type $RE_TYPE --name '$NAME' --class-type $class_type --class-name '$class_name'"
      ssh $SSH_OPTIONS $server "$cmd"
      if [ $? -ne 0 ]; then
        error "Failed to revert $server to its state prior to $exec_id"
        revert_failed_on+=($server)
      fi
    fi
  done

  if [ "${#revert_failed_on[@]}" -gt 0 ]; then
    return 1
  fi

  return 0
}

function cleanup_foreign_remoteexec {
  # Clean up a remoteexec execution on a foreign server

  local foreign_run_dir="$1"
  local servers="$2"

  notify "Cleaning up remoteexec run directory on [$servers]"
  for server in $servers; do
    ssh $SSH_OPTIONS $server "if [ -d $foreign_run_dir ]; then rm -rf $foreign_run_dir; fi"
    if [ $? -ne 0 ]; then
      error "Failed to remove run directory '$foreign_run_dir' on $server"
      return 1 
    fi
  done
}

function parse_server_list {
  # Parse the supplied arg into a map profile => servers
  # and store the result in the global variable profile_server_map.
  # The arg is a server list formatted as such:
  # fqdn,role,profile1,profile2,...;fqdn,role,profile1,...;...
  OFS=$IFS
  IFS=';'
  read -ra servers <<< "$1"
  for server in "${servers[@]}"; do
    IFS=','
    read -ra server_attrs <<< "$server"
    local fqdn="${server_attrs[0]}"
    local role="${server_attrs[1]}"
    unset server_attrs[0]
    unset server_attrs[1]
    # Populate global role => servers map
    local existing_role_servers="${ROLE_SERVERS_MAP["$role"]}"
    if [ -n "$existing_role_servers" ]; then
      ROLE_SERVERS_MAP["$role"]+=" "
    fi
    ROLE_SERVERS_MAP["$role"]+="$fqdn"
    # Populate global profile => servers map
    for profile in "${server_attrs[@]}"; do
      local existing_servers="${PROFILE_SERVERS_MAP["$profile"]}"
      if [ -n "$existing_servers" ]; then
        PROFILE_SERVERS_MAP["$profile"]+=" "
      fi
      PROFILE_SERVERS_MAP["$profile"]+="$fqdn"
    done
  done
  IFS=$OFS 
}

function get_input_value {
  local opt="$1"
  shift;
  while [[ $# -gt 0 ]]; do
    local c_opt="$1"
    shift;
    if [ "$c_opt" == "$opt" ]; then
      if [[ "$1" == "-"* ]]; then
        echo ""
      else
        echo "$1"
      fi
      return 0
    fi
  done
  return 1 
}

function acquire_lock {
  # Check if an existing lock is in place
  #  Create a lock if one does not already exist
  #  Overwrite a lock which has expired
  if [[ -f $1 ]]; then
    # Check if the existing lock has expired
    warn "Not implemented - lock expiration"
    return 1
  else
    date +%s > $1
    return 0
  fi
}

function rm_lock {
  # Remove lock file
  rm -f $1
  if [[ $? -ne 0 ]]; then
    error "Unable to remove lock file"
  fi
}

function register_exit_callback {
 # Register a cmd, func, etc to be exec'd on exit
  ON_EXIT_CALLBACKS+=("$1")
}

function clean_exit {
  # Exit handler

  # Should I exec each callback?
  # Helpful for debugging
  if [[ $EXEC_EXIT_CALLBACKS -eq 0 ]]; then
    return 1
  fi

  # Exec each callback in reverse order (emulate stack)
  for (( idx=${#ON_EXIT_CALLBACKS[@]}-1 ; idx>=0 ; idx-- )) ; do
    eval "${ON_EXIT_CALLBACKS[$idx]}"
  done

  return 0
}

function md5str {
  echo "$1" | md5sum | cut -d" " -f1
}
