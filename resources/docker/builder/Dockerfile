# Get packer executables
FROM hashicorp/packer:light AS packer

# Build openstack client
FROM python:3.7-alpine AS builder

RUN apk add --update --no-cache git build-base linux-headers libffi-dev openssl-dev
RUN git clone --depth 1 https://github.com/openstack/python-openstackclient.git /src
RUN cd /src && pip install --no-cache-dir --root=/app .

# Builder image
FROM python:3.7-alpine

RUN apk add --update --no-cache git bash wget openssl \
    jq curl wget gettext openssh && \
    mkdir /data && \
    apk --update add --no-cache --virtual build-dependencies \
    gcc \
    musl-dev \
    libffi-dev \
    openssl-dev && \
    pip install ansible && \
    apk del build-dependencies && \
    curl -fL https://getcli.jfrog.io | sh && \
    mv jfrog /usr/bin


#Copy the executables
COPY --from=packer /bin/packer /bin/packer
COPY --from=builder /app /

WORKDIR /data
