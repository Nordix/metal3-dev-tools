# Jumphost management

Author: [Tero Kauppinen](mailto:tero.kauppinen@est.tech)

The scripts in this folder are aimed at managing jumphosts.

## Requirements

- Management key must be created. Further details in
[inject the management key][management].
- Public keys for the users must be registered to
the artificatory. Further details in
[adding public keys][artifactory].
- Infrastructure must in place. Further details in
[creating infrastructure][infra].

[management]: ../openstack/README.md#inject-the-management-key
[infra]: ../openstack/README.md#create-infrastructure
[artifactory]: ../artifactory/README.md#adding-public-keys

## Create the jumphost

Jumphost can be created with the following command:

```console
$ ./create_or_rebuild_jumphost.sh

Usage:

  create_or_rebuild_jumphost.sh [opts]

Create or rebuild a jumphost in openstack environment.

Use the `-h` option to list all available options.
```

It should be noted that in this context, `key-file` and `user`
options are used to specify the management user's credentials to access
the jumphost with SSH once the VM is created. Upon creation, the admin
user is created as `user` and *the management key* will be injected as the
key pair.

The command does not require options if the default values meet
the user's requirements.

## Register public keys registered in the artificatory

When the jumphost is created, the next step is usually to create
users and inject public keys with the following script:

```console
$ ./update_jumphost_users.sh

Usage:

  update_jumphost_users.sh [opts] <user>

Add public keys for the users found in the artifactory to the jumphost.

Use the `-h` option to list all available options.
```

This script will fetch either a specific user's (if `<user>` is specified) or
all users (if no `<user>` is specified or the value is *all*) information from
the artificatory at `rt-url` and creates or updates these users' information
in the jumphost.

It should be noted that in this context, `key-file` and `user`
options are used to specify the management user's credentials to access the
jumphost.

## Inject a custom authorized keys file

If there is need to inject a custom authorized keys file for a specific user,
use the following script:

```console
$ ./add_jumphost_user.sh

Usage:

  add_jumphost_user.sh [opts] <new-user> <authorized-keys-file>

Create a user to the jumphost.

Use the `-h` option to list all available options.
```

This script is also used by *update_jumphost_users.sh*.

It should be noted that in this context, `key-file` and `user`
options are use to specify the management user's credentials to access the
jumphost.

## Deleting a user

Users can removed with the following script:

```console
$ ./del_jumphost_user.sh

Usage:

  del_jumphost_user.sh [opts] <user>

Remove a user to the jumphost.

Use the `-h` option to list all available options.
```

This script will remove the user specified by `<user>`. For safety reasons,
only a single user can be removed at a time.

It should be noted that in this context, `key-file` and `user`
options are used to specify the management user's credentials to access
the jumphost.

## Deleting the jumphost

Jumphost can removed with the following command:

```console
$ ./delete_jumphost.sh

Usage:

  delete_jumphost.sh [opts]

Delete a jumphost in openstack environment.

Use the `-h` option to list all available options.
```

This script will remove a previously created jumphost and disassociates the
allocated floating IP address. However, the allocated floating IP address
is kept to be reused later.

Warning! If a previously used jumphost floating IP address is associated
with another instance without clearing the *tag* field of the IP address,
creating a new jumphost instance with the same configuration
will *hijack* the address from the instance.
