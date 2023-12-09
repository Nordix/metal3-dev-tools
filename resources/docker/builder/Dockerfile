# Get packer executables
FROM hashicorp/packer:light-1.9.4@sha256:33386b90aeb67a1dde1730b75a67d306dc8b9aebf2a0bbb96d9e96164b484e2b AS packer

# Build openstack client
FROM python:3.12.1-alpine3.18@sha256:af0d8da43677e3000ebdf4045508d891a87e7bd2d3ec87bc6e40403be97291b8 AS builder

RUN apk add --update --no-cache git build-base linux-headers libffi-dev openssl-dev cargo
RUN git clone --depth 1 https://github.com/openstack/python-openstackclient.git /src
RUN cd /src && pip install --no-cache-dir --root=/app .

# Builder image
FROM python:3.12.1-alpine3.18@sha256:af0d8da43677e3000ebdf4045508d891a87e7bd2d3ec87bc6e40403be97291b8

RUN apk add --update --no-cache git bash openssl qemu-img \
    jq curl wget gettext openssh && \
    mkdir /data && \
    apk --update add --no-cache --virtual build-dependencies \
    gcc \
    musl-dev \
    libffi-dev \
    openssl-dev \
    cargo && \
    pip install ansible && \
    apk del build-dependencies && \
    curl -fL https://getcli.jfrog.io | sh && \
    mv jfrog /usr/bin

#Copy the executables
COPY --from=packer /bin/packer /bin/packer
COPY --from=builder /app /

RUN packer plugins install github.com/hashicorp/openstack

WORKDIR /data
