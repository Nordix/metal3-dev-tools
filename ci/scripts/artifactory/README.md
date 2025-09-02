# Artifactory

Author: [Tero Kauppinen](mailto:tero.kauppinen@est.tech)

This folder contains scripts to create/remove users' public keys from the
artifactory. Path of the artifactory is set by *RT_URL* (command line option)
and *RT_USERS_DIR* (defined in [artifactory utils](./utils.sh)).

In order to access the
[artifactory](https://artifactory.nordix.org/artifactory),
both account and access token are required. If you need an account, contact
[Kraken Team](mailto:kraken@est.tech). Access tokens can be created
[here](https://artifactory.nordix.org/ui/user_profile).

## Prerequisites

- Install jq

## Adding public keys

A new public key for a specific user can be added by using the following script:

```console
$ RT_TOKEN="<artifactory-access-token>" ./add_new_user_key.sh

Usage:

  add_new_user_key.sh [opts]

Add user's public key to the artifactory.

Use the `-h` option to list all available options.
```

This will create the key specified by `key-name` for user specified by `user`.

It should be noted that the script will *replace* any existing key with the
same `key-name`.

## Removing public keys

Remove a specified key from a specific user with the following script:

```console
$ RT_TOKEN="<artifactory-access-token>" ./del_user_key.sh

Usage:

  del_user_key.sh [opts]

Delete user's public key in the artifactory.

Use the `-h` option to list all available options.
```

This will remove the key specified by `key-name` from user specified by
`user`. It should be noted that no error is given for a non-existing
key.

## List public keys

To list all registered public keys, run the following script:

```console
$ ./artifactory/list_user_keys.sh

Usage:

  list_user_keys.sh [opts]

List user's public keys in the artifactory.

Use the `-h` option to list all available options.
```

Listing public keys require no `RT_TOKEN`. If no `user` is given or
value *all* is specified, public keys are listed for *all* existing users.
