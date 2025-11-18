#!/bin/bash
# Purpose: Launch consistent cSRX Demo Environments
# Version: 0.1.5
# Author: John Weidley
###################################################################
# Dependencies:
# - Linux (tested with Ubuntu 22)
#   + Docker installed (27.2.1)
#   + Internet connection (to download containers)
#
# CAVEATS:
# 1. Fails to start container if there are multiple container versions
# 2. Need to have different config & logs for single & dual
#
# References:
# Diagram: https://textik.com/
# https://serverfault.com/questions/1067577/how-to-connect-container-in-another-docker-network
# https://serverfault.com/questions/1102209/how-to-disable-docker-network-isolation
###################################################################

##############################
# Variables
##############################
# TMPOUTPUT the file that stores output to be used in whiptail dialogs.
TMPOUTPUT="/tmp/docker-test-env-output.txt"

# Set the menu color palette
export NEWT_COLORS='
    root=white,black
    roottext=,black
    border=black,lightgray
    window=lightgray,lightgray
    shadow=black,gray
    title=black,lightgray
    button=black,cyan
    actbutton=white,cyan
    compactbutton=black,lightgray
    checkbox=black,lightgray
    actcheckbox=lightgray,cyan
    entry=black,lightgray
    disentry=gray,lightgray
    label=black,lightgray
    listbox=black,lightgray
    actlistbox=black,cyan
    sellistbox=lightgray,black
    actsellistbox=lightgray,black
    textbox=black,lightgray
    acttextbox=black,cyan
    emptyscale=,gray
    fullscale=,cyan
    helpline=white,black
' \

##############################
# Functions
##############################

selectTopo () {
	TOPO=$(whiptail --backtitle "cSRX Demo Menu" --title "Select Topology" --separate-output --radiolist "Choose options" 10 35 5 \
		"SecureWire" "Secure Wire" OFF \
		"Single"     "Single cSRX" OFF \
		"Dual"       "Dual cSRX" OFF 3>&1 1>&2 2>&3)

	if [ -z "$TOPO" ]; then
		echo "No option was chosen (user hit Cancel)"
		exit
	elif [ $TOPO == "SecureWire" ]; then
		echo "The user chose topology: $TOPO"
		secureWireBanner
	elif [ $TOPO == "Single" ]; then
		echo "The user chose topology: $TOPO"
		singleBanner
	elif [ $TOPO == "Dual" ]; then
		echo "The user chose topology: $TOPO"
		dualBanner
	else	
		echo "ERROR: Invalid Option! Exiting!"
		exit
	fi
}

secureWireBanner () {
cat << "EOF" > ./startBanner.txt
      ____  ____  __  __          ____                         __        ___
  ___/ ___||  _ \ \ \/ /         / ___|  ___  ___ _   _ _ __ __\ \      / (_)_ __ ___
 / __\___ \| |_) | \  /   _____  \___ \ / _ \/ __| | | | '__/ _ \ \ /\ / /| | '__/ _ \
| (__ ___) |  _ <  /  \  |_____|  ___) |  __/ (__| |_| | | |  __/\ V  V / | | | |  __/
 \___|____/|_| \_\/_/\_\         |____/ \___|\___|\__,_|_|  \___| \_/\_/  |_|_|  \___|

-------------------------------------------------------------------------------------
     
         +-----------------+          
         |     csrx01      |          
         +----+--------+---+          
      ge-0/0/0|        |ge-0/0/1      
     (untrust)|        |(trust)
              |        |              
    +---------+---+ +--+----------+  
    |    vpc1     | |    vpc2     |  
    |(172.16.1.10)| |(172.16.1.11)|  
    +-------------+ +-------------+  

EOF
    sleep 1

    # Start the banner
    whiptail --backtitle "cSRX Demo Menu" --textbox ./startBanner.txt 31 100

    # Call singleMenu
    secureWireMenu
}

singleBanner () {
cat << "EOF" > ./startBanner.txt
      ____  ____  __  __          ____  _             _
  ___/ ___||  _ \ \ \/ /         / ___|(_)_ __   __ _| | ___
 / __\___ \| |_) | \  /   _____  \___ \| | '_ \ / _` | |/ _ \
| (__ ___) |  _ <  /  \  |_____|  ___) | | | | | (_| | |  __/
 \___|____/|_| \_\/_/\_\         |____/|_|_| |_|\__, |_|\___|
                                                |___/
-------------------------------------------------------------------------------------
         +-----------------+          
         |  csrx01-untrust |          
         |   (10.0.1.1)    |          
         +--------+--------+          
                  |                   
         ge-0/0/1 | 10.0.1.2/24       
         +--------+--------+          
         |     csrx01      |          
         +----+--------+---+          
      ge-0/0/0|        |ge-0/0/2      
 172.16.1.2/24|        |172.16.11.2/24
              |        |              
    +---------+---+ +--+-----------+  
    |    vpc1     | |    vpc11     |  
    |(172.16.1.10)| |(172.16.11.10)|  
    +-------------+ +--------------+  

EOF
    sleep 1

    # Start the banner
    whiptail --backtitle "cSRX Demo Menu" --textbox ./startBanner.txt 31 100

    # Call singleMenu
    singleMenu
}

dualBanner () {
cat << "EOF" > ./startBanner.txt
      ____  ____  __  __          ____              _
  ___/ ___||  _ \ \ \/ /         |  _ \ _   _  __ _| |
 / __\___ \| |_) | \  /   _____  | | | | | | |/ _` | |
| (__ ___) |  _ <  /  \  |_____| | |_| | |_| | (_| | |
 \___|____/|_| \_\/_/\_\         |____/ \__,_|\__,_|_|

-------------------------------------------------------------------------------------
         +-----------------+                 +-----------------+    
         |  csrx01-untrust |====IPSec_VPN====|  csrx02-untrust |    
         |   (10.0.1.1)    |                 |   (10.0.2.1)    |    
         +--------+--------+                 +--------+--------+    
                  |                                   |             
         ge-0/0/1 | 10.0.1.2/24              ge-0/0/1 | 10.0.2.2/24 
         +--------+--------+                 +--------+--------+    
         |     csrx01      |                 |     csrx02      |    
         +----+--------+---+                 +-------+---------+    
      ge-0/0/0|        |ge-0/0/2            ge-0/0/0 | 172.16.2.2/24
 172.16.1.2/24|        |172.16.11.2/24               |              
              |        |                             |              
    +---------+---+ +--+-----------+           +-----+-------+      
    |    vpc1     | |    vpc11     |           |    vpc2     |      
    |(172.16.1.10)| |(172.16.11.10)|           |(172.16.2.10)|      
    +-------------+ +--------------+           +-------------+      

EOF
    sleep 1

    # Start the banner
    whiptail --backtitle "cSRX Demo Menu" --textbox ./startBanner.txt 31 100

    # Call dualMenu
    dualMenu
}

checkImages () {
        echo "- Checking container dependencies..."

	# Check cSRX image is installed. This is a manual process!
	checkCSRX=$(docker image ls csrx -q)

	if [ -z $checkCSRX ]; then
		echo "  ! ERROR: cSRX image NOT installed. Please go to the URL below to download"
		echo "  !        and use the 'docker load -i xxx' command in import it."
		echo "  !        https://support.juniper.net/support/downloads/?p=csrx "

		# Fatal error: Exit the menu
		exit
	else
		echo "  + cSRX image is present"

                # Grab cSRX version from docker
                cSRXVersion=$(docker image ls csrx | egrep -v 'TAG' | awk '{print $2}')
                echo "  + cSRX version is $cSRXVersion"
	fi

	# Check if the Alpine image is install, else download it.
	checkAlpine=$(docker image ls alpine -q)

	if [ -z $checkAlpine ]; then
		echo "  ! Alpine not present, downloading it..."

		docker image pull alpine
		echo
	else
		echo "  + Alpine image is present"
	fi
}

secureWireMenu () {
    CHOICE=$(whiptail --backtitle "cSRX Demo Menu" --title "cSRX Management-SecureWire" --menu "Select Option" 18 100 10 \
        "1" "  Create Secure Wire Demo Environment" \
        "2" "  Reset Demo Environment (remove/destroy)" \
        "3" "  Show Network Diagram" \
        "R" "  Show Resources" 3>&1 1>&2 2>&3)

    if [ -z "$CHOICE" ]; then
        # Remove tmp banner file
        if [ -f ./startBanner.txt ]; then
                echo "- removing start banner"
                rm ./startBanner.txt
        fi

        echo "No option was chosen (user hit Cancel)"
        exit
    else
        wedge=$CHOICE
        printf "Menu option selected: $wedge\n"

        # Redirect to the correct wedge Interface list
        if [ $CHOICE == "1" ]; then
                createSecureWireEnvironment
        elif [ $CHOICE == "2" ]; then
                resetSecureWireEnvironment
        elif [ $CHOICE == "3" ]; then
                showBanner
        elif [ $CHOICE == "R" ]; then
                showResources
        else
            whiptail --msgbox "ERROR: Option NOT implemented" 10 100
            if [ "$TOPO" == "Single" ]; then
                singleMenu
            elif [ "$TOPO" == "Dual" ]; then
                dualMenu
            elif [ "$TOPO" == "SecureWire" ]; then
                secureWireMenu
            fi
        fi
    fi
}

singleMenu () {
    CHOICE=$(whiptail --backtitle "cSRX Demo Menu" --title "cSRX Management-Single" --menu "Select Option" 18 100 10 \
        "1" "  Create Single Firewall Demo Environment" \
	"2" "  Reset Demo Environment (remove/destroy)" \
	"3" "  Show Network Diagram" \
        "R" "  Show Resources" 3>&1 1>&2 2>&3)

    if [ -z "$CHOICE" ]; then
	# Remove tmp banner file
	if [ -f ./startBanner.txt ]; then
		echo "- removing start banner"
		rm ./startBanner.txt
	fi

        echo "No option was chosen (user hit Cancel)"
        exit
    else
        wedge=$CHOICE
        printf "Menu option selected: $wedge\n"

        # Redirect to the correct wedge Interface list
        if [ $CHOICE == "1" ]; then
		createEnvironment
        elif [ $CHOICE == "2" ]; then
		resetSingleEnvironment
        elif [ $CHOICE == "3" ]; then
		showBanner
        elif [ $CHOICE == "R" ]; then
		showResources
        else
            whiptail --msgbox "ERROR: Option NOT implemented" 10 100
	    if [ "$TOPO" == "Single" ]; then
		singleMenu
            elif [ "$TOPO" == "Dual" ]; then
                dualMenu
            elif [ "$TOPO" == "SecureWire" ]; then
                secureWireMenu
            fi
        fi
    fi
}

dualMenu () {
    CHOICE=$(whiptail --backtitle "cSRX Demo Menu" --title "cSRX Management-Dual" --menu "Select Option" 18 100 10 \
        "1" "  Create Dual Firewall Demo Environment" \
        "2" "  Reset Demo Environment (remove/destroy)" \
        "3" "  Show Network Diagram" \
        "R" "  Show Resources" 3>&1 1>&2 2>&3)

    if [ -z "$CHOICE" ]; then
        # Remove tmp banner file
        if [ -f ./startBanner.txt ]; then
                echo "- removing start banner"
                rm ./startBanner.txt
        fi

        echo "No option was chosen (user hit Cancel)"
        exit
    else
        wedge=$CHOICE
        printf "Menu option selected: $wedge\n"

        # Redirect to the correct wedge Interface list
        if [ $CHOICE == "1" ]; then
                createDualEnvironment
        elif [ $CHOICE == "2" ]; then
                resetDualEnvironment
        elif [ $CHOICE == "3" ]; then
                showBanner
        elif [ $CHOICE == "R" ]; then
                showResources
        else
            whiptail --msgbox "ERROR: Option NOT implemented" 10 100
	    if [ "$TOPO" == "Single" ]; then
                singleMenu
            elif [ "$TOPO" == "Dual" ]; then
                dualMenu
            elif [ "$TOPO" == "SecureWire" ]; then
                secureWireMenu
            fi
        fi
    fi
}

############################################################################################
# verifyVolumes function is used for long-term cSRX demos/testing where you need/want to 
# have multiple versions of configs and logs that survive across container stop/starts. The
# default operation is a 1 and done. Search this script for the commented verifyVolumes
# lines and the --volume options for cSRX containers.
############################################################################################
verifyVolumes () {
	containerName=$1
	echo "- Checking/creating container volumes: $1"

	# Checking/creating container volumes	
	checkConfig=$(docker volume inspect $containerName-config --format='{{ .Name }}')

	if [ -z $checkConfig ]; then
		echo "  + Creating config volume"
		docker volume create $containerName-config
	else
		echo "  + Config Volume exists"
	fi

	checkLog=$(docker volume inspect $containerName-varlog --format='{{ .Name }}')

	if [ -z $checkLog ]; then
		echo "  + Creating Log volume"
		docker volume create $containerName-varlog
	else
		echo "  + Log Volume exists"
	fi
}

createSecureWireEnvironment () {
        # Build the required network bridges
        echo " + Creating mgmt_net bridge..."
        docker network create \
                --driver bridge \
                --subnet=10.0.254.0/24 \
                --gateway=10.0.254.1 \
                mgmt_net

        echo " + Creating csrx01-untrust bridge..."
        # masq is required to NAT traffic to the host bridge to make it routable
        docker network create \
                --driver bridge \
                --opt com.docker.network.bridge.enable_ip_masquerade=false \
                csrx01-untrust

        echo " + Creating csrx01-trust bridge..."
        docker network create \
                --driver bridge \
                --opt com.docker.network.bridge.enable_ip_masquerade=false \
                csrx01-trust

        # cSRX01
        echo "- Starting Container: csrx01"
        docker run \
                --name csrx01 \
                --detach \
                --privileged \
                --rm \
                --network mgmt_net \
                --env CSRX_SIZE="CSRX-2CPU-2G" \
                --env CSRX_PORT_NUM=3 \
                --env CSRX_ROOT_PASSWORD=juniper123 \
                --env CSRX_FORWARD_MODE="wire" \
                --volume ./Configs/csrx01-securewire.txt:/root/config.txt \
                csrx:${cSRXVersion}

        # Alpine Trust PC1
        echo "- Starting Container: vpc1"
        docker run \
                --name vpc1 \
                --interactive \
                --tty \
                --detach \
                --rm \
                --privileged \
                alpine:latest \
                ash

        # Alpine Trust PC2
        echo "- Starting Container: vpc2"
        docker run \
                --name vpc2 \
                --interactive \
                --tty \
                --detach \
                --rm \
                --privileged \
                alpine:latest \
                ash

        # Connect addition networks to cSRX (order matters)
        echo
        echo "- Connecting additional networks to container..."
        docker network connect csrx01-trust csrx01
        docker network connect csrx01-trust vpc1
        docker network connect csrx01-untrust csrx01
        docker network connect csrx01-untrust vpc2

        # Alpine gateway change
        echo "- Configure IP addresses on vpcs"
        docker exec vpc1 ip route delete default
        docker exec vpc1 ip addr flush dev eth1
        docker exec vpc1 ip address add 172.16.1.10/24 dev eth1
        docker exec vpc2 ip route delete default
        docker exec vpc2 ip addr flush dev eth1
        docker exec vpc2 ip address add 172.16.1.11/24 dev eth1

        # Import the configuration from the volume
        echo
        echo "- Importing Device Specific Configuration..."
        sleep 2
        docker exec -it csrx01 /usr/sbin/cli -f /root/config.txt
        sleep 2

        # Completion banner then back to start menu
        whiptail --msgbox "SUCCESS! Demo environment created." 10 100
        if [ "$TOPO" == "Single" ]; then
                singleMenu
        elif [ "$TOPO" == "Dual" ]; then
                dualMenu
        elif [ "$TOPO" == "SecureWire" ]; then
                secureWireMenu
        fi
}

createEnvironment () {
	# Build the required network bridges
        echo " + Creating mgmt_net bridge..."
        docker network create \
                --driver bridge \
                --subnet=10.0.254.0/24 \
                --gateway=10.0.254.1 \
                mgmt_net

        echo " + Creating csrx01-untrust bridge..."
        # masq is required to NAT traffic to the host bridge to make it routable
        docker network create \
                --driver bridge \
                --subnet=10.0.1.0/24 \
                --opt com.docker.network.bridge.enable_ip_masquerade=true \
                csrx01-untrust

        echo " + Creating csrx01-trust bridge..."
        docker network create \
                --driver bridge \
                --subnet=172.16.1.0/24 \
                --opt com.docker.network.bridge.enable_ip_masquerade=false \
                csrx01-trust

        echo " + Creating csrx01-dmz bridge..."
        docker network create \
                --driver bridge \
                --subnet=172.16.11.0/24 \
                --opt com.docker.network.bridge.enable_ip_masquerade=false \
                csrx01-dmz

	# Check/create config & log volumes for crpd instances
	#verifyVolumes csrx01

	# cSRX01
	echo "- Starting Container: csrx01"
        docker run \
                --name csrx01 \
                --detach \
                --privileged \
                --rm \
                --network mgmt_net \
		--env CSRX_SIZE="CSRX-2CPU-2G" \
		--env CSRX_PORT_NUM=4 \
		--env CSRX_ROOT_PASSWORD=juniper123 \
		--env CSRX_FORWARD_MODE="routing" \
                --volume ./Configs/csrx01-single.txt:/root/config.txt \
                csrx:${cSRXVersion}

	# Alpine Trust PC
	echo "- Starting Container: vpc1"
        docker run \
                --name vpc1 \
                --interactive \
                --tty \
                --detach \
                --rm \
                --privileged \
                --network csrx01-trust \
                --ip 172.16.1.10 \
                alpine:latest \
                ash

	# Alpine DMZ PC
	echo "- Starting Container: vpc11"
        docker run \
                --name vpc11 \
                --interactive \
                --tty \
                --detach \
                --rm \
                --privileged \
                --network csrx01-dmz \
                --ip 172.16.11.10 \
                alpine:latest \
                ash

	# Alpine gateway change
	echo "- Configure Gateway on vpcs"
	docker exec vpc1 ip route delete default
	docker exec vpc1 ip route add default via 172.16.1.2 dev eth0
	docker exec vpc11 ip route delete default
	docker exec vpc11 ip route add default via 172.16.11.2 dev eth0

	# Connect addition networks to cSRX (order matters)
        echo
        echo "- Connecting additional networks to container..."
        docker network connect csrx01-trust csrx01
        docker network connect csrx01-untrust csrx01
        docker network connect csrx01-dmz csrx01

	# Import the configuration from the volume
        echo
        echo "- Importing Device Specific Configuration..."
	sleep 2
	docker exec -it csrx01 /usr/sbin/cli -f /root/config.txt
	sleep 2

	# Completion banner then back to start menu
	whiptail --msgbox "SUCCESS! Demo environment created." 10 100
	if [ "$TOPO" == "Single" ]; then
                singleMenu
        elif [ "$TOPO" == "Dual" ]; then
                dualMenu
        elif [ "$TOPO" == "SecureWire" ]; then
                secureWireMenu
        fi
}

createDualEnvironment () {
	# Build the required network bridges
        echo " + Creating mgmt_net bridge..."
        docker network create \
                --driver bridge \
                --subnet=10.0.254.0/24 \
                --gateway=10.0.254.1 \
                mgmt_net

        echo " + Creating csrx01-untrust bridge..."
        # masq is required to NAT traffic to the host bridge to make it routable
        docker network create \
                --driver bridge \
                --subnet=10.0.1.0/24 \
                --opt com.docker.network.bridge.enable_ip_masquerade=true \
                csrx01-untrust

        echo " + Creating csrx02-untrust bridge..."
        # masq is required to NAT traffic to the host bridge to make it routable
        docker network create \
                --driver bridge \
                --subnet=10.0.2.0/24 \
                --opt com.docker.network.bridge.enable_ip_masquerade=true \
                csrx02-untrust

        echo " + Creating csrx01-trust bridge..."
        docker network create \
                --driver bridge \
                --subnet=172.16.1.0/24 \
                --opt com.docker.network.bridge.enable_ip_masquerade=false \
                csrx01-trust

        echo " + Creating csrx02-trust bridge..."
        docker network create \
                --driver bridge \
                --subnet=172.16.2.0/24 \
                --opt com.docker.network.bridge.enable_ip_masquerade=false \
                csrx02-trust

        echo " + Creating csrx01-dmz bridge..."
        docker network create \
                --driver bridge \
                --subnet=172.16.11.0/24 \
                --opt com.docker.network.bridge.enable_ip_masquerade=false \
                csrx01-dmz

	# Check/create config & log volumes for crpd instances
	#verifyVolumes csrx01
	#verifyVolumes csrx02

	# cSRX01
	#--volume csrx01-config:/config \
        #--volume csrx01-varlog:/var/log \
	echo "- Starting Container: csrx01"
        docker run \
                --name csrx01 \
                --detach \
                --privileged \
                --rm \
                --network mgmt_net \
                --env CSRX_SIZE="CSRX-2CPU-2G" \
                --env CSRX_PORT_NUM=4 \
                --env CSRX_ROOT_PASSWORD=juniper123 \
                --env CSRX_FORWARD_MODE="routing" \
                --volume ./Configs/csrx01-dual.txt:/root/config.txt \
                csrx:${cSRXVersion}

	# cSRX02
	#--volume csrx02-config:/config \
        #--volume csrx02-varlog:/var/log \
	echo "- Starting Container: csrx02"
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
                --volume ./Configs/csrx02-dual.txt:/root/config.txt \
                csrx:${cSRXVersion}

	# Alpine PC
	echo "- Starting Container: vpc1"
        docker run \
                --name vpc1 \
                --interactive \
                --tty \
                --detach \
                --rm \
                --privileged \
                --network csrx01-trust \
                --ip 172.16.1.10 \
                alpine:latest \
                ash

        # Alpine DMZ PC
        echo "- Starting Container: vpc11"
        docker run \
                --name vpc11 \
                --interactive \
                --tty \
                --detach \
                --rm \
                --privileged \
                --network csrx01-dmz \
                --ip 172.16.11.10 \
                alpine:latest \
                ash

	echo "- Starting Container: vpc2"
        docker run \
                --name vpc2 \
                --interactive \
                --tty \
                --detach \
                --rm \
                --privileged \
                --network csrx02-trust \
                --ip 172.16.2.10 \
                alpine:latest \
                ash

	# Alpine gateway change
	echo "- Configure Gateways on vpc"
	docker exec vpc1 ip route delete default
	docker exec vpc1 ip route add default via 172.16.1.2 dev eth0
	docker exec vpc11 ip route delete default
	docker exec vpc11 ip route add default via 172.16.11.2 dev eth0
	docker exec vpc2 ip route delete default
	docker exec vpc2 ip route add default via 172.16.2.2 dev eth0

        echo
        echo "- Connecting additional networks to container..."
        docker network connect csrx01-trust csrx01
        docker network connect csrx01-untrust csrx01
        docker network connect csrx01-dmz csrx01
        docker network connect csrx02-trust csrx02
        docker network connect csrx02-untrust csrx02

	# Import the configuration from the volume
        echo
        echo "- Importing Device Specific Configuration..."
	sleep 2
        echo "  + Importing csrx01 Configuration..."
	docker exec -it csrx01 /usr/sbin/cli -f /root/config.txt
	sleep 2
        echo "  + Importing csrx02 Configuration..."
	docker exec -it csrx02 /usr/sbin/cli -f /root/config.txt
	sleep 2

	# Add iptables to allow container to container traffic
	leftBridge=$(ip -br a | egrep '10\.0\.1\.' | awk '{print $1}')
	rightBridge=$(ip -br a | egrep '10\.0\.2\.' | awk '{print $1}')

	if [[ -z "$leftBridge" || -z "$rightBridge" ]]; then
		echo "  !!!! ERROR: Cant determine bridge names for iptables rules! "
		echo "  !!!!        Inter-container traffic will NOT work!"
	else
		echo "- Adding iptables rules to permit inter-container traffic"
		sudo iptables -I DOCKER-USER -i $leftBridge -o $rightBridge -j ACCEPT
		sudo iptables -I DOCKER-USER -i $rightBridge -o $leftBridge -j ACCEPT
	fi

	# Completion banner then back to start menu
	whiptail --msgbox "SUCCESS! Demo environment created." 10 100
	if [ "$TOPO" == "Single" ]; then
                singleMenu
        elif [ "$TOPO" == "Dual" ]; then
                dualMenu
        elif [ "$TOPO" == "SecureWire" ]; then
                secureWireMenu
        fi
}

resetSecureWireEnvironment () {
        # Resetting Demo environment
        echo "! Resetting Demo environment"

        # Stop containers
        echo "  + stopping containers..."
        docker stop csrx01 vpc1 vpc2

        # Deleting network namespaces
        echo "  + Removing network bridges..."
        echo "    + Removing mgmt_net bridge..."
        docker network rm mgmt_net
        echo "    + Removing csrx01-untrust bridge..."
        docker network rm csrx01-untrust
        echo "    + Removing csrx01-trust bridge..."
        docker network rm csrx01-trust

        # Return to the menu
        sleep 1
        if [ "$TOPO" == "Single" ]; then
                singleMenu
        elif [ "$TOPO" == "Dual" ]; then
                dualMenu
        elif [ "$TOPO" == "SecureWire" ]; then
                secureWireMenu
        fi
}

resetSingleEnvironment () {
        # Resetting Demo environment
        echo "! Resetting Demo environment"

        # Stop containers
        echo "  + stopping containers..."
        docker stop csrx01 vpc1 vpc11

        # Deleting network namespaces
        echo "  + Removing network bridges..."
        echo "    + Removing mgmt_net bridge..."
        docker network rm mgmt_net
        echo "    + Removing csrx01-untrust bridge..."
        docker network rm csrx01-untrust
        echo "    + Removing csrx01-trust bridge..."
        docker network rm csrx01-trust
        echo "    + Removing csrx01-dmz bridge..."
        docker network rm csrx01-dmz

        # Return to the menu
        sleep 1
	if [ "$TOPO" == "Single" ]; then
                singleMenu
        elif [ "$TOPO" == "Dual" ]; then
                dualMenu
        elif [ "$TOPO" == "SecureWire" ]; then
                secureWireMenu
        fi
}

resetDualEnvironment () {
	# Resetting Demo environment
	echo "! Resetting Demo environment"

	# Delete iptables for container to container traffic
        leftBridge=$(ip -br a | egrep '10\.0\.1\.' | awk '{print $1}')
        rightBridge=$(ip -br a | egrep '10\.0\.2\.' | awk '{print $1}')

	if [[ -z "$leftBridge" || -z "$rightBridge" ]]; then
		echo "  !!!! ERROR: Cant determine bridge names for iptables rules! "
		echo "  !!!!        Unable to remove inter-container rules, do it manually!"
	else
		echo "- Removing iptables rules that permit inter-container traffic"
		sudo iptables -D DOCKER-USER -i $leftBridge -o $rightBridge -j ACCEPT
		sudo iptables -D DOCKER-USER -i $rightBridge -o $leftBridge -j ACCEPT
	fi

	# Stop containers
	echo "  + stopping containers..."
	docker stop csrx01 csrx02 vpc1 vpc2 vpc11

	# Deleting network namespaces
	echo "  + Removing network bridges..."
        echo "    + Removing mgmt_net bridge..."
        docker network rm mgmt_net
        echo "    + Removing csrx01-untrust bridge..."
        docker network rm csrx01-untrust
        echo "    + Removing csrx02-untrust bridge..."
        docker network rm csrx02-untrust
        echo "    + Removing csrx01-trust bridge..."
        docker network rm csrx01-trust
        echo "    + Removing csrx01-dmz bridge..."
        docker network rm csrx01-dmz
        echo "    + Removing csrx02-trust bridge..."
        docker network rm csrx02-trust

	# Return to the menu
	sleep 1
	if [ "$TOPO" == "Single" ]; then
                singleMenu
        elif [ "$TOPO" == "Dual" ]; then
                dualMenu
        elif [ "$TOPO" == "SecureWire" ]; then
                secureWireMenu
        fi
}

showBanner () {
	# Start the banner
	whiptail --backtitle "cSRX Demo Menu" --textbox ./startBanner.txt 31 100

	# Restart the Menu
	if [ "$TOPO" == "Single" ]; then
		singleMenu
	elif [ "$TOPO" == "Dual" ]; then
		dualMenu
        elif [ "$TOPO" == "SecureWire" ]; then
                secureWireMenu
	fi
}

showResources () {
	echo > $TMPOUTPUT
	echo "############# CONTAINERS #############" >> $TMPOUTPUT
	docker ps --format='table {{ .Names }}\t{{ .ID }}\t{{ .Image }}\t{{ .Status }}' >> $TMPOUTPUT
	echo >> $TMPOUTPUT
	echo "############# CONTAINER - IPs - MAC #############" >> $TMPOUTPUT
	docker ps -q | xargs -n 1 docker inspect --format ' {{ .Name }}  {{range .NetworkSettings.Networks}}{{.IPAddress}}  {{.MacAddress}}{{end}}' | sed 's/ \// /' >> $TMPOUTPUT

	# Start the banner
	whiptail --backtitle "cSRX Demo Menu" --scrolltext --title "Show Configured Resources" --textbox $TMPOUTPUT 28 110

	# Go back to the menu
        if [ "$TOPO" == "Single" ]; then
                singleMenu
        elif [ "$TOPO" == "Dual" ]; then
                dualMenu
        elif [ "$TOPO" == "SecureWire" ]; then
                secureWireMenu
        fi
}

##############################
# Main
##############################
# Print console start message, mostly used for debugging
echo "===================================================================="
echo " cSRX Demo Menu"
echo "===================================================================="

# Check for container dependencies first (exit if necessary)
checkImages

# Select which topology
selectTopo

# Terminate
exit

## End of Script ##
