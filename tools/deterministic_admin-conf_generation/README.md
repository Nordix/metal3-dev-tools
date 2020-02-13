# Deterministic admin.conf generation for accessing k8s cluster

Given a ```ca.key``` and ```ca.crt``` we would like to create _admin.conf for accessing a kubernetes cluster.

Note:
- The cluster is not setup yet.
- The file is named ```_admin```.conf to distinguish it from the one automatically created during ```kubeadm init```
# Steps
1. Get ```ca.key``` and ```ca.crt``` files
2. Create _admin.conf with the provided script
3. Create a kubernetes cluster using the ```ca.key``` and ```ca.crt```
4. Access the kubernetes cluster using the pre-created _admin.conf
5. Destroy and create the cluster multiple times to see the _admin.conf remains valid

The ```admin.sh``` performs step 2 in the above list.

# Usage

The script takes the following arguments, only the ```endpoint`` is mandatory

```
1 - a path to ca.crt
2 - a path to ca.key
3 - an enpoint address
```

Examples:

When providing all three arguments
```
./admin.sh /tmp/ca.cert /tmp/ca.key https://172.17.0.2:6443
```
To verify that the generated _admin.conf is correct, run the following.

```
kubectl get pods --kubeconfig=_admin.conf
```

When providing only the end point
```
./admin.sh https://172.17.0.2:6443
```

when you are not providing ca.crt and ca.key, then the script generates them for you.
However, you need to make sure that ```kubeadm init``` is run with those crts. Or else you will get the following error.


```
kubectl get pods --kubeconfig=_admin.conf
```
```
Unable to connect to the server: x509: certificate signed by unknown authority
```
