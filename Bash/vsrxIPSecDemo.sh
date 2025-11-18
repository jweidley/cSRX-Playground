#!/bin/bash
# Purpose: Setup cSRX to vSRX IPSec demo environment
# Version: 0.1
# Author: John Weidley
###########################################################################################################
# Notes:
# - Sometimes (depending on docker host performance) when you try to install the cSRX config you could
#	receive the message below. Just type 'yes', possibly multiple times, until it installs the config.
#		- Importing Device Specific Configuration...
#		could not open user interface connection: management daemon not responding
#		Retry connection attempts ? [yes,no] (yes) yes
###########################################################################################################

########################################################
# Variables
########################################################
csrxVersion="csrx:25.2R1.9"

########################################################
# Main
########################################################
echo "########################################################"
echo "# cSRX Demo Topology"
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
		--driver bridge \
		--subnet=10.1.0.0/24 \
		--opt com.docker.network.bridge.enable_ip_masquerade=true \
		csrx02-untrust	

	echo " + Creating csrx02-trust bridge..."
	docker network create \
		--driver bridge \
		--subnet=172.16.2.0/24 \
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
                --env CSRX_FORWARD_MODE="routing" \
                --volume ./Configs/csrx02-ipsec.txt:/root/config.txt \
                ${csrxVersion}

	echo
        echo "- Starting vPC Container..."
	# Privileged is required to change default route/gateway
        docker run \
                --name vpc1 \
                --interactive \
                --tty \
                --detach \
                --rm \
                --privileged \
                --network csrx02-trust \
		--ip 172.16.2.10 \
                alpine:latest \
                ash

	echo
        echo "- Connecting additional networks to container..."
	docker network connect csrx02-trust csrx02
	docker network connect csrx02-untrust csrx02
	echo

        # Alpine gateway change
        echo "- Configure Gateway on vpcs"
        docker exec vpc1 ip route delete default
        docker exec vpc1 ip route add default via 172.16.2.2 dev eth0

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
        echo "+ Destroying Containers..."
	docker stop csrx02 vpc1

	echo
	echo "+ Removing bridges..."
	docker network rm mgmt_net csrx02-untrust csrx02-trust

	echo
	echo "Topology Teardown Completed! "
        ;;
    *)
        echo "! ERROR: Must supply an option. Acceptable options are [start|stop]"
        ;;
esac

## End of Script ##
