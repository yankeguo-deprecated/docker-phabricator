#!/bin/bash

set -e
set -u

config_set() {
  $PH_ROOT/phabricator/bin/config set $1 $2
}

#config_set phabricator.base-uri 'http://192.168.59.103/'
