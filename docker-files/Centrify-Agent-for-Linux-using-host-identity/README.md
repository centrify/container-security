# Enable Centrify Agent for Linux in a docker container using host identity

## Introduction
Centrify Agent for Linux (version 18.7 and later) provides support for CoreOS.
You can install Centrify Agent for Linux in a CoreOS host and enroll it to Centrify Identity Platform. 
This document describes how one can enable Centrify Agenet for Linux functionalities inside docker containers after
the host has installed and enabled such functionalities.   All docker containers share the same identity as the host; and
there is no need for individual container to enroll to Centrify Identify Platform separately.

Note: You can also install and enroll the docker container directly to Centrify Identity Platform, which results in unique 
identity (system) in Centrify Identity Platform. 
See [Enable Centrify Agent For Linux in a CentOS container](http://github.com/centrify/docker_files/tree/master/centrify_agent_for_linux/README.md) 
for details.

## Files for docker container support
* [dockerfile.centos.cc](dockerfile.centos.cc): docker file for Centos container
* [dockerfile.ubuntu.cc](dockerfile.ubuntu.cc): docker file for Ubuntu container
* [ubuntu_startup.sh](ubuntu_startup.sh): startup file for Ubuntu container

## Enable these steps to enable Centrify Agent for Linux inside docker containers:
Follow these steps to enable Centrify Agent for Linux functionality inside docker containers:
1. Install Centrify Agent for Linux (version 18.7 or later) in CoreOS host.
1. Enroll the CoreOS host to Centrify Identity Platform.
1. Login to an account that can run docker commands and can run sudo commands as root (e.g., core)
1. Run the following commands to set up a sandbox environment:
   * **mkdir ~/sandbox**
   * **cd ~/sandbox**
   * __sudo tar -cvf docker.copy.tar /etc/centrifycc/centrifycc.conf /etc/centrifycc/*.ignore__
1. For creating and running a Ubuntu container:
   * Copy the files dockerfile.ubuntu.cc and ubuntu_startup.sh to ~/sandbox
   * Edit the file dockerfile.ubuntu.cc:
     - Replace __$ROOT_PASSWORD__ by the password of the root user in the container
   * Run this command to build the docker image:
     - __docker build -t "ubuntu:cc" -f ~/sandbox/dockerfile.ubuntu.cc .__ 
	 - (note the period as the last character)
   * Run this command to run the docker image:
     - __docker run -d -p $SSHD_PORT:22 -v /var/centrify/cloud:/var/centrify/cloud ubuntu:cc__
	 - replace __$SSHD_PORT__ by the port to be used for sshd service in this container.
	 - Note: if rsyslog cannot be started, you need to add "--security-opt seccomp:unconfined" to the docker run command line
1. For creating and running a CentOS container:
   * Copy the file dockerfile.centos.cc to ~/sandbox
   * Edit the file dockerfile.centos.cc:
     - Replace __$ROOT_PASSWORD__ by the password of the root user in the container
   * Run this command to build the docker image:
     - __docker build -t "centos:cc" -f ~/sandbox/dockerfile.centos.cc .__
	 - (note the period as the last character)
   * Run this command to run the docker image:
     - __docker run -d -p $SSHD_PORT:22 -v /var/centrify/cloud:/var/centrify/cloud -v /sys/fs/cgroup:/sys/fs/cgroup --cap-add=SYS_ADMIN centos:cc__
	 - replace __$SSHD_PORT__ by the port to be used for sshd service in this container.
	 
## User logins inside docker container
When a Centrify Identity Platform user logins inside a docker container, the home directory is not created inside the docker container.  You can work around this by:
- Share the home directory of the host with the docker container by specifying __-v /home:/home__ in the docker run command
- Modify the pam configuration in the docker container to invoke pam_mkhomedir.so for the PAM session management.

## Notes about Centrify Agent for Linux commands
1. DO NOT run __cunenroll__ inside the docker container.  This may affect the configuration in the host as well as other containers.
1. DO NOT run __creload__ inside the docker container.  It does not change anything in the container or the host.
1. If you unenroll the host and then re-enroll the host to Centrify Identity Platform again, all docker containers __MUST__ be restarted. Otherwise, Centrify Agent for Linux functionalities will not work in the docker container.
1. If you run the command __/usr/share/centrifycc/bin/centrifycc status__ inside the docker container to get the status of the agent, it will show that CentrifyCC is not running.  Actually it shows that the CentrifyCC service is not running inside the container, which is expected. (Ref: 60633)

## Limitations
1. You cannot use Centrify Privileged Access Service to manage passwords for the local accounts inside the docker container. (Ref: 60408)
1. You cannot use the "Use My Account" feature to login to the docker container from the Centrify Portal.   However, "Use My Account" can still be used to login to the host.  (Ref: 59485)
1. Configuration parameters in /etc/centrifycc/centrifycc.conf are used in both the host and docker containers.   If you need to make changes to any configuration parameter, please make the changes in the host and copy the modified /etc/centrifycc/centrifycc.conf to the docker containers. (Ref: 60231)


