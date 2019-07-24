# Introduction

In this development environment, deploying kubernetes involves two steps. 
- Create machines with required binaries, such as kubelete, kubeadm and docker
- Create a kubernetes cluster using tools such as kubeadm

The scripts under `./providers/kinder/` try provide solution to both of the above tasks as follows.

**Creating Machines**: Using the scripts under `/providers/kinder/`, it is possible to create machines with relevant binaries. The versions of the variables is determined by the node-image built using kinder. 

As to networking, each control plane node has multiple control plane networks and workers are connected to to multiple traffic networks. Experiments related to workers networking can be ignored for now. When it is considered again, we would like to separate the management and traffic networks and experiments need to be done on that.


**Creating K8s cluster:** The creation the K8s cluster is a manual process and needs to be done as described below. 

A kubernetes control plane is made of multiple components, such as the API server, etcd and scheduler. The components that are of interest to us at this point are the API server and the etcd database.

## Experiments overview

The main focus on studying the behavior of kubeadm when run on machine with multiple interfaces.
And, We try to answer the following questions.

- How do these components choose which interfaces to use ?
- How do we influence the choice during init phase ?
- How do we influence the choice during join phase ? 
- How granular the configuration could be made. 

As shown below, there are multiple traffic networks for the workers and additional control plane networks. Although different kinds of tests can be done, we focus on the extreme case in that:

- etcd to etcd communication done over an etcd-network
- api-server to api-server communication done over an api-network (with or without a load balancer)
- api-server to etcd communication over localhost if they are on the same machine
- api-server to etcd communication not possible if they are on separate machines


![Topology](./resources/images/network-topology.png)

Alternative topologies can be found [here](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/ha-topology/)


# Kinder based machine creation

**prerequisites**

- [Kinder](https://github.com/kubernetes/kubeadm/tree/master/kinder) and [jq](https://stedolan.github.io/jq/download/) are installed    
- None of the networks defined in `./setup_test_environment.sh` conflict with existing docker networks
- No cluster exists with the same name or else it will delete and re-create it

**Setup test environment**

    ./providers/kinder/setup_test_environment.sh <cluster name> [<number of masters> <number of workers>]

If you do not provide the number of workers or masters or both, then both default to 3.

**Teardown test environment**

    ./providers/kinder/teardown_test_environment.sh <cluster name>

# Test Results

## Requirements
In a multi interface control plane node, configuring control plane such that
1. IP addresses of control plane components are pre-determined
2. During init phase, control plane components use distinct IP addresses
3. During join phase, control plane components use distinct IP addresses

### Solutions

**Test case 1:**
Setup:
Result:
Observation:

- How do these components choose which interfaces to use ? by default
- How do we influence the choice during init phase ? using config files no mix
- How do we influence the choice during join phase ? Using config files no mix
- How granular the configuration could be made. 
    - only the case where the api server and the etcd use the same none defautl ip works
    - Making separate was not succeeding on the joining end as it always takes ....