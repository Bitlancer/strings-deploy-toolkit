# vim: set filetype=sh:

function build_and_distribute_deploy_package {
  # Build and distribute a deploy package

  local foreign_run_dir="$1"
  local servers="$2"
  local build_deploy_package_func="$3"

  $build_deploy_package_func "deploy_pkg.tgz"
  if [ $? -ne 0 ]; then
    rm "deploy_pkg.tgz"
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
    ssh $ssh_options $server "if [ ! -d $remote_run_dir ]; then mkdir $remote_run_dir; fi"
    scp -r $ssh_options $deploy_pkg_tarball $server:$remote_run_dir/
    if [ $? -ne 0 ]; then
      error "Failed to copy deploy package to $server"
      return 1
    fi
    ssh $ssh_options $server "cd $remote_run_dir; tar -zxf $deploy_pkg_tarball"
    if [ $? -ne 0 ]; then
      error "Failed to extract deploy package on $server"
      return 1
    fi
  done

  return 0
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
