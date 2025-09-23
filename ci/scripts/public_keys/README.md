# Public key management

Public keys for jumphost users must be stored under this directory. Each user
must have a directory of his or her own which stores SSH public keys for
the user in question.

Users can have multiple key files or a single file that stores multiple keys.
When adding or updating user's key information, the process will combine
content of all found files in the user's directory as a single
`authorized_keys` file which is then uploaded to the target host.
