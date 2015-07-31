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

# Ensure permissions
ensure_permissions() {
  # Ensure $PH_WWW_USER owns these folders
  chown -R $PH_WWW_USER:$PH_WWW_USER $PH_ROOT/libphutil $PH_ROOT/arcanist $PH_ROOT/phabricator $PH_ROOT/uploads $PH_ROOT/repos
  # Ensure permission of phabricator-ssh-hook.sh
  chown $PH_WWW_USER:$PH_WWW_USER $PH_BIN_ROOT/phabricator-ssh-hook.sh
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
  # Notifications service
  config_set notification.enabled true
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

# Start phd
start_phd() {
  sudo -u $PH_WWW_USER $PH_ROOT/phabricator/bin/phd start
}

# Start aphlict
start_aphlict() {
  sudo -u $PH_WWW_USER $PH_ROOT/phabricator/bin/aphlict start
}

# Print usage
if [ $# -lt 1 ]
then
  print_usage
  exit
fi

case "$1" in
  # Start supervisor
  run)        echo "Wait 10 seconds before startup"
              sleep 10
              echo "Starting everything"
              ensure_permissions
              ensure_all_sshd_keys
              run_configs
              upgrade_storage
              echo "Starting phd"
              start_phd
              echo "Starting aphlict"
              start_aphlict
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
