# Dev Jumphost management

The scripts in this folder are aimed at managing the dev environment jumphost

## User keys management

All users that will be using the jumphost need to have their public keys on
Artifactory. In order to upload the user keys, use the add_new_user_key.sh
script

### Requirements

Some environment variables need to be set

- RT_USER: Artifactory username
- RT_TOKEN: Artifactory token
- RT_URL: Artifactory URL

### Key management usage

   ```bash
     add_user_key.sh <user_name> <user_key_name> <user_public_key>
   ```

The public key should be given as content, not as a file.

## Create the Jumphost

### Create requirements

Some environment variables need to be set

- RT_URL: Artifactory URL
- METAL3_CI_USER: CI username for the jumphost
- METAL3_CI_USER_KEY: CI user private key path

### Creation Usage

   ./create_or_update_dev_jumphost.sh

## Update the Jumphost

### Update requirements

Some environment variables need to be set

- RT_URL: Artifactory URL
- METAL3_CI_USER: CI username for the jumphost
- METAL3_CI_USER_KEY: CI user private key path

### Update usage

  ./create_or_update_dev_jumphost.sh

## Delete the Jumphost

   ./delete_dev_jumphost.sh

## Update the user keys on the jumphost

### Delete requirements

Some environment variables need to be set

- RT_URL: Artifactory URL
- METAL3_CI_USER: CI username for the jumphost
- METAL3_CI_USER_KEY: CI user private key path

### Delete usage

   ./update_dev_jumphost_users.sh
