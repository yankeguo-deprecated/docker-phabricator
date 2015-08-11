#!/bin/bash

set -e
set -u

ROOT_FOLDER=`dirname $0`

update_repo() {
  pushd $1
  git pull origin master
  popd
}

update_repo arcanist
update_repo libphutil
update_repo phabricator
