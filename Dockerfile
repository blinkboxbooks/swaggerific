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

ADD . /srv/www
WORKDIR /srv/www
RUN bundle install
RUN echo $PATH