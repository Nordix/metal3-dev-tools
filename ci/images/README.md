# Generating images

## Images

The images used in the CI :

* Jenkins Ubuntu image

* Base Ubuntu image
* Metal3 Ubuntu image

* Base CentOS image
* Metal3 CentOS dev-env image
* Metal3 CentOS node image

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
      docker run --rm -it -v "<path to metal3-dev-tool repo>:/data"
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

The ubuntu building scripts take two arguments :

* path: to airship CI private key relative in the container
* boolean: Use a floating ip publicly accessible ( 0 or 1 )

   ```bash
   ./gen_<xxx>_<ubuntu>_image.sh /data/keys/id_rsa_airshipci 1
   ```

The centos building scripts take three arguments :

* path: to airship CI private key relative in the container
* boolean: Use a floating ip publicly accessible ( 0 or 1 )
* provisioner script: script file name, give random string to list available scripts

   ```bash
   ./gen_<xxx>_<centos>_image.sh /data/keys/id_rsa_airshipci 1 <provisioner script>
   ```

