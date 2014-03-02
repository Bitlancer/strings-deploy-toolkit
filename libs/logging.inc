# vim: set filetype=sh:

LOG_LEVEL_ERROR=1
LOG_LEVEL_WARN=2
LOG_LEVEL_INFO=3
LOG_LEVEL_DEBUG=4

VERBOSITY=$LOG_LEVEL_DEBUG

function error {
  log $LOG_LEVEL_ERROR "$1"
}

function warn {
  log $LOG_LEVEL_WARN "$1"
}

function notify {
  log $LOG_LEVEL_INFO "$1"
}

function debug {
  log $LOG_LEVEL_DEBUG "$1"
}

function log_level_descr {
  case "$1" in
    $LOG_LEVEL_ERROR )
      echo "error"
      ;;
    $LOG_LEVEL_WARN )
      echo "warn"
      ;;
    $LOG_LEVEL_INFO )
      echo "info"
      ;;
    $LOG_LEVEL_DEBUG )
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
  if [ $VERBOSITY -ge $1 ]; then
    hname=$(hostname -s)
    date_str=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    severity=$(log_level_descr $1)
    printf "%s  %10s  %6s  %s\n" "$date_str" "$hname" "$severity" "$2"
  fi
}
