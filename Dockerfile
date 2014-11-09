########################################
#
# Runs swaggerific with puma on CentOS 7
#
########################################

FROM centos:centos7

MAINTAINER Drew J. Sonne drews@blinkbox.com

RUN yum update -y && yum install -y \
  unzip \
  wget \
  bundle \
  ruby-devel \
  make \
  gcc \
  openssl-devel
RUN gem install foreman bundler

COPY Gemfile /srv/www/swaggerific/
COPY Gemfile.lock /srv/www/swaggerific/
WORKDIR /srv/www/swaggerific
RUN bundle install --deployment --without test,development
COPY . /srv/www/swaggerific

EXPOSE 5000
ENTRYPOINT ["foreman", "start"]
