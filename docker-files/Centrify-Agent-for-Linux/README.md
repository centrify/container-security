# Enable Centrify Agent for Linux in a CentOS container

## Setup the docker image
<!--
### Use pre-built docker image
You can just download the pre-built docker image from docker hub and follows these steps to set up the docker image:
* gunzip centos_base.tar.gz
* docker load --input centos_base.tar

A random password is generated for root when the docker image is run.  You can override it by specifying *-e ROOT_PASSWORD=\<root_password\>* in the docker command.

-->
### Build your own docker image
You can use the docker file [dockerfile.centos.cjoin](dockerfile.centos.cjoin) as a template and modify it for your own requirements.  You need to download the following files to your docker working directory:
* [dockerfile.centos.cjoin](dockerfile.centos.cjoin): docker file
* [cjoin_startup.sh](cjoin_startup.sh): start up file
* [centrifycc-unenroll.service](centrifycc-unenroll.service): service definition for CentrifyCC service.  Used for unenroll the machine when the docker container is stopped.

Follow these steps to build the CentOS docker image:
1. Create a working directory in your CoreOS host (e.g., ~/sandbox) and make it the current working directory.
1. Download the above three files to the working directory.
1. Specify the following docker build command to build the docker image:
```
docker build -t "centos:cjoin" -f ./dockerfile.centos.cjoin .
```
  If you want to specify the tenant URL for all the docker containers in the docker image, you can use this docker command:
```
docker build -t "centos:cjoin" -f ./dockerfile.centos.cjoin --build-arg \
  TENANT_URL=<URL_of_Centrify_Identity_Platform> .
```
Notes:
  * *URL_of_Centrify_Identity_Platform* is the URL for your Centrify Identity Platform.
  * Specification of TENANT_URL is optional.  If you do not specify it in the docker build command, you need to specify it as *-e URL=\<URL_of_Centrify_Identity_Platform\>* in the docker run command.
  * This command builds a docker image named **centos:cjoin**.  You can change the image name if you want.

## Brief overview of the docker file
The docker file does the followings:
1. Update yum repository information.
1. Install Openssh client and server.
1. Install vim.
1. Modify SSHD configuration files:
    * allow root login
    * allow challenge/response during login
1. Update PAM configuration file to make pam_loginuid optional for sshd login.  This is required to workaround a docker limitation.
1. Install systemd.  This is required to run both sshd and Centrify Agent for Linux service.
1. Download and install the latest version of Centrify Agent for Linux.
1. Create a service to unenroll the agent when the container is stopped.
1. Set SELinux context to permissive.
1. Run cjoin_startup.sh as the startup command.

## Brief overview of startup command
The startup command does the followings:
1. Sets up the command line arguments for the cenroll command.
1. If **VAULT_ROOT_PASSWORD** is true, create a shell script that is run after the agent is successfully enrolled. The shell script also generates a random password for root.
1. Otherwise, set the password to **ROOT_PASSWORD** (if it is specified), or a randomly generated password.
1. Enroll the agent.
1. Run /usr/sbin/init as the last command.

Note that there should be NO NEED for you to modify this file.

## Environment variables for docker run command
You can customize your docker container by specifying environment variables using the -e option in the docker run command.  The following table describes all the parameters.

| Parameter | Description | Optional | Example | Comments |
| --- | --- | --- | --- | --- |
| CODE | Enrollment code | NO | *a long string* | |
| LOGIN_ROLE | The roles who members can login | NO | role1,role2 | separate roles by comma |
| URL | URL of Centrify Identity Platform to enroll to. | Yes | aaa0001.centrify.com | You must specify this if it is NOT specified when the docker image is built. | 
| NAME | Name registered as the system name for the docker container. | Yes | **MyContainer** | Default: the docker instance ID is used |
| ADDRESS | IP address of the container host. | Yes | *10.11.1.1* | You must specify this if you want users to login using the Admin Portal.  This IP address must be reachable from the Centrify connector specified in the **CONNECTOR** parameter. |
| PORT | Port number used by SSH daemon | Yes | 2001 | Default: 22.  Note: If you specify the ADDRESS parameter, you should specify a different value for this parameter since the docker container shares the same IP address as the container host. |
| CONNECTOR | The Centrify Connector to use when accessing this docker container using the Admin Portal. | YES | **connector1,connector2** | Default: any Centrify Connector will be used.  If you need to specify multiple connectors, separate them by commas. |
| ENABLE_USE_MY_ACCOUNT | Set to yes if you want to enable the "Use My Account" feature for the system. | Yes | **yes** | The startup command automatically downloads the ssh public key and make other modifications on the system. |
| VAULT_ROOT_PASSWD | Set to yes if you want to vault the root password in Centrify Identify Platform after it is enrolled successfully.   | Yes | **yes** | A random password will be generated and vaulted for root. |
| MANAGE_ROOT_PASSWD | Set to yes if you want Centrify Identity Platform to manage the root password. | Yes | **yes** | Only relevant if **VAULT_ROOT_PASSWD** is yes. |
| LOGIN_AS_ROOT_ROLES | Specify the roles that can login to the system as root.  Such users must use Admin Portal to login and/or checkout the root passowrd. | Yes | **role1,role2** | Only relevant if **VAULT_ROOT_PASSWD** is yes.  If you need to specify multiple roles, separate them by commas. |
| ROOT_PASSWORD | Specify the root password. | Yes | **my_password** | Relevant only if **VAULT_ROOT_PASSWD** is not yes.   If not specified, a random password will be generated for root. |

Here is an example of a docker run command:
```
docker run -d -p 2010:22 -v /sys/fs/cgroup:/sys/fs/cgroup --cap-add=SYS_ADMIN --name container1 \
  -e CODE=12345678-ABCD-EFGH-IJKL-12345678ABCD -e PORT=2010 \
  -e ADDRESS=10.1.1.1 -e CONNECTOR=connector1,connector2, \
  -e NAME=container1 -e LOGIN_ROLE=role1,rol2 centos:cjoin
```
Note that you must specify **-d -v /sys/fs/cgroup:/sys/fs/cgroup --cap-add=SYS_ADMIN** in the docker run command.

## Stopping the docker image

The docker image always unenrolls itself when it is stopped.  However, the default timeout for the docker stop command may be too short to complete the operation.  We recommend to use a longer timeout such as 180 seconds.

An example of the docker stop command
```
docker stop -t 180 container1
```
where *container1* is the name of the docker container.

Note that the docker image automatically re-enrolls to Centrify Identify Platform (based on the parameter settings in the original docker run command) when it is restarted.
