# Flannel Demo

This repo is based on https://github.com/coreos/coreos-vagrant/ - it contains a Vagrant configuration for CoreOS that:

* Creates a single CoreOS host, running etcd and fleet
* Runs 2 instances of flannel, configured with subnets 10.20.0.0/24 and 10.20.1.0/24
* Maps a shared directory to /home/core/share

The script `docker-fleet-pipework-wrapper` allows you to run docker containers with a specified IP address on one of the subnets managed by flannel. This needs to be run on the coreos host to manipulate the container network interfaces.

```
git clone https://github.com/johanek/flannel-demo.git
cd flannel-demo
vagrant up
vagrant ssh
./share/docker-fleet-pipework-wrapper run [IP] [DOCKER OPTIONS]
```
