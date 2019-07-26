# airship-dev-tools

Set of internal tools for Airship and metal3 development

## Setup

```sh
$ make setup-repos
```

## Update the nordix master branches

```sh
$ make update-repos
```

## Run a development container

```sh
$ make workspace
```

### Running the tests

All the following actions take place in the container. Otherwise
check you have installed everything properly (go 1.12, bazel, operator-sdk etc.)

If you want to run the metal3 tests, you first need to fetch the dependencies.

```sh
$ dep ensure
```

Then for all repositories :

```sh
$ make test
```

## Ways of working

* [Github Workflow](wow/github-workflow.md)
