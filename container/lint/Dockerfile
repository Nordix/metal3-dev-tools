FROM ubuntu:18.04

# Install the minimum dependencies
# (software-properties-common for add-apt-repository)
RUN apt-get update && \
    apt-get install -y \
    git \
    curl \
    apt-transport-https \
    ca-certificates \
    software-properties-common

#Add repos and install Go lint and shellcheck
RUN add-apt-repository -y ppa:longsleep/golang-backports && \
    apt-get update && apt-get install -y \
    golang-go \
    golint \
    shellcheck

ENV GOPATH=/data/go
ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/data/go/bin


#Install Golang dep and go sec
RUN curl -LO https://raw.githubusercontent.com/golang/dep/master/install.sh && \
    mkdir -p /data/go/bin && chmod +x install.sh && ./install.sh && rm install.sh && \
    mv /data/go/bin/dep /usr/local/bin && \
    \
    go get github.com/securego/gosec/cmd/gosec && \
    mv /data/go/bin/gosec /usr/local/bin && \
    \
    mkdir -p /data

WORKDIR /data

CMD ["/bin/bash"]
