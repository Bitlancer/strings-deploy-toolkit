# vim: set filetype=sh:

# Includes
source ./libs/app.inc

# Functions

function deploy_app {
  # Entry point for deploying an application

  # Parse input for anything specific to app deployment
  code_repo=$(get_input_value "--repo" "$@")
  if [ $? -ne 0 ] || [ -z "$code_repo" ]; then
    error "Required argument --repo is missing."
    return 1
  fi

  code_branch=$(get_input_value "--branch" "$@")
  if [ $? -ne 0 ]; then
    code_branch="master"
  fi
  if [ -z "$code_branch" ]; then
    error "The --branch argument needs a value."
    return 1
  fi

  # Resolve app name to a deployment type
  case $app_name in
    "app-name" )
      deployment_type="wordpress"
      ;;
    * )
      error "Unexpected application $app_name encountered."
      return 1
  esac
  debug "Deployment type for $app_name is $deployment_type"

  # Resolve a deployment type to an entry point 
  case $deployment_type in
    "wordpress" )
      deploy_app_wordpress "$@"
      return $?
      ;;
    * )
      error "Unexpected deployment type encountered."
      return 1
  esac
}

function deploy_app_wordpress {
  # Entry point for deploying a wordpress application

  deploy_app_generic "$@"
  return $?
}

function deploy_app_generic {
  # Logic for deploying a generic app
  # Note: this could have been architected to be more generic, however
  # in most cases order of execution is probably important so lets
  # let each organization define their own logic

  local foreign_run_dir="~/$exec_id"

  # Build deploy packages and distribute
  notify "Building and distributing deploy package(s)"

  ## App servers
  local app_servers="${profile_servers_map[$app_server_profile]}"
  if [ -z "$app_servers" ]; then
    warn "No $app_server_profile found"
  else
    build_and_distribute_deploy_package "$foreign_run_dir" "$app_servers" "build_deploy_package_app_servers"
    if [ $? -ne 0 ]; then
      return 1
    fi
  fi
 
  # Execute remoteexec script on each server
  notify "Executing the remoteexec script on each server"

  ## App servers
  app_servers="${profile_servers_map[$app_server_profile]}"
  run_foreign_remoteexec "$foreign_run_dir" "profile" "$app_server_profile" "$app_servers"
  if [ $? -ne 0 ]; then
    revert_foreign_remoteexec "$exec_id" "$foreign_run_dir" "profile" "$app_server_profile" "$app_servers"
  fi

}

function build_deploy_package_app_servers {
  # Build a deploy package for "app servers"

  debug "Building app servers deploy package"
  
  local deploy_pkg_tarball="$1"

  local deploy_pkg_dir=${1%.*}
  local code_dir=$deploy_pkg_dir/app_code
  local apache_config_dir=$deploy_pkg_dir/apache_configs

  mkdir -p $code_dir $apache_config_dir
  if [ $? -ne 0 ]; then
    error "Failed to create deploy package directory"
    return 1
  fi

  ## Code
  debug "Cloning app code repository $code_repo at $code_branch"
  git_clone "$code_repo" "$code_branch" "$code_dir"
  if [[ $? -ne 0 ]]; then
    error "Failed to clone application code repo"
    return 1
  fi

  ## Apache configs
  debug "Cloning apache config repo $apache_config_repo"
  git_clone "$apache_config_repo" "master" "$apache_config_dir/tmp"
  if [[ $? -ne 0 ]]; then
    error "Failed to clone apache config repo"
    return 1
  fi
  mv $apache_config_dir/tmp/apache/$app_name/* "$apache_config_dir"
  if [[ $? -ne 0 ]]; then
    error "Failed to extract apache configs from config repo clone"
    return 1
  fi
  rm -rf $apache_config_dir/tmp

  ## Tar up the deploy package
  tar -czf $deploy_pkg_tarball $deploy_pkg_dir
  if [[ $? -ne 0 ]]; then
    error "Failed to create deploy package tarball"
    return 1
  fi
  rm -rf $deploy_pkg_dir

  return 0
}
