# vim: set filetype=sh:

function deploy_app {
  # Entry point for deploying an application

  if [ $class_type == 'profile' ]; then
    case $class_name in
      $app_server_profile )
        if [ $undo -eq 1 ]; then
          app_server_undo_logic
          return $?
        else
          app_server_logic
          return $?
        fi
        ;;
     esac
  fi
 
  return 0
}

function app_server_logic {

  local output=""
  local app_doc_root=/var/www/vhosts/$app_name

  # Create the app doc root to prevent apachectl -t
  # from complaining about the missing doc root
  if [ ! -d $app_doc_root ]; then
    sudo mkdir -p $app_doc_root
  fi

  # Update apache configs

  ## Backup the existing configs
  warn "Need to remove old backups"
  sudo cp -R /etc/httpd/conf.d/ "/etc/httpd/conf.prev.$exec_id/"
  if [ $? -ne 0 ]; then
    error "Failed to backup apache configs"
    return 1
  fi

  ## Copy over the new configs
  sudo cp -f deploy_pkg/apache_configs/* /etc/httpd/conf.d/
  if [ $? -ne 0 ]; then
    error "Failed to copy new apache configs into place"
    return 1
  fi

  ## Test the configs
  output=$(sudo apachectl -t 2>&1)
  if [ $? -ne 0 ]; then
    error "New apache configs did not pass a syntax check"
    error "  $output"
    return 1
  fi

  # Deploy the code
  sudo cp -R $app_doc_root $app_doc_root.prev.$exec_id
  if [ $? -ne 0 ]; then
    error "Unable to backup existing application code."
    return 1
  fi
  sudo rm -rf $app_doc_root
  if [ $? -ne 0 ]; then
    error "Unable to (re)create application code directory."
    return 1
  fi
  sudo mv deploy_pkg/app_code $app_doc_root/
  if [ $? -ne 0 ]; then
    error "Unable to move new application code into place."
    return 1
  fi

  # Restart apache
  debug "Restarting apache"
  output=$(sudo apachectl restart 2>&1)
  if [ $? -ne 0 ]; then
    error "Failed to restart Apache."
    error "  $output"
    return 1
  fi

  return 0
}

function app_server_undo_logic {
  # Undo

  error "Not implemented"
  return 1;
}
