#!/bin/bash
#
# docker-flannel-pipework-wrapper.sh
# Wrapper around docker, flannel and pipework to allow setting a custom IP when launching a docker container
#
# The wrapper will:
#   - Check if the IP is in use, and fail if so
#   - Check if the subnet is valid for this host, and fail if not
#   - Either:
#     - Identify the correct bridge device to use if the subnet is setup, or
#     - Create a bridge device fot the subnet, and register the subnet in etcd for flannel
#   - Launch a docker container with no networking
#   - Use pipework to setup the container networking, attach to the correct bridge, and set the IP

set -u

OPTION=$1;shift
IP=$1;shift
WORKDIR=$(dirname $0)
IPADDR=$(networkctl status eth1 | grep '^\s*Address' | awk -F': ' '{ print $2 }')

function getbridge {
  # Check if subnet already defined
  SUBNETKEY="/coreos.com/network/subnets/$SUBNET-24"
  RESULT=$?
  if etcdctl ls $SUBNETKEY >& /dev/null; then
    # Subnet defined, check if subnet on this host
    SUBNETIP=$(etcdctl get $SUBNETKEY | $WORKDIR/jq .PublicIP | sed 's/\"//g')
    if [ "$SUBNETIP" = "$IPADDR" ]; then
      # Get bridge name
      BRIDGE=$(etcdctl get $SUBNETKEY | $WORKDIR/jq .Bridge | sed 's/"//g')
      # Check the bridge is defined
      if [ $BRIDGE = null ]; then
        echo "Subnet $SUBNET does not have a bridge defined"
        usage
      else
        echo "Using existing bridge $BRIDGE for $SUBNET"
      fi
    else
      echo "Subnet $SUBNET is in use by another host"
      usage
    fi
  else
    # Subnet available, create the bridge and set the subnet key in etcd
    BRIDGE="bridge$(nextbridge)"
    echo "Creating new bridge $BRIDGE for $SUBNET"
    sudo brctl addbr $BRIDGE
    sudo ip link set $BRIDGE up
    sudo ip link set dev $BRIDGE mtu 1472
    sudo ip addr add $GATEWAY/24 dev $BRIDGE
    etcdctl set $SUBNETKEY \{\"PublicIP\":\"$IPADDR\",\"Bridge\":\"$BRIDGE\"\} > /dev/null
  fi
}

function nextbridge {
  local CURRENT=$(brctl show | grep ^bridge | sed 's/^bridge\([0-9]*\).*/\1/' | sort -nr | head -1)
  echo $(expr $CURRENT + 1)
}

function valid_ip {
  local  ip=$1
  local  stat=1

  if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
      OIFS=$IFS
      IFS='.'
      ip=($ip)
      IFS=$OIFS
      [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
          && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
      stat=$?
  fi
  return $stat
}

function usage {
  echo "Usage: $0 run [IP] [DOCKER OPTIONS]"
  exit 1
}

case $OPTION in
  run)

    # Convert IP to subnet, gateway and key for etcd
    SUBNET=$(echo $IP | sed 's/\(.*\..*\..*\)\..*/\1.0/')
    GATEWAY=$(echo $SUBNET | sed 's/\.0$/\.1/')

    # Check IP Address is valid
    valid_ip $IP
    if [ $? -ne 0 ]; then
      echo "IP address $IP is not valid"
      usage
    fi

    # Check IP address within 10.20.0.0/16 CIDR range
    # Very lame/simple
    IFS=. read -r i1 i2 i3 i4 <<< "$IP"
    if [ $i1 -ne 10 ] || [ $i2 -ne 20 ]; then
      echo "IP address $IP not in 10.20.0.0/16 range"
      usage
    fi

    # Check IP Address is available
    ping -c 1 -w 1 $IP >& /dev/null
    if [ $? -ne 1 ]; then
      echo "IP address $IP already in use"
      usage
    fi

    # Create or identify bridge device
    getbridge

    # Create docker container and grab ID
    set -e
    DOCKERCMD="/usr/bin/docker run --net none $@"
    echo "Running $DOCKERCMD"
    ID=$($DOCKERCMD)

    # Create pipework command
    PIPEWORKCMD="sudo $WORKDIR/pipework $BRIDGE $ID $IP/24@$GATEWAY"
    echo "Running $PIPEWORKCMD"
    $PIPEWORKCMD
    ;;
  *)
    usage
    ;;
esac

