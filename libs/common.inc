# vim: set filetype=sh:

function run_foreign_remoteexec {
  # Execute the remoteexec script on each server.

  local remote_run_dir="$1"
  local class_type="$2"
  local class_name="$3"
  local servers="$4"

  notify "Running remoteexec on ${servers[@]}"
  local failed=0
  for server in $servers; do
    scp -r $ssh_options foreign/* $server:$remote_run_dir/
    if [ $? -ne 0 ]; then
      error "Failed to copy remoteexec scripts to $server"
      failed=1
      break;
    fi
    local cmd="cd $remote_run_dir; ./remoteexec.sh --exec-id $exec_id --type $re_type --name '$name' --class-type $class_type --class-name '$class_name'"
    ssh $ssh_options $server "$cmd"
    if [ $? -ne 0 ]; then
      error "Remoteexec failed on $server."
      failed=1
      break
    fi
  done

  return $failed
}

function revert_foreign_remotexec {
  # Try to undo the actions performed by the supplied remoteexec

  local exec_id="$1"
  local remote_run_dir="$2"
  local class_type="$3"
  local class_name="$4"
  local servers="$5"

  notify "Trying to revert ${servers[@]} to their state prior to $exec_id"
  for server in $servers; do
    ssh $ssh_options $server "cd $remote_run_dir; [ -f remoteexec.sh ]"
    if [ $? -eq 0 ]; then # Only need to revert if the remoteexec script exists
      cmd="cd $remote_run_dir; ./remoteexec.sh --undo 1 --exec-id $exec_id --type $re_type --name $name --class-type $class_type --class-name $class_name"
      ssh $ssh_options $server "$cmd"
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

  local forgeign_run_dir="$1"
  local servers="$2"

  notify "Cleaning up remoteexec run directory on $servers"
  for server in $servers; do
    ssh $ssh_options $server "if [ -d $forgeign_run_dir ]; then rm -rf $forgeign_run_dir; fi"
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
    local existing_role_servers="${role_servers_map["$role"]}"
    if [ -n "$existing_role_servers" ]; then
      role_servers_map["$role"]+=" "
    fi
    role_servers_map["$role"]+="$fqdn"
    # Populate global profile => servers map
    for profile in "${server_attrs[@]}"; do
      local existing_servers="${profile_servers_map["$profile"]}"
      if [ -n "$existing_servers" ]; then
        profile_servers_map["$profile"]+=" "
      fi
      profile_servers_map["$profile"]+="$fqdn"
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
  on_exit_callbacks+=("$1")
}

function clean_exit {
  # Exit handler

  # Should I exec each callback?
  # Helpful for debugging
  if [[ $exec_exit_callbacks -eq 0 ]]; then
    return 1
  fi

  # Exec each callback in reverse order (emulate stack)
  for (( idx=${#on_exit_callbacks[@]}-1 ; idx>=0 ; idx-- )) ; do
    eval "${on_exit_callbacks[$idx]}"
  done

  return 0
}
