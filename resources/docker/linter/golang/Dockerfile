FROM golang:1.17.13-alpine

RUN apk add --update --no-cache ca-certificates git

RUN set -x \
	&& export GOPATH=/go \
	&& mkdir -p /go/src/golang.org/x \
	&& go get -u golang.org/x/lint/golint \
	&& go get -u github.com/securego/gosec/cmd/gosec

WORKDIR /data
