#!/bin/bash

MYSQL_PORT_3306_TCP_PORT="$MYSQL_PORT_3306_TCP_PORT"

set -e
set -u

# Function to print usage
print_usage() {
  cat <<-EOF
Usage:
  run         - Run everything
  shell       - Start a bash shell for $PH_WWW_USER user
  root_shell  - Start a bash shell for root user
EOF
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

# Ensure folders
ensure_folders() {
  ## phd
  mkdir -p $PH_RUN_ROOT/phd/pid
  mkdir -p $PH_RUN_ROOT/phd/log

  ## php5-fpm
  mkdir -p $PH_RUN_ROOT/php5-fpm/pid
  mkdir -p $PH_RUN_ROOT/php5-fpm/log
  mkdir -p $PH_RUN_ROOT/php5-fpm/sock

  ## nginx
  mkdir -p $PH_RUN_ROOT/nginx/pid
  mkdir -p $PH_RUN_ROOT/nginx/log

  ## sshd_vcs/sshd_ctrl
  mkdir -p $PH_RUN_ROOT/sshd_vcs/pid
  mkdir -p $PH_RUN_ROOT/sshd_ctrl/pid

  ## aphlict
  mkdir -p $PH_RUN_ROOT/aphlict/pid
  mkdir -p $PH_RUN_ROOT/aphlict/log

  # supervisor
  mkdir -p $PH_RUN_ROOT/supervisor/pid
  mkdir -p $PH_RUN_ROOT/supervisor/log
}

# Ensure permissions
ensure_permissions() {
  # Ensure $PH_WWW_USER owns these folders
  chown -R $PH_WWW_USER:$PH_WWW_USER $PH_ROOT/libphutil $PH_ROOT/arcanist $PH_ROOT/phabricator $PH_ROOT/uploads $PH_ROOT/repos $PH_RUN_ROOT
  # Ensure permission of phabricator-ssh-hook.sh
  chown root:root $PH_BIN_ROOT/phabricator-ssh-hook.sh
  chmod 755 $PH_BIN_ROOT/phabricator-ssh-hook.sh
}

# Ensure multiple ssh_host_key
ensure_all_sshd_keys() {
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
run_internal_configs() {
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
run_pre_configs() {
  PRE_CONFIG_SH=$PH_PRE_ROOT/config.sh
  if [ -f $PRE_CONFIG_SH ]; then
    sudo -u $PH_WWW_USER $PRE_CONFIG_SH
  fi
}

# Run configs
run_configs() {
  run_internal_configs
  run_pre_configs
}

# Upgrade storage
upgrade_storage() {
  sudo -u $PH_WWW_USER $PH_ROOT/phabricator/bin/storage upgrade --force
}

# Print usage
if [ $# -lt 1 ]
then
  print_usage
  exit
fi

case "$1" in
  # Start supervisor
  run)        echo "Starting everything"
              ensure_folders
              ensure_permissions
              ensure_all_sshd_keys
              run_configs
              upgrade_storage
              echo "Starting supervisord"
              /usr/bin/supervisord -c $PH_ETC_ROOT/supervisor/supervisord.conf
              ;;
  # Start a shell as $PH_WWW_USER user
  shell)      echo "Starting shell for $PH_WWW_USER user"
              ensure_permissions
              sudo -u $PH_WWW_USER -i
              ;;
  # Start a root shell
  root_shell) echo "Starting shell for root user"
              ensure_permissions
              bash
              ;;
  *)          print_usage
esac
