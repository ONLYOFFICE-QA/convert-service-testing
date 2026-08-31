FROM ruby:3.4

MAINTAINER Dmitriy.Rotatii "kvazilife@gmail.com"
ENV S3_KEY ""
ENV S3_PRIVATE_KEY ""
ENV DOCUMENTSERVER_JWT ""
RUN mkdir -pv ~/.s3 && \
    echo $S3_KEY > ~/.s3/key && \
    echo $S3_PRIVATE_KEY > ~/.s3/private_key

RUN mkdir ~/.documentserver
RUN echo $DOCUMENTSERVER_JWT > ~/.documentserver/documentserver_jwt

RUN apt-get update && apt-get -y -q install libmagic-dev

RUN mkdir /convert_service_testing
WORKDIR /convert_service_testing
ADD . /convert_service_testing
RUN gem install bundler
RUN bundle config set without 'test development'
RUN bundle install
