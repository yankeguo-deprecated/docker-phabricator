docker-phabricator
---

# Introduction

This image provides an all-in-one Ubuntu 14.04 based container of Phabricator.

# Design

This image contains nearly every thing in Phabricator.

* Processes
    * `sshd_vcs`, sshd process for git via ssh.
    * `sshd_ctrl`, sshd process for directly shell access.
    * `nginx`, nginx for web
    * `php5-fpm`, php5-fpm for web
    * `phd`, Phabricator worker
    * `aphlict`, Phabricator notification server
* Ports
    * `22` for `sshd_vcs`, i.e. git via ssh.
    * `222`for `sshd_ctrl`, i.e. direct shell access, DO NOT EXPOSE THIS PORT TO PUBLIC.
    * `80` for `nginx`, i.e. web.
    * `22280` for `aphlict`, i.e Phabricator notification server websocket.
* Users
    * `root`, root user, password `123`
    * `www`, owner of web service and git repos, password `123`.
    * `git`, user for git via ssh only, no password.
* Volumes
    * `/srv/uploads`, large file storage.
    * `/srv/repos`, git repos.
    * `/srv/pre`, `/srv/pre/config.sh`, pre-launch configuration files, see `/pre/config.sample.sh` for more information.
    * `/srv/etc/sshd_keys`, host keys for both `ssh_vcs` and `ssh_ctrl`
