#!/bin/bash
# Purpose: Setup cSRX for a switch-to-switch SecureWire Demo
# Version: 0.1
# Author: John Weidley
###########################################################################################################
# Notes:
###########################################################################################################

########################################################
# Variables
########################################################
csrxVersion="csrx:25.2R1.9"

########################################################
# Main
########################################################
echo "########################################################"
echo "# cSRX cPRD Demo Topology"
echo "########################################################"

case "$1" in
    "start")
        echo "- Starting cSRX Demo Topology..."
	echo " + Creating mgmt_net bridge..."
        docker network create \
                --driver bridge \
                --subnet=10.0.254.0/24 \
                --gateway=10.0.254.1 \
		--opt com.docker.network.bridge.enable_ip_masquerade=false \
                mgmt_net

	echo " + Creating csrx02-untrust bridge..."
	docker network create \
		--driver macvlan \
		--subnet=172.16.30.0/24 \
		--gateway=172.16.30.1 \
		--opt parent=ens6 \
		--opt com.docker.network.bridge.enable_ip_masquerade=true \
		csrx02-untrust	

	echo " + Creating csrx02-trust bridge..."
	docker network create \
		--driver macvlan \
		--subnet=172.16.2.0/24 \
		--gateway=172.16.2.1 \
		--opt parent=ens4 \
		--opt com.docker.network.bridge.enable_ip_masquerade=false \
		csrx02-trust	

	echo
        echo "- Starting cSRX Container..."
        docker run \
                --name csrx02 \
                --detach \
                --privileged \
                --rm \
                --network mgmt_net \
                --env CSRX_SIZE="CSRX-2CPU-2G" \
                --env CSRX_PORT_NUM=3 \
                --env CSRX_ROOT_PASSWORD=juniper123 \
                --env CSRX_FORWARD_MODE="wire" \
                --volume ./Configs/csrx02-securewire.txt:/root/config.txt \
                ${csrxVersion}

	echo
        echo "- Connecting additional networks to cSRX..."
	docker network connect csrx02-trust csrx02
	docker network connect csrx02-untrust csrx02
	echo

	# Import the configuration from the volume
        echo
        echo "- Importing Device Specific Configuration..."
        sleep 2
        docker exec -it csrx02 /usr/sbin/cli -f /root/config.txt
        sleep 2
	echo "-------------------------------------------------------"

	echo
	echo "Topology Setup Completed! "
        ;;
    "stop")
        echo "- Tearing down cSRX Demo Topology..."
        echo "  + Destroying Container..."
	docker stop csrx02

	echo " + Removing bridges..."
	docker network rm mgmt_net csrx02-untrust csrx02-trust

	echo
	echo "Topology Teardown Completed! "
        ;;
    *)
        echo "! ERROR: Must supply an option. Acceptable options are [start|stop]"
        ;;
esac

## End of Script ##
