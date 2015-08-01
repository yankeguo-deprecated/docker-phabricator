FROM ubuntu:trusty
MAINTAINER YANKE Guo<me@yanke.io>

# Disable interactive during package installation

ENV DEBIAN_FRONTEND noninteractive

# Prepare for package installation

## Change apt sources
ADD apt/sources.list /etc/apt/

## Install wget
RUN apt-get -qy update && apt-get -qy install wget apt-transport-https && rm -rf /var/lib/apt/lists/*

## Add GPG keys
RUN wget -qO- https://deb.nodesource.com/gpgkey/nodesource.gpg.key | apt-key add -
RUN wget -qO- http://nginx.org/keys/nginx_signing.key | apt-key add -

## Add 3rd party sources
ADD apt/nginx.list   /etc/apt/sources.list.d/
ADD apt/nodejs.list   /etc/apt/sources.list.d/

# Install packages

RUN apt-get -qy update && apt-get -qy install git \
                                              vim \
                                              wget \
                                              nginx \
                                              nodejs \
                                              sendmail \
                                              python-pip \
                                              supervisor \
                                              openssh-server \
                                              build-essential \
                                              dpkg-dev \
                                              php5 \
                                              php5-mysql \
                                              php5-gd \
                                              php5-dev \
                                              php5-curl \
                                              php-apc \
                                              php5-cli \
                                              php5-json \
                                              php5-fpm \
                                              && rm -rf /var/lib/apt/lists/*

RUN pip install Pygments

# ENV Variables

ENV PH_WWW_USER             www
ENV PH_VCS_USER             git
ENV PH_ROOT                 /srv
ENV PH_ETC_ROOT             $PH_ROOT/etc
ENV PH_BIN_ROOT             $PH_ROOT/bin
ENV PH_PRE_ROOT             $PH_ROOT/pre
ENV PH_RUN_ROOT             $PH_ROOT/run

# Create and enter WORKDIR

RUN mkdir -p $PH_ROOT
WORKDIR $PH_ROOT

# Add Sources

ADD libphutil   $PH_ROOT/libphutil
ADD arcanist    $PH_ROOT/arcanist
ADD phabricator $PH_ROOT/phabricator
RUN cd $PH_ROOT/phabricator/support/aphlict/server/ && npm install ws --verbose

# Add Users

# Add $PH_WWW_USER user for general http file permission
RUN echo "$PH_WWW_USER:x:800:800:,,,:$PH_ROOT:/bin/bash"                  >> /etc/passwd
RUN echo "$PH_WWW_USER:x:800:"                                            >> /etc/group
RUN echo "$PH_WWW_USER:NP:16647:0:99999:7:::"                             >> /etc/shadow

# Add git user for vcs access via ssh
RUN echo "$PH_VCS_USER:x:801:801:,,,:$PH_ROOT:/bin/bash"                  >> /etc/passwd
RUN echo "$PH_VCS_USER:x:801:"                                            >> /etc/group
RUN echo "$PH_VCS_USER:NP:16647:0:99999:7:::"                             >> /etc/shadow

# Add sudoers rules for $PH_VCS_USER <-> $PH_WWW_USER
RUN echo "$PH_VCS_USER ALL=($PH_WWW_USER) SETENV: NOPASSWD: /usr/bin/git-upload-pack, /usr/bin/git-receive-pack"  >> /etc/sudoers
RUN echo "Defaults  env_keep+=\"PH_* MYSQL_*\""                                                                   >> /etc/sudoers

# Configuration files

ADD etc $PH_ETC_ROOT
ADD bin $PH_BIN_ROOT
RUN mkdir -p $PH_PRE_ROOT
RUN ln -sf $PH_ETC_ROOT/php5/cli/php.ini /etc/php5/cli/php.ini
RUN ln -sf $PH_ETC_ROOT/php5/fpm/php.ini /etc/php5/fpm/php.ini

# tmp folders

## /srv/run
RUN mkdir -p $PH_RUN_ROOT

# Change owners and permission

RUN mkdir -p $PH_ROOT/uploads $PH_ROOT/repos
RUN chown -R $PH_WWW_USER:$PH_WWW_USER arcanist libphutil phabricator uploads repos run
RUN chmod 755 $PH_BIN_ROOT/phabricator-ssh-hook.sh

# Set default password for root and $PH_WWW_USER

RUN echo "root:123"       | chpasswd
RUN echo "$PH_WWW_USER:123"  | chpasswd

# Make privilege directory
RUN mkdir /var/run/sshd

# EXPOSE

## 80 for nginx
EXPOSE 80
## 22 for sshd_vcs
EXPOSE 22
## 222 for sshd_ctrl
EXPOSE 222
## 22280 for aphlict
EXPOSE 22280

# ENTRYPOINT and CMD
ADD entrypoint.sh /
ENTRYPOINT ["/entrypoint.sh"]
CMD ["run"]
