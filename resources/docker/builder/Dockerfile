# Get packer executables
FROM hashicorp/packer:light AS packer

# Build openstack client
FROM python:3.12-alpine@sha256:ae35274f417fc81ba6ee1fc84206e8517f28117566ee6a04a64f004c1409bdac AS builder

RUN apk add --update --no-cache git build-base linux-headers libffi-dev openssl-dev cargo
RUN git clone --depth 1 https://github.com/openstack/python-openstackclient.git /src
RUN cd /src && pip install --no-cache-dir --root=/app .

# Builder image
FROM python:3.12-alpine@sha256:ae35274f417fc81ba6ee1fc84206e8517f28117566ee6a04a64f004c1409bdac

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
