

### Tilt setup for cluster-api-provider-openstack

The Tilt environment requires golang 1.16 or higher. 

Get a stable release of cluster-api
```bash
cluster-api$ git checkout release-0.3 
```

Add ```opentack``` provider 
cluster-api$ cat tilt-settings.json

```json
{
  "default_registry": "gcr.io/cluster-api-provider",
  "provider_repos": ["../cluster-api-provider-openstack"],
  "enable_providers": ["openstack", "kubeadm-bootstrap", "kubeadm-control-plane"]
}
```

cluster-api-provider-openstack repo 
Add a kustomization.yaml in ```cluster-api-provider-openstack/config```

cluster-api-provider-openstack/config$ cat kustomization.yaml 
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

bases:
- default
```

#### Deploying workload

```bash
source /tmp/capo_openstackrc
export KUBERNETES_VERSION=v1.21.0
clusterctl config cluster --infrastructure=openstack:v0.3.4 basic-1 > /tmp/basic.yaml
kubectl create -f /tmp/basic.yaml
```
