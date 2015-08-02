#!/bin/bash

# Get MYSQL_PORT_3306_TCP_PORT before strict mode
MYSQL_PORT_3306_TCP_PORT="$MYSQL_PORT_3306_TCP_PORT"

set -e
set -u

# Place preamble.php
place_preamble() {
  # preamble.php
  PRE_CONFIG_PHP=$PH_PRE_ROOT/preamble.php
  TAR_CONFIG_PHP=$PH_ROOT/phabricator/support/preamble.php
  if [ -f $PRE_CONFIG_PHP ]; then
    cp $PRE_CONFIG_PHP $TAR_CONFIG_PHP
  fi
}

# Ensure single run folder
ensure_run_folder() {
  rm -rf   $PH_RUN_ROOT/$1/pid
  rm -rf   $PH_RUN_ROOT/$1/sock
  mkdir -p $PH_RUN_ROOT/$1/pid
  mkdir -p $PH_RUN_ROOT/$1/log
  mkdir -p $PH_RUN_ROOT/$1/sock
}

# Ensure folders
ensure_run_folders() {
  ensure_run_folder phd
  ensure_run_folder php5-fpm
  ensure_run_folder nginx
  ensure_run_folder sshd_vcs
  ensure_run_folder sshd_ctrl
  ensure_run_folder aphlict
  ensure_run_folder supervisor
}

# Ensure permissions
ensure_folder_permissions() {
  # Ensure $PH_WWW_USER owns these folders
  chown -R $PH_WWW_USER:$PH_WWW_USER $PH_ROOT/libphutil $PH_ROOT/arcanist $PH_ROOT/phabricator $PH_ROOT/uploads $PH_ROOT/repos $PH_RUN_ROOT
  # Ensure permission of phabricator-ssh-hook.sh
  chown root:root $PH_BIN_ROOT/phabricator-ssh-hook.sh
  chmod 755 $PH_BIN_ROOT/phabricator-ssh-hook.sh
}

# Ensure a ssh_host_key, if not exists, copy from /etc/ssh/
ensure_sshd_key() {
  KEY_FILE=$PH_ETC_ROOT/sshd_keys/$1
  OLD_KEY_FILE=/etc/ssh/$1
  if [ ! -f $KEY_FILE ]; then
    echo "ssh_host_key copied $KEY_FILE"
    cp $OLD_KEY_FILE      $KEY_FILE
    cp $OLD_KEY_FILE.pub  $KEY_FILE.pub
  fi
  # Ensure key_file owner and permission, or sshd will refuse to start
  chown root:root $KEY_FILE
  chmod 700 $KEY_FILE
}

# Ensure multiple ssh_host_key
ensure_sshd_keys() {
  ensure_sshd_key "ssh_host_dsa_key"
  ensure_sshd_key "ssh_host_rsa_key"
  ensure_sshd_key "ssh_host_ecdsa_key"
  ensure_sshd_key "ssh_host_ed25519_key"
}

# Config set for phabricator
config_set() {
  sudo -u $PH_WWW_USER $PH_ROOT/phabricator/bin/config set $1 $2
}

# Internal configs
do_internal_configs() {
  # Configs for linked mysql
  if [ -n "$MYSQL_PORT_3306_TCP_PORT" ]; then
    config_set mysql.host $MYSQL_PORT_3306_TCP_ADDR
    config_set mysql.user root
    config_set mysql.port $MYSQL_PORT_3306_TCP_PORT
    config_set mysql.pass $MYSQL_ENV_MYSQL_ROOT_PASSWORD
  fi
  # Configs for file storage
  config_set storage.mysql-engine.max-size  0
  config_set storage.local-disk.path        $PH_ROOT/uploads
  config_set repository.default-local-path  $PH_ROOT/repos
  # Configs for phd
  config_set phd.user $PH_WWW_USER
  # Configs for diffusion
  config_set diffusion.ssh-user $PH_VCS_USER
  # Configs for daemons
  config_set phd.pid-directory    $PH_RUN_ROOT/phd/pid
  config_set phd.log-directory    $PH_RUN_ROOT/phd/log
  # Configs for notifications service
  config_set notification.enabled true
  config_set notification.log     $PH_RUN_ROOT/aphlict/log/aphlict.log
  config_set notification.pidfile $PH_RUN_ROOT/aphlict/pid/aphlict.pid
  # Other Configs
  config_set pygments.enabled true
}

# Run Pre configs
do_external_configs() {
  PRE_CONFIG_SH=$PH_PRE_ROOT/config.sh
  if [ -f $PRE_CONFIG_SH ]; then
    chmod +x $PRE_CONFIG_SH
    chown $PH_WWW_USER:$PH_WWW_USER $PRE_CONFIG_SH
    sudo -u $PH_WWW_USER $PRE_CONFIG_SH
  fi
}

# Run configs
do_configs() {
  do_internal_configs
  do_external_configs
}

# Upgrade storage
storage_upgrade() {
  sudo -u $PH_WWW_USER $PH_ROOT/phabricator/bin/storage upgrade --force
}

# phd ctrl
service_ctrl() {
  sudo -u $PH_WWW_USER $PH_ROOT/phabricator/bin/$1 $2
}

# On SIGTERM
on_exit() {
  echo
  echo "## Signal caught..."
  echo
  # Stop supervisord
  kill -SIGTERM $1
  wait $1
  # Stop phd, aphlict
  service_ctrl phd      stop
  service_ctrl aphlict  stop
  # Exit
  exit 0
}

# Preparation

echo
echo "## Preparing..."
echo

place_preamble
ensure_run_folders
ensure_folder_permissions
ensure_sshd_keys
do_configs
storage_upgrade

# Start standalone services

echo
echo "## Starting phd, aphlict..."
echo

service_ctrl phd      start
service_ctrl aphlict  start

# Start supervisord for all other services

echo
echo "## Starting supervisord..."
echo

/usr/bin/supervisord -c $PH_ETC_ROOT/supervisor/supervisord.conf &

PID="$!"

# Trapping SIGTERM by docker stop
trap "on_exit $PID" SIGTERM SIGINT SIGQUIT

echo
echo "## Waiting..."
echo

wait
