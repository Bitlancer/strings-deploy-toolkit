# vim: set filetype=sh:

# Includes
source ./libs/app.inc

# Functions

function deploy_app {
  # Entry point for deploying an application

  # Resolve app name to a deployment type
  case $NAME in
    * )
      deployment_type="generic"
      ;;
  esac
  debug "Deployment type for $NAME is $deployment_type"

  # Resolve a deployment type to an entry point 
  case $deployment_type in
    "generic" )
      deploy_app_generic "$@"
      return $?
      ;;
    * )
      error "Unexpected deployment type encountered."
      return 1
  esac
}

function deploy_app_generic {
  # Logic for deploying a generic app
  # Note: this could have been architected to be more generic, however
  # in most cases order of execution is probably important so lets
  # let each organization define their own logic

  local foreign_run_dir="~/$EXEC_ID"

  # Parse input for anything specific to app deployment
  CODE_REPO=$(get_input_value "--repo" "$@")
  CODE_BRANCH=$(get_input_value "--branch" "$@")
  local cloudfiles_credentials=$(get_input_value "--cloud-files-credentials" "$@")
  if [ $? -eq 0 ] && [ ! -z "$cloudfiles_credentials" ]; then
    CLOUDFILES_USER=$(echo $cloudfiles_credentials | cut -d, -f1)
    CLOUDFILES_KEY=$(echo $cloudfiles_credentials | cut -d, -f2)
  fi 

  # Build deploy packages and distribute
  notify "Building and distributing deploy package(s)"

  ## App servers
  local app_servers="${PROFILE_SERVERS_MAP[$APP_SERVER_PROFILE]}"
  if [ -z "$app_servers" ]; then
    warn "No $APP_SERVER_PROFILE found"
  else
    build_and_distribute_deploy_package "$foreign_run_dir" "$app_servers" "build_deploy_package_generic"
    if [ $? -ne 0 ]; then
      return 1
    fi
  fi
 
  # Execute remoteexec script on each server
  notify "Executing the remoteexec script on each server"

  ## App servers
  app_servers="${PROFILE_SERVERS_MAP[$APP_SERVER_PROFILE]}"
  run_foreign_remoteexec "$foreign_run_dir" "profile" "$APP_SERVER_PROFILE" "$app_servers"
  if [ $? -ne 0 ]; then
    revert_foreign_remoteexec "$foreign_run_dir" "profile" "$APP_SERVER_PROFILE" "$app_servers"
  fi

}

function build_deploy_package_generic {
  # Build a deploy package for generic "app servers"

  debug "Building app servers deploy package"

  local output=""
  
  local deploy_pkg_tarball="$1"

  local deploy_pkg_dir=${1%.*}
  local code_dir=$deploy_pkg_dir/app_code

  mkdir -p $code_dir
  if [ $? -ne 0 ]; then
    error "Failed to create deploy package directory"
    return 1
  fi

  ## Code
  debug "Cloning app code repository $CODE_REPO at $CODE_BRANCH"
  if [ -z "$CODE_REPO" ]; then
    error "Required argument --repo is missing."
    return 1
  fi
  if [ -z "$CODE_BRANCH" ]; then
    CODE_BRANCH="master"
  fi
  git_clone "$CODE_REPO" "$CODE_BRANCH" "$code_dir"
  if [[ $? -ne 0 ]]; then
    error "Failed to clone application code repo"
    return 1
  fi

  ## Tar up the deploy package
  tar -czf $deploy_pkg_tarball $deploy_pkg_dir
  if [[ $? -ne 0 ]]; then
    error "Failed to create deploy package tarball"
    return 1
  fi
  rm -rf $deploy_pkg_dir

  return 0
}
