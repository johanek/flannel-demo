# Flannel Demo

This repo is based on https://github.com/coreos/coreos-vagrant/ - it contains a Vagrant configuration for CoreOS that:

* Creates two CoreOS hosts, core-01 and core02, running etcd and flannel
* Configures flannel to use 10.20.0.0/16 network
* Maps a shared directory to /home/core/share

The script `docker-flannel-pipework-wrapper.sh` allows you to run docker containers with a specified IP address on any /24 subnet within the 10.20.0.0/16 range. It will:
* Check the IP address is valid, available, and within the 10.20.0.0/16 range
* Check if the subnet is in use on another host (each /24 subnet can only be used on a single coreos host)
* If the subnet is not used, create a new bridge device for the subnet, and register the subnet config for flannel in etcd
* If the subnet is already available, identify the correct bridge device
* Launch a docker container, and use pipework to setup the container networking and map the veth device to the correct bridge

```
git clone https://github.com/johanek/flannel-demo.git
cd flannel-demo
vagrant up
vagrant ssh [coreos-01|coreos-02]
./share/docker-flannel-pipework-wrapper.sh run [IP] [DOCKER OPTIONS]
```
