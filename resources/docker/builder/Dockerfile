# Get packer executables
FROM hashicorp/packer:light-1.9.2@sha256:9af80b3a43e1f408dd6c5787088031da317b533e6cf0c950e60c4a5abef496a6 AS packer

# Build openstack client
FROM python:3.12.1-alpine3.18@sha256:bcffdd35b550a1869f0211d1aa681f3b494c029213f3fb16f365166534c6baac AS builder

RUN apk add --update --no-cache git build-base linux-headers libffi-dev openssl-dev cargo
RUN git clone --depth 1 https://github.com/openstack/python-openstackclient.git /src
RUN cd /src && pip install --no-cache-dir --root=/app .

# Builder image
FROM python:3.12.1-alpine3.18@sha256:bcffdd35b550a1869f0211d1aa681f3b494c029213f3fb16f365166534c6baac

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
