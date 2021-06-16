#!/bin/bash

FILTER=${1:-"no-existing-resources"}
datadir="/tmp/collectedresources"

run_after_confirmation() {
    _command="${1}"
    _message="${2}"
    printf "\n\t${_message}\n"
    read -p "Continue (y/n)?" USER_RESPONSE
    case "${USER_RESPONSE}" in
        y|Y ) echo "yes";;
        n|N ) return;;
        * ) echo "invalid option" && return;;
    esac
    ${_command}
}
gather_resources(){
    rm -rf ${datadir} && mkdir ${datadir}
    echo "Collecting top level resources"
    openstack network list -c Name -f value | grep "${FILTER}" > "${datadir}/networks.list"
    openstack server list -c Name -f value | grep "${FILTER}"  > "${datadir}/servers.list"
    openstack router list -c Name -f value | grep "${FILTER}" > "${datadir}/routers.list"
    openstack security group list -c Name -f value| grep "${FILTER}" > "${datadir}/sg.list"
    # remove empty lines added due to nameless resources
    sed -i '/^$/d' "${datadir}/*"
}

# Collect resources
gather_resources
printf "Resources to be deleted are listed in ${datadir}, you may review the list\n"
read -p "Press Enter to proceed to deletion or CTRL-c to abort"

# Remove resourcess
[ -s ${datadir}/servers.list ] && for server in $(cat ${datadir}/servers.list);do
    echo "Removing server: ${server}"
    run_after_confirmation "openstack server delete ${server}" "Removing server: ${server}"
done

[ -s ${datadir}/routers.list ] && for router in "$(cat ${datadir}/routers.list)";do
    port=$(openstack floating ip list --router=${router} -c Port -f value)
    run_after_confirmation "openstack port delete ${port}" "Removing port associated with floating IP on router: ${router}"
done
[ -s ${datadir}/routers.list ] && for router in $(cat ${datadir}/routers.list);do
    run_after_confirmation "openstack router unset --external-gateway ${router}" "Removing external gateway from ${router}"
done

# Remove ports associated with routers that are also to be removed
[ -s ${datadir}/routers.list ] && for router in $(cat ${datadir}/routers.list);do
    port=$(openstack port list --router=${router} -c ID -f value)
    run_after_confirmation "openstack router remove port ${router} ${port}" "removing port: ${port} from router: ${router}"
done

# Finally, Remove the routers themselves
[ -s ${datadir}/routers.list ] && for router in $(cat ${datadir}/routers.list);do
    run_after_confirmation "openstack router delete ${router}" "removing router: ${router}"
done

# Remove networks and associated ports"
[ -s ${datadir}/networks.list ] && for net in $(cat ${datadir}/networks.list);do
    ports=$(openstack port list --network=${net} -c id -f value)
    for port in ${ports}; do
        run_after_confirmation "openstack port delete ${port}" "removing port ${port} associated with network: ${net}"
    done
    run_after_confirmation "openstack network delete ${net}" "Removing network: ${net}"
done

# Remove security groups
[ -s ${datadir}/sg.list ] && for sg in $(cat ${datadir}/sg.list);do
    run_after_confirmation "openstack security group delete ${sg}" "Removing security group: ${sg}"
done
