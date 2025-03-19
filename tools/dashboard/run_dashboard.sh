sudo apt -y install htop ruby || sudo dnf -y install htop ruby
sudo gem install tmuxinator

ipam=$(kubectl get pods -A  |  awk '{print $1,$2}' | grep -m1 ipam-controller)
capm3=$(kubectl get pods -A  |  awk '{print $1,$2}' | grep -m1 capm3-controller)
bmo=$(kubectl get pods -A  |  awk '{print $1,$2}' | grep -m1 baremetal-operator-controller)
capi=$(kubectl get pods -A  |  awk '{print $1,$2}' | grep -m1 capi-controller)

sudo wget https://raw.githubusercontent.com/tmuxinator/tmuxinator/master/completion/tmuxinator.bash -O /etc/bash_completion.d/tmuxinator.bash
tmuxinator new dashboard
cat <<-EOF > ~/.config/tmuxinator/dashboard.yml
name: dashboard
root: ~/
windows:
  - crs:
      layout: tiled
      panes:
        - watch sudo virsh list --all
        - watch kubectl get bmh -A
        - watch kubectl get machine -A
        - htop
        - watch kubectl get pods -A -o wide
  - logs:
      layout: tiled
      panes:
        - kubectl logs  -n $capm3 -f 
        - kubectl logs  -n $capi -f 
        - kubectl logs  -n $bmo -f 
        - kubectl logs  -n $ipam -f 
EOF
tmuxinator start dashboard
