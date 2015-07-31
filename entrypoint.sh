#!/bin/bash

set -e
set -u

WWW_USER=www
ETC_ROOT=/srv/etc
SSHD_KEYS_ROOT=$ETC_ROOT/sshd_keys
OLD_SSHD_KEYS_ROOT=/etc/ssh

# Print usage
if [ $# -lt 1 ]
then
  cat <<-EOF
Usage:
  run   - Start supervisord in foreground mode
  shell - Start a bash shell as www user
EOF
  exit
fi

# Ensure one ssh_host_key, if not exists, copy from /etc/ssh/
ensure_sshd_key() {
  KEY_FILE=$SSHD_KEYS_ROOT/$1
  OLD_KEY_FILE=$OLD_SSHD_KEYS_ROOT/$1
  if [ ! -f $KEY_FILE ]; then
    echo "ssh_host_key copied $KEY_FILE"
    cp $OLD_KEY_FILE      $KEY_FILE
    cp $OLD_KEY_FILE.pub  $KEY_FILE.pub
  fi
  chown root:root $KEY_FILE
  chmod 700 $KEY_FILE
}

# Ensure multiple ssh_host_key
ensure_all_sshd_keys() {
  ensure_sshd_key "ssh_host_dsa_key"
  ensure_sshd_key "ssh_host_rsa_key"
  ensure_sshd_key "ssh_host_ecdsa_key"
  ensure_sshd_key "ssh_host_ed25519_key"
}

case "$1" in
  # Start supervisor
  run)        echo "Starting supervisord"
              ensure_all_sshd_keys
              /usr/bin/supervisord -c $ETC_ROOT/supervisor/supervisord.conf
              ;;
  # Start a shell as www user
  www_shell)  echo "Starting shell for www user"
              ensure_all_sshd_keys
              sudo -u $WWW_USER -i
              ;;
  # Start a root shell
  root_shell) echo "Starting root shell"
              ensure_all_sshd_keys
              bash
              ;;
  *)          echo "Avaliable commands are: run, www_shell, root_shell"
esac
