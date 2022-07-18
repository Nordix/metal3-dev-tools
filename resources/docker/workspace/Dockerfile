FROM ubuntu:20.04

# Install the minimum dependencies
# (software-properties-common for add-apt-repository)
RUN apt-get update && \
    apt-get install -y \
    git \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common

#Add repos and install Go, Docker and Bazel
RUN add-apt-repository -y ppa:longsleep/golang-backports && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add - && \
    curl https://bazel.build/bazel-release.pub.gpg | apt-key add - && \
    add-apt-repository \
    "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" && \
    add-apt-repository \
    "deb [arch=amd64] https://storage.googleapis.com/bazel-apt stable jdk1.8" && \
    apt-get update && apt-get install -y \
    docker-ce-cli \
    bazel \
    golang-go \
    golint \
    shellcheck

ENV GOPATH=/data/go
ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/data/go/bin:/usr/local/kubebuilder/bin

#Install Golang dep, operator-sdk, Kubectl, Kustomize and kubebuilder
RUN curl -LO https://raw.githubusercontent.com/golang/dep/master/install.sh && \
    mkdir -p /data/go/bin && chmod +x install.sh && ./install.sh && rm install.sh && \
    mv /data/go/bin/dep /usr/local/bin && \
    \
    curl -OJL https://github.com/operator-framework/operator-sdk/releases/download/v0.9.0/operator-sdk-v0.9.0-x86_64-linux-gnu && \
    chmod +x operator-sdk-v0.9.0-x86_64-linux-gnu && cp operator-sdk-v0.9.0-x86_64-linux-gnu /usr/local/bin/operator-sdk && rm operator-sdk-v0.9.0-x86_64-linux-gnu && \
    \
    curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl && \
    chmod +x ./kubectl && \
    mv ./kubectl /usr/local/bin/kubectl && \
    \
    @if ! which kustomize >/dev/null 2>&1 ; then echo "Running 'go get sigs.k8s.io/kustomize'" && GO111MODULE=on go get sigs.k8s.io/kustomize && mv /data/go/bin/kustomize /usr/local/bin; fi \
    \
    curl -sL https://go.kubebuilder.io/dl/2.0.0/$(go env GOOS)/$(go env GOARCH) | tar -xz -C /tmp/ && \
    mv /tmp/kubebuilder_2.0.0_$(go env GOOS)_$(go env GOARCH) /usr/local/kubebuilder && \
    \
    go get github.com/securego/gosec/cmd/gosec && \
    mv /data/go/bin/gosec /usr/local/bin && \
    \
    mkdir -p /data

WORKDIR /data

CMD ["/bin/bash"]
