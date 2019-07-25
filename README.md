# airship-dev-tools

Set of internal tools for Airship and metal3 development

## Setup

```
$ ./tools/init-repo.sh
```

## Update the nordix master branches

```
$ ./tools/update-nordix-repos-master.sh
```

## Run a development container

```
$ ./container/run-workspace.sh
```

### Running the tests

All the following actions take place in the container. Otherwise
check you have installed everything properly (go 1.12, bazel, operator-sdk etc.)

If you want to run the metal3 tests, you first need to fetch the dependencies.

```
$ dep ensure
```

Then for all repositories :
```
$ make test
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
* [Nuclino (deprecated)](https://app.nuclino.com/ETSJORVAS/Airship)
