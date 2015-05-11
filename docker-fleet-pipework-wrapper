#!/bin/bash

set -u

OPTION=$1;shift
IP=$1;shift
WORKDIR=$(dirname $0)

case $OPTION in
  run)

    # Convert IP to subnet, gateway and key for etcd
    SUBNET=$(echo $IP | sed 's/\(.*\..*\..*\)\..*/\1.0/')
    KEY="/coreos.com/networks/$SUBNET-24"
    # get bridge instance for network
    etcdctl ls $KEY >& /dev/null
    RESULT=$?
    if [ "$RESULT" -ne 0 ]; then
      echo "Network information at $KEY not found in etcd"
      exit 1
    fi
    INSTANCE=$(etcdctl get $KEY)

    # Check IP Address is available
    ping -c 1 -w 1 $IP >& /dev/null
    RESULT=$?
    if [ "$RESULT" -ne 1 ]; then 
      echo "IP address $IP already in use"
      exit 1
    fi

    # Create docker container and grab ID
    set -e
    DOCKERCMD="/usr/bin/docker run $@"
    echo "Running $DOCKERCMD"
    ID=$($DOCKERCMD)

    # Create pipework command
    PIPEWORKCMD="sudo $WORKDIR/pipework bridge$INSTANCE $ID $IP/24"
    echo "Running $PIPEWORKCMD"
    $PIPEWORKCMD
    ;;
  *)
    echo "Usage: $0 run [IP] [DOCKER OPTIONS]"
    ;;
esac
