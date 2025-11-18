#!/bin/bash

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
	docker network create --driver bridge mgmt_net	

	echo " + Creating untrust bridge..."
	docker network create \
		--driver bridge \
		--subnet=10.0.0.0/24 \
		--opt com.docker.network.bridge.enable_ip_masquerade=true \
		untrust	

	echo " + Creating csrx01-trust bridge..."
	docker network create \
		--driver bridge \
		--subnet=172.16.1.0/24 \
		--gateway=172.16.1.2 \
		csrx01-trust	
	echo

        echo "- Starting cSRX Container..."
        docker run \
                --name csrx01 \
                --detach \
		--privileged \
                --rm \
                --network mgmt_net \
		--volume csrx01-config:/config \
      		--volume csrx01-varlog:/var/log \
                ${csrxVersion}
	echo
        echo "- Starting vPC Container..."
        docker run \
                --name vpc1 \
                --interactive \
                --tty \
                --detach \
                --rm \
                --network csrx01-trust \
		--ip 172.16.1.10 \
                alpine:latest \
                ash

	echo
        echo "- Connecting additional networks to container..."
	docker network connect untrust csrx01
	docker network connect csrx01-trust csrx01
	echo
        ;;
    "stop")
        echo "- Destroying cSRX Container..."
	docker stop csrx01

        echo "- Destroying vPC Container..."
	docker stop vpc1

        echo "- Tearing down cSRX Demo Topology..."
	echo " + Removing mgmt_net bridge..."
	docker network rm mgmt_net	
	echo " + Removing untrust bridge..."
	docker network rm untrust	
	echo " + Removing csrx01-trust bridge..."
	docker network rm csrx01-trust	
        ;;
    *)
        echo "! ERROR: Must supply an option. Acceptable options are [start|stop]"
        ;;
esac
