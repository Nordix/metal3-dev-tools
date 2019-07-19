FROM ubuntu:18.04

RUN apt-get update && \
    apt-get install -y software-properties-common

RUN add-apt-repository -y ppa:longsleep/golang-backports && \
    apt-get update && apt-get install -y \
    git \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    golang-go \
    golint
RUN curl -LO https://raw.githubusercontent.com/golang/dep/master/install.sh && \
    mkdir -p /root/go/bin && chmod +x install.sh && ./install.sh && rm install.sh
RUN curl -OJL https://github.com/operator-framework/operator-sdk/releases/download/v0.9.0/operator-sdk-v0.9.0-x86_64-linux-gnu && \
    chmod +x operator-sdk-v0.9.0-x86_64-linux-gnu && cp operator-sdk-v0.9.0-x86_64-linux-gnu /usr/local/bin/operator-sdk && rm operator-sdk-v0.9.0-x86_64-linux-gnu
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add - && \
    add-apt-repository \
    "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) \
    stable" && \
    apt-get update && apt-get install docker-ce-cli
RUN curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl && \
    chmod +x ./kubectl && \
    mv ./kubectl /usr/local/bin/kubectl

ENV GOPATH=/root/go
ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/root/go/bin

RUN curl -LO https://raw.githubusercontent.com/Nordix/cluster-api-provider-baremetal/master/tools/install_kustomize.sh && \
    chmod +x ./install_kustomize.sh && ./install_kustomize.sh && rm install_kustomize.sh && \
    curl -LO https://raw.githubusercontent.com/Nordix/cluster-api-provider-baremetal/master/tools/install_kubebuilder.sh && \
    chmod +x ./install_kubebuilder.sh && ./install_kubebuilder.sh && rm install_kubebuilder.sh && \
    mv kubebuilder /usr/local


RUN mkdir /data
WORKDIR /data

CMD ["/bin/bash"]
