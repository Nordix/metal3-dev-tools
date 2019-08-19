# Generating images

## Images

There are three images used in the CI :

* Base image
* Jenkins image
* Metal3 image

### Base

 This is a vanilla ubuntu with some handy tools and user configuration

### Jenkins

 This image includes a JDK

### Metal3

 This image includes the packages needed to run the Metal3 dev env.

## Requirements

You need to have the environmental variables set to access Openstack, for
example with :

   ```bash
      source openstack.rc
   ```

You need to have the Airship CI user private key.

### Building environment

A container image is available and contains all the tools to build the images

   ```bash
      docker pull registry.nordix.org/airship/image-builder
   ```

   ```bash
      docker run --rm -it -v "<path to airship-dev-tool repo>:/data"
   -v "<path to ci keys folder>:/data/keys" registry.nordix.org/airship/image-builder /bin/bash
   ```

### Calling the scripts

First, you will need to source the OpenStack credentials file.

   ```bash
      source openstack.rc
   ```

Then set the correct environment variables:

   ```bash
      export AIRSHIP_CI_USER=airshipci
      export AIRSHIP_CI_USER_KEY=/data/keys/id_rsa_airshipci
      export RT_URL="https://artifactory.nordix.org/artifactory"
   ```

The building scripts take two arguments :

* path: to airship CI private key relative in the container
* boolean: Use a floating ip publicly accessible ( 0 or 1 )

   ```bash
   ./gen_<xxx>_ubuntu_image.sh /data/keys/id_rsa_airshipci 1
   ```
