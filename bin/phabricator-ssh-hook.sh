#!/bin/sh

set -e
set -u

if [ "$1" != "$PH_VCS_USER" ];
  then
  exit 1
fi

exec "$PH_ROOT/phabricator/bin/ssh-auth" $@
