# Upgrade script naming scheme

* nodes: <i>cp | <j>w; i=1..n, j=0..n
* what: bootDiskImage | k8sVer | k8sBin
* How: scaleInWorkers | scaleOutWorkers
* other: extraNode
* postfix: upgrade | upgrade_both; cp or w depending on the script directory or both cp and w

nodes_what_how_other_postfix.sh

# Example:
1cp_3w_k8sVer_scaleInWorkers_upgrade.sh