# vim: set filetype=sh:

function deploy_app {
  # Entry point for deploying an application

  BACKUP_DIR=~/backup.$EXEC_ID.$(echo "$CLASS_TYPE|$CLASS_NAME" | md5sum | cut -d" " -f1)

  case $NAME in
    * )
      if [ $CLASS_TYPE == 'profile' ]; then
        case $CLASS_NAME in
          $APP_SERVER_PROFILE )
            if [ $UNDO -eq 1 ]; then
              generic_app_restore
            else
              generic_app_deploy
            fi
            ;;
        esac
      fi
  esac

  return 0
}

function generic_app_deploy {

  local output=""
  local app_doc_root=/var/www/html

  # Create the app doc root if it doesn't exist
  if [ ! -d $app_doc_root ]; then
    output=$(sudo /bin/mkdir -p $app_doc_root 2>&1)
    if [ $? -ne 0 ]; then
      error "Failed to create application document root"
      error "  $output"
      return 1
    fi
  fi

  b_dirs="$app_doc_root"
  generic_backup_restore "backup" "$BACKUP_DIR" "$b_dirs"

  # Deploy the code
  output=$(sudo /bin/rm -rf $app_doc_root 2>&1)
  if [ $? -ne 0 ]; then
    error "Unable to (re)create application code directory."
    error "  $output"
    return 1
  fi
  output=$(sudo /bin/mv deploy_pkg/app_code $app_doc_root/ 2>&1)
  if [ $? -ne 0 ]; then
    error "Unable to move new application code into place."
    error "  $output"
    return 1
  fi

  # Restart apache
  debug "Restarting apache"
  output=$(sudo /usr/sbin/apachectl restart 2>&1)
  if [ $? -ne 0 ]; then
    error "Failed to restart Apache."
    error "  $output"
    return 1
  fi

  return 0
}

function generic_app_restore {
  # Undo

  local output=""
  local app_doc_root=/var/www/html

  b_dirs="$app_doc_root"
  generic_backup_restore "restore" "$BACKUP_DIR" "$b_dirs"

  # Restart apache
  debug "Restarting apache"
  output=$(sudo /usr/sbin/apachectl restart 2>&1)
  if [ $? -ne 0 ]; then
    error "Failed to restart Apache."
    error "  $output"
    return 1
  fi

  return 0;
}

function generic_backup_restore {
  # Backup a list of supplied directories to the supplied backup dir
  # Its critical that the dirs are passed without a trailing /

  local backup_or_restore="$1"
  local backup_dir="$2"
  local dirs="$3"

  local output=""

  local ret=0

  ## Create the backup dir
  if [ ! -d $backup_dir ]; then
    output=$(sudo /bin/mkdir $backup_dir 2>&1)
    if [ $? -ne 0 ]; then
      error "Failed to create the backup dir"
      error "  $output"
      return 1
    fi
  fi
  
  ## Backup the supplied dirs
  for d in $dirs; do
    d_backup_dir=$backup_dir/$(md5str "$d")

    if [ $backup_or_restore == "backup" ]; then
      output=$(sudo /bin/cp -Rp "$d" "$d_backup_dir" 2>&1)
      if [ $? -ne 0 ]; then
        error "Failed to backup dir $d"
        error "  $output"
        ret=1
        break
      fi
    else
      if [ $backup_or_restore == "restore_wipe" ]; then
        output=$(sudo /bin/rm -rf "$d" 2>&1 && mkdir "$d" 2>&1)
        if [ $? -ne 0 ]; then
          error "Failed to wipe and recreate $d"
          error "  $output"
          ret=1
        fi
      fi
      output=$(sudo /bin/cp -Rfp $d_backup_dir/ $d 2>&1)
      if [ $? -ne 0 ]; then
        error "Failed to restore dir $d"
        error "  $output"
        ret=1
      fi
    fi
  done

  return $ret
}
