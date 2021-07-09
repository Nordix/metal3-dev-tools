#!/bin/bash
set -x
FILTER=${1:-"no-existing-resources"}
datadir="/tmp/collectedresources"

run_after_confirmation() {
    _command="${1}"
    _message="${2}"
    _resources="${3}"
    if [[ $(echo ${#_resources}) -eq 0 ]];then
        return
    fi
    echo $_resources
    printf "\n\t${_message}\n$_resources\n"
    read -p "Continue (y/n)?" USER_RESPONSE
    case "${USER_RESPONSE}" in
        y|Y ) echo "yes";;
        n|N ) return;;
        * ) echo "invalid option" && return;;
    esac

    for resource in $_resources;do
        resourcen_ame=$(echo $resource | cut -f1 -d,)
        resource_id=$(sanitizeID $resource)
        ./run-openstack-command.sh $_command $resource_id
    done
}
gather_resources(){
    rm -rf ${datadir} && mkdir ${datadir}
    echo "Collecting top level resources"
    ./run-openstack-command.sh openstack network list -c ID -c Name -f json | jq --arg FILTER "$FILTER" '.[]|select(.Name | contains($FILTER))' > "${datadir}/networks.list"
    ./run-openstack-command.sh openstack server list   -c ID -c Name -f json | jq --arg FILTER "$FILTER" '.[]|select(.Name | contains($FILTER))' > "${datadir}/servers.list"
    ./run-openstack-command.sh openstack router list  -c ID -c Name -f json | jq --arg FILTER "$FILTER" '.[]|select(.Name | contains($FILTER))' > "${datadir}/routers.list"
    ./run-openstack-command.sh openstack security group list -c ID -c Name -f json | jq --arg FILTER "$FILTER" '.[]|select(.Name | contains($FILTER))' > "${datadir}/sg.list"
    # remove empty lines added due to nameless resources
    sed -i '/^$/d' "${datadir}/networks.list" 2> /dev/null
    sed -i '/^$/d' "${datadir}/routers.list" 2> /dev/null
    sed -i '/^$/d' "${datadir}/servers.list" 2> /dev/null
    sed -i '/^$/d' "${datadir}/sg.list" 2> /dev/null
}
sanitizeID() {
    local id="${1?requires an ID}"
    sid=$(echo $id | cut -f2 -d',' | tr -d '\n' | tr -d '\r')
    echo $sid
}

# Collect resources
gather_resources

# relinquish floating IPs that are not used by any servers
fids=$(./run-openstack-command.sh openstack floating ip list -f json | jq -r '.[]|select(.Port == null) |."Floating IP Address"+","+.ID')
run_after_confirmation "openstack floating ip delete" "Releasing unused floating IPs (IP,UID)" "$fids"

servers=$(cat ${datadir}/servers.list| jq -r '.|.Name+","+.ID')
[ -s ${datadir}/servers.list ] && run_after_confirmation "openstack server delete" "Removing the following servers (name,id)"  $servers

routers="$(cat ${datadir}/routers.list | jq -r '.|.Name+","+.ID')"

[ -s ${datadir}/routers.list ] && for router in ${routers};do
    rname=$(echo $router | cut -f1 -d,)
    rid=$(sanitizeID $router)
    ports=$(./run-openstack-command.sh openstack floating ip list --router=$rid -f json | jq -r '.[]|."Floating IP Address"+","+.Port')
    run_after_confirmation "openstack port delete" "Removing the following ports, associated with router $rname" "$ports"
done
[ -s ${datadir}/routers.list ] && for router in $routers;do
    rname=$(echo $router | cut -f1 -d,)
    rid=$(sanitizeID $router)
    ./run-openstack-command.sh openstack router unset --external-gateway ${rname}
done
# Remove ports associated with routers that are also to be removed
[ -s ${datadir}/routers.list ] && for router in $routers;do
    rname=$(echo $router | cut -f1 -d,)
    rid=$(sanitizeID $router)
    ports=$(./run-openstack-command.sh openstack port list --router=${rid} -f json | jq -r '.[]|.Name+","+.ID')
    run_after_confirmation "openstack router remove port ${rid}" "Removing the following ports from router ${rname}" "$ports"
done

# Finally, Remove the routers themselves
[ -s ${datadir}/routers.list ] && run_after_confirmation "openstack router delete" "Removing the following routers" $routers

# Remove networks and associated ports"
networks="$(cat ${datadir}/networks.list | jq -r '.|.Name+","+.ID')"
[ -s ${datadir}/networks.list ] && for net in $networks;do
    netid=$(sanitizeID $net)
    nname=$(echo $net | cut -f1 -d',')
    ports=$(./run-openstack-command.sh openstack port list --network=${netid} -c ID -c Name -f json | jq -r '.[]|.Name+","+.ID')
    run_after_confirmation "openstack port delete" "Removing ports associated with network ${nname}" "$ports"
done
[ -s ${datadir}/networks.list ] && run_after_confirmation "openstack network delete ${netid}" "Removing the following networks" $networks

# Remove security groups
 security_groups=$(cat ${datadir}/sg.list | jq -r '.|.Name+","+.ID')
[ -s ${datadir}/sg.list ] && run_after_confirmation "openstack security group delete" "Removing the following security groups" "$security_groups"
set +x