###############################################
#
# Docker file to build a standalone swaggerific
#
###############################################

FROM centos:centos7

MAINTAINER Drew J. Sonne drews@blinkbox.com

RUN yum update -y
RUN yum install unzip wget bundle ruby-devel make gcc openssl-devel -y
RUN gem install foreman
RUN gem install bundler

EXPOSE 5000

ADD . /srv/www/swaggerific
WORKDIR /srv/www/swaggerific
RUN bundle install

ENV SWAGGERIFIC_TLD_LEVEL 4

ADD ./swaggerific /usr/local/bin/swaggerific
RUN chmod ug+rx,ugo-w,o-rx /usr/local/bin/swaggerific