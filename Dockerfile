FROM ubuntu:trusty
MAINTAINER YANKE Guo<me@yanke.io>

# Create and enter WORKDIR

RUN mkdir -p /srv
WORKDIR /srv

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
                                              supervisor \
                                              openssh-server \
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

# Add Sources

ADD libphutil   ./libphutil
ADD arcanist    ./arcanist
ADD phabricator ./phabricator

# Add Users

# Add www user for general http file permission
RUN echo "www:x:800:800:,,,:/home:/bin/bash"      >> /etc/passwd
RUN echo "www:x:800:"                             >> /etc/group
RUN echo "www:NP:16647:0:99999:7:::"              >> /etc/shadow

# Add git user for vcs access via ssh
RUN echo "git:x:801:801:,,,:/home:/bin/bash"      >> /etc/passwd
RUN echo "git:x:801:"                             >> /etc/group
RUN echo "git:NP:16647:0:99999:7:::"              >> /etc/shadow

# Configuration files

ADD etc ./etc
RUN ln -sf /srv/etc/php5/cli/php.ini /etc/php5/cli/php.ini
RUN ln -sf /srv/etc/php5/fpm/php.ini /etc/php5/fpm/php.ini

# Apply owners

RUN mkdir -p /srv/uploads /srv/repo
RUN chown -R www:www arcanist libphutil phabricator uploads repo

# EXPOSE

EXPOSE 80

# ENTRYPOINT and CMD
ADD entrypoint.sh /
ENTRYPOINT ["/entrypoint.sh"]

CMD ["run"]
