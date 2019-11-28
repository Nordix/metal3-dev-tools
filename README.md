# airship-dev-tools

Set of internal tools for Airship and metal3 development

## Setup

```sh
make setup-local-repos
```

## Update the nordix master branches

```sh
make update-remote-repos
```

## Run the metal3 dev env

First, make sure that hardware virtualization is enabled, then you need to
source your Openstack credentials

```sh
source openstack.rc
```

Then run

```sh
make run-dev-env
```

If the IP address of the newly created virtual machine is not shown, then run the following

```
virsh net-dhcp-leases default
```

ssh into the machine with the airshipci user

```
ssh airshipci@VM_IP
```

Then you can set up the environment :

```sh
git clone https://github.com/metal3-io/metal3-dev-env.git
export CONTAINER_RUNTIME=docker
cd metal3-dev-env
make
```

## Alternative way to run a development container

```sh
make workspace
```

### Running the tests

All the following actions take place in the container. Otherwise
check you have installed everything properly (go 1.12, bazel, operator-sdk etc.)

If you want to run the metal3 tests, you first need to fetch the dependencies.

```sh
dep ensure
```

Then for all repositories :

```sh
make test
```

## Ways of working

* [Github Workflow](wow/github-workflow.md)

## Useful links

* [Github Nordix organization](https://github.com/Nordix)
* [Jenkins Nordix](https://jenkins.nordix.org)
* [Wiki Nordix](https://wiki.nordix.org/)
* [Jira Nordix](https://jira.nordix.org/secure/Dashboard.jspa)
* [Jira Airship](https://airship.atlassian.net/projects/AIR/issues)
* [Gerrit Nordix](https://gerrit.nordix.org)
* [Harbour nordix](https://registry.nordix.org)
* [Slack EST](estech-group.slack.com)
* [Our Wiki Nordix Pages](https://wiki.nordix.org/display/CPI/Cloud+and+Programmable+Infrastructure)
