#!/bin/bash

if [ $# -lt 1 ]
then
  cat <<-EOF
Usage:
  run   - Start supervisord in foreground mode
  shell - Start a bash shell as www user
EOF
  exit
fi

case "$1" in
  # Start supervisor
  run)    echo "Starting supervisord"
          /usr/bin/supervisord -c /srv/etc/supervisor/supervisord.conf
          ;;
  # Start a shell as www user
  shell)  echo "Starting shell"
          sudo -u www -i
          ;;
  *)      echo "Avaliable commands are run, shell"
esac
