FROM alpine:3.14

RUN apk add --no-cache \
		ca-certificates

RUN [ ! -e /etc/nsswitch.conf ] && echo 'hosts: files dns' > /etc/nsswitch.conf

ENV GOLANG_VERSION 1.13rc2

RUN set -eux; \
	apk add --no-cache --virtual .build-deps \
		bash \
		gcc \
		musl-dev \
		openssl \
		go \
	; \
	export \
		GOROOT_BOOTSTRAP="$(go env GOROOT)" \
		GOOS="$(go env GOOS)" \
		GOARCH="$(go env GOARCH)" \
		GOHOSTOS="$(go env GOHOSTOS)" \
		GOHOSTARCH="$(go env GOHOSTARCH)" \
	; \
	apkArch="$(apk --print-arch)"; \
	case "$apkArch" in \
		armhf) export GOARM='6' ;; \
		x86) export GO386='387' ;; \
	esac; \
	\
	wget -O go.tgz "https://golang.org/dl/go$GOLANG_VERSION.src.tar.gz"; \
	echo '0c7387b3be32718282a39faa3020ff30365ef70e64fa71e10017a986587b7fe9 *go.tgz' | sha256sum -c -; \
	tar -C /usr/local -xzf go.tgz; \
	rm go.tgz; \
	\
	cd /usr/local/go/src; \
	./make.bash; \
	\
	rm -rf \
		/usr/local/go/pkg/bootstrap \
		/usr/local/go/pkg/obj \
	; \
	apk del .build-deps; \
	\
	export PATH="/usr/local/go/bin:$PATH"; \
	go version

ENV GOPATH /go

RUN apk add --update \
    git \
    glide \
    make \
    curl \
    musl-dev \
    bash \
    && rm -rf /var/cache/apk/* && \
    curl -s https://api.github.com/repos/kubernetes-sigs/kustomize/releases |\
    grep browser_download | grep linux | cut -d '"' -f 4 | grep /kustomize/v | sort | tail -n 1 | xargs curl -O -L && \
    tar xzf ./kustomize_v*_linux_amd64.tar.gz && \
    chmod u+x kustomize && \
    mv kustomize /usr/local/bin \
    && curl -OJL https://github.com/operator-framework/operator-sdk/releases/download/v0.9.0/operator-sdk-v0.9.0-x86_64-linux-gnu && \
    chmod +x operator-sdk-v0.9.0-x86_64-linux-gnu && cp operator-sdk-v0.9.0-x86_64-linux-gnu /usr/local/bin/operator-sdk  \
    && rm operator-sdk-v0.9.0-x86_64-linux-gnu && \
    go get github.com/securego/gosec/cmd/gosec && \
    mv /go/bin/gosec /usr/local/bin && \
    go get -u golang.org/x/lint/golint && \
    mv /go/bin/golint /usr/local/bin && \
    curl -LO https://raw.githubusercontent.com/golang/dep/master/install.sh && \
    chmod +x install.sh && ./install.sh && rm install.sh && \
    mv /go/bin/dep /usr/local/bin && \
    curl -LO https://raw.githubusercontent.com/Nordix/cluster-api-provider-baremetal/master/hack/tools/install_kubebuilder.sh && \
    chmod +x ./install_kubebuilder.sh \
    && ./install_kubebuilder.sh \
    && rm ./install_kubebuilder.sh && \
    mv /kubebuilder /usr/local && \
    cp /usr/local/kubebuilder/bin/kubebuilder /usr/local/bin

COPY run-test.sh /usr/bin/testentrypoint
CMD ["/usr/bin/testentrypoint"]
