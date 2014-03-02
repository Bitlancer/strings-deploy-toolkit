# vim: set filetype=sh:

function build_and_distribute_deploy_package {
  # Build and distribute a deploy package

  local foreign_run_dir="$1"
  local servers="$2"
  local build_deploy_package_func="$3"

  $build_deploy_package_func "deploy_pkg.tgz"
  if [ $? -ne 0 ]; then
    if [ -f "deploy_pkg.tgz" ]; then
      rm "deploy_pkg.tgz"
    fi
    return 1
  fi
  distribute_deploy_package "$foreign_run_dir" "deploy_pkg.tgz" "$app_servers"
  local exit_code=$?
  rm "deploy_pkg.tgz"
  if [ $exit_code -ne 0 ]; then
    return 1
  fi

  return 0
}

function distribute_deploy_package {

  local remote_run_dir="$1"
  local deploy_pkg_tarball="$2"
  local servers="$3"

  # Register remote cleanup
  register_exit_callback "cleanup_foreign_remoteexec '$remote_run_dir' '$servers'"

  # Distribute the deploy package and extract on each server
  notify "Distributing the deploy package to each server"
  for server in $servers; do
    ssh $SSH_OPTIONS $server "if [ ! -d $remote_run_dir ]; then mkdir $remote_run_dir; fi"
    scp -r $SSH_OPTIONS $deploy_pkg_tarball $server:$remote_run_dir/
    if [ $? -ne 0 ]; then
      error "Failed to copy deploy package to $server"
      return 1
    fi
    ssh $SSH_OPTIONS $server "cd $remote_run_dir; tar -zxf $deploy_pkg_tarball"
    if [ $? -ne 0 ]; then
      error "Failed to extract deploy package on $server"
      return 1
    fi
  done

  return 0
}

function swift_download_container {
  # Download an entire Openstack swift container

  local error_code=0

  local auth_url="$1"
  local user="$2"
  local key="$3"
  local container="$4"
  local dest="$5"

  current_dir=$(pwd)
  cd $dest
  
  /usr/bin/swift -A $auth_url -U $user -K $key download $container
  error_code=$?

  cd $current_dir

  return $error_code
}

function swift_download_file {
  # Download a file from Openstack swift

  local auth_url="$1"
  local user="$2"
  local key="$3"
  local container="$4"
  local file="$5"
  local dest="$6"

  /usr/bin/swift -A $auth_url -U $user -K $key download $container $file -o $dest

  return $?
}

function git_clone {
  # Call git clone wrapper to handle special ssh options

  local exit_code=0

  local repo="$1"
  local ref="$2"
  local local_path="$3"

  GIT_SSH=./git-wrapper.sh git clone --quiet "$repo" --branch "$ref" "$local_path"
  exit_code=$?
  unset GIT_SSH

  return $exit_code
}
