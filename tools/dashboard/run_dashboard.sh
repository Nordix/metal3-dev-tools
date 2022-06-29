sudo apt -y install htop ruby
sudo gem install tmuxinator
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
EOF
tmuxinator start dashboard
