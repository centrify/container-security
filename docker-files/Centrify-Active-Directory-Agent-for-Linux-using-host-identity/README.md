# Enable DirectControl and DirectAudit functionalities inside Docker Container

## Introduction
Centrify starts support CoreOS platform in Centrify Infrastructure Services 2017.3.  This README describes how one can enable DirectControl and DirectAudit functionalities inside docker containers after the host has installed and enabled such functionalities.  All the docker containers share the same identity as the host;  there is no need for individual container to join to Active Directory and there is only one computer from the Active Directory perspective.

## Files for docker container support
* [centrify.repo](centrify.repo): information for Centrify repository.
* [dockerfile.centos.dc](dockerfile.centos.dc): docker file for enabling DirectControl in Centos docker image.
* [dockerfile.centos.dcda](dockerfile.centos.dcda): docker file for enabling DirectControl and DirectAudit in Centos docker image.
* [dockerfile.ubuntu.dc](dockerfile.ubuntu.dc): docker file for enabling DirectControl in Ubuntu docker image.
* [dockerfile.ubuntu.dcda](dockerfile.ubuntu.dcda): docker file for enabling DirectControl and DirectAudit in Ubuntu docker image.

## IMPORTANT NOTES ABOUT UPGRADE
1. Centrify requires the host and docker container to run with the same version of Centrify Infrastructure Services.   This is the recommended steps for upgrades:
   1. Stop all the docker containers that use the host identity.
   1. Upgrade Centrify Infrastructure Services in host.
   1. Rebuild all the docker containers to install the latest Centrify Infrastructure Services agent.
   1. Deploy the new docker container.  
   1. Remove all the docker containers that are stopped in step 1.
1. Before you upgrade DirectAudit in the host and any docker container, you need to disable auditing in the host and all the containers. (Ref: 46220)

## Enable DirectControl functionality inside docker container
Follow these steps to enable DirectControl functionality inside docker containers:
1. Install DirectControl in CoreOS host.
1. Join the CoreOS host to zone.
1. Login to an account that can run **docker** commands and can run **sudo** commands as root (e.g., core).
1. Run the following commands set up a sandbox environment:
   ```
   mkdir ~/sandbox
   cd ~/sandbox
   sudo tar cvf docker.copy.tar /etc/centrifydc /etc/krb5*  
   ```
1. For creating and running a Ubuntu container:
   1. Copy the attached file **dockerfile.ubuntu.dc** to ~/sandbox
   1. Edit the file **dockerfile.ubuntu.dc**:
      1. Replace $CENTRIFY_REPOSITORY_KEY by your Centrify support repository credential.
      1. Replace $ROOT_PASSWORD by the password of the root user in the container.
   1. Run this command to build the docker image:
      ```
      docker build -t "ubuntu:dc" -f ~/sandbox/dockerfile.ubuntu.dc .  (note the period as the last parameter)
      ```
   1. Run this command to run the docker image:
      ```
      docker run -d -p $SSHD_PORT:22 -v /var/centrifydc:/var/centrifydc -v /sys/fs/cgroup:/sys/fs/cgroup --cap-add=SYS_ADMIN ubuntu:dc
      ```
      Replace $SSHD_PORT by the port to be used for sshd service for this container.
1. For creating and running a CentOS container:
   1. Copy the attached files **dockerfile.centos.dc** and **centrify.repo** to ~/sandbox
   1. Edit the file **centrify.repo** and replace $CENTRIFY_REPOSITORY_KEY by your Centrify support repository credential.
   1. Edit the file **dockerfile.centos.dc** to replace $ROOT_PASSWORD by the password of the root user in the container.
   1. Run this command to build the docker image:
      ```
      docker build -t "centos:dc" -f ~/sandbox/dockerfile.centos.dc .  (note the period as the last parameter)
      ```
   1. Run this command to run the docker image:
      ```
      docker run -d -p $SSHD_PORT:22 -v /var/centrifydc:/var/centrifydc -v /sys/fs/cgroup:/sys/fs/cgroup --cap-add=SYS_ADMIN centos:dc
      ```
      Replace $SSHD_PORT by the port to be used for sshd service for this container.

## Enable both DirectControl and DirectAudit functionalities inside docker container
Follow these steps to enable both DirectControl and DirectAudit functionalities inside docker container:
1. Install DirectControl and DirectAudit in CoreOS host
1. Join the CoreOS host to zone.
1. Login to an account that can run **docker** commands and can run **sudo** commands as root (e.g., core).
1. Run the following commands set up a sandbox environment:
   ```
   mkdir ~/sandbox
   cd ~/sandbox
   sudo tar -cvf docker.copy.tar /etc/centrifydc /etc/centrifyda /etc/krb5*  
   ```
1. For creating and running a Ubuntu container:
   1. Copy the attached file **dockerfile.ubuntu.dcda** to ~/sandbox
   1. Edit the file **dockerfile.ubuntu.dcda**:
      1. Replace $CENTRIFY_REPOSITORY_KEY by your Centrify support repository credential.
      1. Replace $ROOT_PASSWORD by the password intended for root in the container.
   1. Run this command to build the docker image:
      ```
      docker build -t "ubuntu:da" -f ~/sandbox/dockerfile.ubuntu.dcda .   (note the period as the last parameter)
      ```
   1. Run this command to run the docker image:
      ```
      docker run -d -p $SSHD_PORT:22 -v /var/centrifydc:/var/centrifydc -v /var/centrifyda:/var/centrifyda -v /sys/fs/cgroup:/sys/fs/cgroup --cap-add=SYS_ADMIN ubuntu:da
      ```
      Replace $SSHD_PORT by the port to be used for sshd service for this container.
1. For creating and running a CentOS container:
   1. Copy the attached files **dockerfile.centos.dcda** and **centrify.repo** to ~/sandbox
   1. Edit the file centrify.repo to replace $CENTRIFY_REPOSITORY_KEY by your Centrify support repository credential.
   1. Edit the file dockerfile.centos.dcda to replace $ROOT_PASSWORD by the password intended for root in the container.
   1. Run this command to build the docker image:
      ```
      docker build -t "centos:da" -f ~/sandbox/dockerfile.centos.dcda .  (note the period as the last parameter)
      ```
   1. Run this command to run the docker image:
      ```
      docker run -d -p $SSHD_PORT:22 -v /var/centrifydc:/var/centrifydc -v /var/centrifyda:/var/centrifyda -v /sys/fs/cgroup:/sys/fs/cgroup --cap-add=SYS_ADMIN centos:da
      ```
      Replace $SSHD_PORT by the port to be used for sshd service for this container.

## Access kerberos credential cache and/or keytab file of host machine account from inside docker container
The docker containers share the identity (and machine account) of the host.   The kerberos credential cache and keytab file are created and stored in the host; and are not available to the docker containers by default.  If a kerberos application running inside the docker container needs to use the kerberos credential cache and keytab files of the host machine account,  Centrify recommends the following steps:

1. By default, the host machine account kerberos credential cache and keytab files are stored in /etc, and it is not good practice to share this directory with the containers.  So, we need to use a separate directory to store and share such files.
1. Set up in CoreOS host:
   1. Create a directory /etc/centrify_krb5 for storing the host machine's kerberos credential cache and keytab file
   1. Set up the following configuration parameters in centrifydc.conf:
      ```
      adclient.krb5.ccache.file: /etc/centrify_krb5/krb5.ccache
      adclient.krb5.keytab: /etc/centrify_krb5/krb5.keytab
      ```
      Note that these two parameters are effective when the host is joined to Active Directory.   Please set up these two parameters before you join the CoreOS host to Active Directory.
   1. If there are any host applications/scripts look for machine kerberos credential cache and keytab files in /etc, create the following symlinks:
      ```
      ln -s /etc/centrify_krb5/krb5.keytab  /etc/krb5.keytab
      ln -s /etc/centrify_krb5/krb5.ccache /etc/krb5.ccache
      ```
1. For the docker images:
   1. In the **docker run** command, specify **-v /etc/centrify_krb5:/etc/centrify_krb5** to set up the bind mount mapping
   1. Point the kerberos applications/scripts to use krb5.keytab/krb5.ccache in /etc/centrify_krb5 (intead of /etc)
   
Note that you probably need to do this if you run any kerberos server applications (e.g., sshd) in the docker container.

Please contact Centrify Technical Support if the docker applications cannot use alternate locations for the kerberos credential cache and keytab files.

## Access kerberos credential cache file of Active Directory users from inside docker container
After an Active Directory user logins to a docker container, the kerberos credential cache file (krb5cc_<uid>, or krb5cc_cdc<unique_number>_<uid>) is created in /tmp in the CoreOS host, not in /tmp in the docker container.   

A new configuration parameter is introduced in Centrify Infrastructure Services 18.8 to configure an alternate directory for the kerberos credential cache files. (Ref: 44846)  You need to do the followings if you want your docker applications to access the kerberos credential cache after login:
   1. Add these configuration parameter to /etc/centrifydc/centrifydc.conf (for both host and docker container)
      1. adclient.krb5.ccache.dir:  /var/centrifydc/ccache </br></br>
         You need to create a directory that is accessible by the containers via volume mapping.  In addition, you can protect this directory by making sure that:
         * it is not a symbolic link
         * it is owned by root
         * it is read/writable by world and has sticky bit
         
      1. adclient.krb5.ccache.dir.secure.usable.check: true</br></br>
         This will verify the credential cache directory are set up in a secure manner.  If the credential cache directory does not pass the security test, /tmp will be used as the credential cache directory.
         
   1. Make sure that the directory is shared with the docker containers using volume mapping in the docker run command.
      
If you are using earlier versions of Centrify Infrastructure Services, the workaround for now is to for the docker container to mount the /tmp directory using **-v /tmp:/tmp** in the **docker run** command.

## Active Directory user logins inside docker container
When Active Directory user logins inside a docker container, the home directory is not created inside the docker container.  You can work around this by:
* Share the home directory of the host with the docker container by specifying **-v /home:/home** in the **docker run** command.
* Modify the pam configuration in the docker container to invoke **pam_mkhomedir.so** for the PAM session management.

Note that the kerberos credential cache (krb5cc_<uid>, or krb5cc_<unique_id>_<uid>) is created in /tmp in the CoreOS host.

## KCM support
KCM is supported in CoreOS, and Active Directory users can login to docker containers.  In Centrify Infrastructure Services 2018 or earlier, the kerberos credential cache is not available to kerberos applications running inside the docker container.  

A new configuration parameter is introduced in Centrify Infrastructure Service 18.8 to configure the location of the socket that is used by the KCM server running in the CoreOS host.  If you need to run kerberos applications inside the docker container, you need to:
1. Set this parameter in /etc/centrifydc/centrifydc.conf in both the host and containers:
   * krb5.conf.kcm.socket.path: /var/centrifydc/.centrify-kcm-socket </br></br>
   Note that the path satisfies all these requirements:
      * The parent directory exists.
      * The parent directory is not a symbolic link.
      * The parent directory is writable by root only
      * The socket path does not exist, or it is NOT a directory if it exists
1. Make sure that the parent directory is available to the docker containers via volume mapping.
1. Do not create the socket in /var/run.

If you change the parameter krb5.cache.type in /etc/centrifydc/centrifydc.conf in the host, you also need to copy the file /etc/krb5.conf from the host to all the containers.

## Notes about DirectControl utilities
* Do not run **adleave** inside any docker container.  This may affect the configuration in the host.
* If you run **adleave** from the host and then joins to Active Directory again using **adjoin**, all docker
containers MUST be restarted.  Otherwise, DirectControl and DirectAudit functionalities will not work in the docker containers.
* **adreload** should not be run in the docker container.  It does not change anything in the container or the CoreOS host but generates an audit trail event in the docker syslog.
* If **addebug** is enabled in a docker container, all the debug messages are sent to the host, and cannot be found in the docker container itself.
* Instead of copying a snapshot of /etc/centrifydc and /etc/centrifyda to the docker containers, you can also share these directories with the docker containers by using the **-v** option in the **docker run** command.   If you decide to do this, running **addebug on/off** (and **dadebug on/off**) on the host will enable/disable debug messages for all the containers.  
* **adcdiag** fails in CNTRCFG test even though multi-factor authentication (MFA) works.  The reason is that **adcdiag** tries to establish a HTTPS connection to the Centrify Connector but the IWA root certificate is not set up in the container.  To workaround this issue, you can add **-v /var/centrify/net/certs:/var/centrify/net/certs** in the docker run command to workaround this issue. (Ref: 44920)
* If you run **/usr/share/centrifydc/bin/centrifydc status** in the container, it will show that "Centrify DirectControl is not running." Note that the DirectControl daemon (adclient) is not running in the container so this is expected. (Ref: 45751)
* The files /etc/centrifydc/uid.ignore and /etc/centrifydc/gid.ignore are generated by adclient running in the host.  However, the host (especially in CoreOS and RedHat Atomic) has a smaller number of local users and groups as compared to the OS running in the docker containers.  For better NSS performance, Centrify recommends you to review and modify such files in the docker container to make sure that the appropriate UIDs and GIDs are included. (Ref: 46555)

## Notes about DirectAudit support inside docker container
* Command line auditing can be supported in a docker.  However, it is not recommended.   One issue is that once you enable command auditing in a container, running **dainfo** in the host OS or any container shows that the command is enabled for auditing in all container and the host OS.  However, this information is not correct.    Command auditing is not supported in CoreOS and only works in containers where it is enabled.
* Running **dacontrol -e/dacontrol -d** in the CoreOS host only enables/disables session auditing in the host.  There is no effect in the docker containers.   If you want to enable/disable session auditing in individual container, run **dacontrol -e/dacontrol -d** in  the container itself.  By default, session auditing is automatically enabled in the docker container.
* If you run **/usr/share/centrifydc/bin/centrifyda status** in the container, it will show that "Centrify DirectAudit is not running." Note that the DirectAudit daemon (dad) is not running in the container so this is expected. (Ref: 45750)
* Local users inside the container by default.   If you want them to be audited, you need to add them to the file /etc/centrifydc/user.ignore inside the container.  Also, you need to add the UID of such users to the file /etc/centrifydc/uid.ignore inside the container.  Moreover, if the same user does not exist in the host, Audit Analyzer will not be able to show the correct user name, and it will show the user as <UID_nnnn> (where nnnn is the UID of the user). (Ref: 46555, 46793)

## Features that are not supported in docker containers
The following features are not currently support in the docker containers:
* DirectAudit Advanced Monitoring
* FIPS
* NIS
* Group policies
* Installation using Deployment Manager


## Bugs fixed related to docker files in Centrify Infrastructure Services Release 18.8
* Running **dainfo** in the container no longer shows the error message "Unable to send lrpc2 message: 406 (Socket error)".  (Ref: 44841)
* Running **dainfo** in the container now shows the correct session auditing status of the container. (Ref: 46148, 44885)
* If auditing is required for a user in a container, you must enable session auditing in the container.  It is not required that session auditing be enabled in the host.  (Ref: 46183)
* The MFA diagnostics tool **adcdiag** is now supported inside the docker container.  However, please make sure that the followings are done first as a pre-requisite:
   * the directory /var/centrify/net/certs must be shared with the containers. (Ref: 44920)
   * set up the container to access the kerberos credential cache and keytab file of the host machine account. See [section above](#access-kerberos-credential-cache-andor-keytab-file-of-host-machine-account-from-inside-docker-container) on how to do this.
