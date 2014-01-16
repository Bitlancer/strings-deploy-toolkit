# vim: set filetype=sh:

log_level_error=1
log_level_warn=2
log_level_info=3
log_level_debug=4

function error {
  log $log_level_error "$1"
}

function warn {
  log $log_level_warn "$1"
}

function notify {
  log $log_level_info "$1"
}

function debug {
  log $log_level_debug "$1"
}

function log_level_descr {
  case "$1" in
    $log_level_error )
      echo "error"
      ;;
    $log_level_warn )
      echo "warn"
      ;;
    $log_level_info )
      echo "info"
      ;;
    $log_level_debug )
      echo "debug"
      ;;
    * )
      echo "unkn"
      return 1
      ;;
  esac
  return 0
}

function log {
  if [ $verbosity -ge $1 ]; then
    hname=$(hostname -s)
    date_str=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    severity=$(log_level_descr $1)
    printf "%s  %10s  %6s  %s\n" "$date_str" "$hname" "$severity" "$2"
  fi
}
