set -e
minikube config set driver kvm2
minikube config set memory 4096
sudo usermod --append --groups libvirt `whoami`
minikube start  --insecure-registry 172.22.0.1:5000
minikube stop

