# Get packer executables
FROM hashicorp/packer:light-1.9.4@sha256:33386b90aeb67a1dde1730b75a67d306dc8b9aebf2a0bbb96d9e96164b484e2b AS packer

# Build openstack client
FROM python:3.12.0-alpine3.18@sha256:09f18c1f8ca777f63934b415af9a781a0e5aaba5e005ba0475cba71bb3e8e609 AS builder

RUN apk add --update --no-cache git build-base linux-headers libffi-dev openssl-dev cargo
RUN git clone --depth 1 https://github.com/openstack/python-openstackclient.git /src
RUN cd /src && pip install --no-cache-dir --root=/app .

# Builder image
FROM python:3.12.0-alpine3.18@sha256:09f18c1f8ca777f63934b415af9a781a0e5aaba5e005ba0475cba71bb3e8e609

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
