#!/bin/sh

options="-o StrictHostKeyChecking=no"

if [ -n "$GIT_SSH_KEY" ]; then
  options+="-i $GIT_SSH_KEY"
fi

/usr/bin/ssh "$options" "$@"
