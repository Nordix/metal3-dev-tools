FROM golang:1.11-alpine3.7

RUN apk add --update \
    git \
    glide \
    make \
    sudo \
    curl \
    musl-dev \
    && rm -rf /var/cache/apk/* \
    && curl -OJL https://github.com/operator-framework/operator-sdk/releases/download/v0.9.0/operator-sdk-v0.9.0-x86_64-linux-gnu && \
    chmod +x operator-sdk-v0.9.0-x86_64-linux-gnu && cp operator-sdk-v0.9.0-x86_64-linux-gnu /usr/local/bin/operator-sdk  \
    && rm operator-sdk-v0.9.0-x86_64-linux-gnu \
    && go get github.com/securego/gosec/cmd/gosec && \
    mv /go/bin/gosec /usr/local/bin && \
    go get github.com/golang/lint/golint && mv /go/bin/golint /usr/local/bin && \
    curl -LO https://raw.githubusercontent.com/golang/dep/master/install.sh && \
    chmod +x install.sh && ./install.sh && rm install.sh && \
    mv /go/bin/dep /usr/local/bin

COPY run-test.sh /usr/bin/testentrypoint
ENTRYPOINT ["/usr/bin/testentrypoint"]
