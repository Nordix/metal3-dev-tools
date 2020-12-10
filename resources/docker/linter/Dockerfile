FROM alpine:latest

RUN apk update && \
    apk add --no-cache ruby ruby-json && \
    gem install --no-document mdl && \
    mkdir /data

WORKDIR /data
