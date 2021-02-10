# Enable DirectControl and DirectAudit agents for Linux in a CentOS/Ubuntu container

## Setup the docker image

### Build your own docker image
You can just download the docker file [dockerfile.centos.adjoin](dockerfile.centos.adjoin)/[dockerfile.ubuntu.adjoin](dockerfile.ubuntu.adjoin) as a template and modify it for your own requirements.  You need to download the following files to your docker working directory:
* [dockerfile.centos.adjoin](dockerfile.centos.adjoin): docker file for enabling DirectControl agent only in CentOS container
* [dockerfile.centos.adjoinaudit](dockerfile.centos.adjoinaudit): docker file for enabling DirectControl and DirectAudit agents in CentOS container.
* [dockerfile.ubuntu.adjoin](dockerfile.ubuntu.adjoin): docker file for enabling DirectControl agent only in Ubuntu container
* [dockerfile.ubuntu.adjoininaudit](dockerfile.ubuntu.adjoininaudit): docker file for enabling DirectControl and DirectAudit agents in Ubuntu container.
* [centrify.repo](centrify.repo): information for Centrify repository for a CentOS container
* [centrify.list](centrify.list): information for Centrify repository for a Ubuntu container
* [adjoin_startup.sh](adjoin_startup.sh): start up file for CentOS container
* [adjoin_startup_ubuntu.sh](adjoin_startup_ubuntu.sh): start up file for Ubuntu container
* [centrifydc-adleave.service](centrifydc-adleave.service): service definition for CentrifyDC service.Used to leave the AD domain when the docker container is stopped.
* [centrifycc-unenroll.service](centrifycc-unenroll.service): service definition for CentrifyCC service.  Used to leave the cloud when the docker container is stopped CentOS and Ubuntu container.
* [centrifycc-cenrollagent.service](centrifycc-cenrollagent.service): service definition for CentrifyCC service.  Used to enroll the only Ubuntu based container in the cloud.

You also need to prepare a Kerberos keytab file with name **adjoiner.keytab** in your docker working directory.  This keytab file contains the user credential to use for automatic joining the docker container to Active Directory.  See the following section "Prepare the adjoiner.keytab file" on detailed instructions.

* **adjoiner.keytab**: Kerberos keytab file that contains the credential for automatic adjoin

#### Prepare the adjoiner.keytab file

First, make sure the AD user has proper permissions to join the computer to the domain and zone. The domain Administrator  can delegate the required permissions to the user using the Delegation Wizard in Access Manager.  In addition,
* If you need to specify the container to create computer account using **adjoin \-\-container** option, additional permissions to that container is required.
* If you need to specfiy one or more computer roles for the docker container, the enroller needs to have "write Members" to the AD group that the computer role is associated with.

Make sure the AD user's full name (that shown in the ADUC) is the same as the logon name (aka samAccountName).

Log on one of the \*nix machines that has been joined to the domain as **root**, run **adkeytab** command as below:
```
/usr/sbin/adkeytab --adopt --local --newpassword <current-user-password> --user <admin> \
    --keytab adjoiner.keytab <user>
```

Where:
* `<admin>`: The AD user that has sufficient rights to read the AD `<user>` account object and update the userAccountControl attribute, e.g. Administrator
* `<user>`: The AD user that is used to join the machine to the AD domain, e.g. zoneadm
* `<current-user-password>`: The current password of `<user>`.

You will be prompted to input the `<admin>`'s password in order to proceed.

Note that the **\-\-newpassword** option here does not change the `<user>`'s password. It is only used to create keytab file locally and therefore you should use the existing password in AD.

Once the keytab file is created, you can test the file with the following command:
```
/usr/share/centrifydc/kerberos/bin/kinit -kt adjoiner.keytab -C <user>@<domain>
```
Where:
* `<user>`: The AD user that is used to join the machine to the `<doamin>`, e.g. zoneadm
* `<domain>`: The AD domain in upper case, e.g. EXAMPLE.COM

Then run **klist** to check if the TGT ticket of the AD user is obtained:
```
/usr/share/centrifydc/kerberos/bin/klist
```

If everthing is OK, you can test whether the keytab file can be used to join computer to the zone. Transfer the keytab file to another computer (with Centrify DirectControl installed but not join to any domain yet), logon that computer as **root**, run **kinit** as above, then run **adjoin**:
```
/usr/sbin/adjoin <domain> -z <zone> --force
```

Once the test is passed, the **adjoiner.keytab** file is ready.

#### Modify the centrify.repo file for you if you are working for the CentOS container


Before using the docker file, please modify the **centrify.repo** file and replace the $CENTRIFY_REPOSITORY_KEY for rpm-redhat with your key in the file. The key is required to download packages from Centrify repository. This is an example of a modified **centrify.repo** file:
```
baseurl=https://cloudrepo.centrify.com/0123456789aAbBcC/rpm-redhat/rpm/any-distro/any-version/$basearch/
```
If you don't have a centrify repo then create an account in the Centrify Support website (http://www.centrify.com/support). Follow the instruction in https://centrify.force.com/support/CentrifyRepo to generate the repo key for rpm-redhat. Use the string <URLtoken> to set up the parameter CENTRIFY_REPOSITORY_KEY. For example, if the <URLtoken> for rpm-redhat is **0123456789aAbBcC**, set **CENTRIFY_REPOSITORY_KEY=0123456789aAbBcC**

#### Modify the centrify.list file for you if you are working for the Ubuntu container

Before using the docker file, please modify the **centrify.list** file and replace the $CENTRIFY_REPOSITORY_KEY for deb with your key in the file. The key is required to download packages from Centrify repository. This is an example of a modified **centrify.list** file:
```
deb https://cloudrepo.centrify.com/0123456789aAbBcC/deb/deb/ubuntu any-version main
```
If you don't have a centrify repo then create an account in the Centrify Support website (http://www.centrify.com/support). Follow the instruction in https://centrify.force.com/support/CentrifyRepo to generate the repo key for deb. Use the string <URLtoken> to set up the parameter CENTRIFY_REPOSITORY_KEY. For example, if the <URLtoken> for deb is **0123456789aAbBcC**, set **CENTRIFY_REPOSITORY_KEY=0123456789aAbBcC**

#### Build arguments for docker build command

There are couple of build arguments that need to be specified in order to build the docker image.  The following table describes all the arguments.

| Argument | Description | Optional | Example | Comments |
| --- | --- | --- | --- | --- |
| DOMAIN | The AD domain to join to | NO | example.com | |
| ADJOINER | The AD user that has proper permissions to join the zone | NO | zoneadm@EXAMPLE.COM | |
| ZONE | The Centrify zone to join to | Yes | default | Use as the default value of environment ZONE |
| TENANT_URL | The tenant URL | Yes | example.my.centrify.com:443 | Use as the default value of environment URL |
| ENABLE_USE_MY_ACCOUNT | Enable/Disable UMA(Use My Account) feature | Yes | Yes | Use as the default value for enabling/disabling the UMA feature |

#### Build the docker image for CentOS container

Follow these steps to build the CentOS docker image:
1. Create a working directory in your CoreOS host (e.g., ~/sandbox) and make it the current working directory.
1. Download the above four files for CentOS to the working directory.
1. Modify the **centrify.repo** file and replace $CENTRIFY_REPOSITORY_KEY with your key.
1. Prepare the **adjoiner.keytab** file, which contains the credential for adjoin when the container is being started.
1. Select the docker file to use (**dockerfile.centos.adjoin** or **dockerfile.centos.adjoinaudit**), modify the docker file if needed.
1. Run **docker build** to build the image:
```
docker build -t "centos:adjoin" \
    --build-arg DOMAIN=example.com --build-arg ADJOINER=zoneadm@EXAMPLE.COM --build-arg ENABLE_USE_MY_ACCOUNT=Yes -f ./dockerfile.centos.adjoin .
```
```
docker build -t "centos:adjoinaudit" \
    --build-arg DOMAIN=example.com --build-arg ADJOINER=zoneadm@EXAMPLE.COM --build-arg ENABLE_USE_MY_ACCOUNT=Yes -f ./dockerfile.centos.adjoinaudit .
```

#### Build the docker image for Ubuntu container

Follow these steps to build the Ubuntu docker image:
1. Create a working directory in your CoreOS host (e.g., ~/sandbox) and make it the current working directory.
1. Download the above files for ubuntu to the working directory.
1. Modify the **centrify.list** file and replace $CENTRIFY_REPOSITORY_KEY with your key.
1. Prepare the **adjoiner.keytab** file, which contains the credential for adjoin when the container is being started.
1. Select the docker file to use (**dockerfile.ubuntu.adjoin** or **dockerfile.ubuntu.adjoininaudit**), modify the docker file if needed.
1. Run **docker build** to build the image:
```
docker build -t "ubuntu:adjoin" \
    --build-arg DOMAIN=example.com --build-arg ADJOINER=zoneadm@EXAMPLE.COM --build-arg ENABLE_USE_MY_ACCOUNT=Yes -f ./dockerfile.ubuntu.adjoin .
```
```
docker build -t "ubuntu:adjoininaudit" \
    --build-arg DOMAIN=example.com --build-arg ADJOINER=zoneadm@EXAMPLE.COM --build-arg ENABLE_USE_MY_ACCOUNT=Yes -f ./dockerfile.ubuntu.adjoininaudit .
```


## Environment variables for docker run command
You can customize your docker container by specifying environment variables using the -e option in the **docker run** command.  The following table describes all the parameters.

| Parameter | Description | Optional | Example | Comments |
| --- | --- | --- | --- | --- |
| ZONE | The Centrify zone to join to | Yes* | default | |
| OU | The OU or container to create the computer account, in DN format | Yes | cn=Computers | |
| NAME | The name of the computer account | Yes | container1 | |
| URL | The tenant URL | Yes* | example.my.centrify.com | If ENABLE_USE_MY_ACCOUNT is yes, this parameter must be specified. |
| ADJOIN_OPTION | Optional parameters for adjoin command | Yes | -i | adjoin will not preload cache with -i option. |
| COMPUTER_ROLES | Computer roles that are effective on the docker container, specified as a comma separate list. | Yes | docker_containers |
| ENABLE_NSS_AUDITING | Enable or disable NSS auditing | Yes | no | This parameter only take effect if DirectAudit is installed in the docker image. By default, NSS auditing is enabled. You can disable NSS auditing with the value 'no' or 'false'.  |
| INSTALLATION | Specify the audit installation | Yes | MyInstallation | This parameter only take effect if DirectAudit is installed in the docker image. If this parameter is not specified, "DefaultInstallation" will be used. Note that group policy can override this parameter. |
| ROOT_PASSWORD | Initial root password. | Yes | | By default, this parameter should not be used and randomized password will be generated.   Set this parameter only for debugging purpose as it is easy for someone to monitor and access this information. |
| CODE | Enrollment Code | Yes | *a long string* | | If enabling Use My Account feature then this parameter must be specified |
| ADDRESS | IP address of the container host. | Yes | *10.11.1.1* | You must specify this if you want users to login using the Admin Portal.  This IP address must be reachable from the Centrify connector specified in the **CONNECTOR** parameter. If ENABLE_USE_MY_ACCOUNT is yes, this parameter must be specified. |
| PORT | Port number used by SSH daemon | Yes | 2001 | Note: If you specify the ADDRESS parameter, you should specify a different value for this parameter since the docker container shares the same IP address and port as the container host. If ENABLE_USE_MY_ACCOUNT is yes, this parameter must be specified. |
| CONNECTOR | The Centrify Connector to use when accessing this docker container using the Admin Portal. | YES | **connector1,connector2** | Default: any Centrify Connector will be used.  If you need to specify multiple connectors, separate them by commas. |

\* The parameter is optional only if the default value has been specified in the build argument at build time.

Here are the examples of running the **docker run** command for CentOS container:
```
docker run -d -p 2010:22 -v /sys/fs/cgroup:/sys/fs/cgroup --cap-add=SYS_ADMIN \
    --name container1 -e NAME=container1 centos:adjoin
```
```
docker run -d -p 2010:22 -v /sys/fs/cgroup:/sys/fs/cgroup --cap-add=SYS_ADMIN \
    --name container1 -e NAME=container1 \
    -e URL=example.my.centrify.com -e CODE=12345678-ABCD-EFGH-IJKL-12345678ABCD\
    -e ADDRESS=10.11.1.1 -e PORT=2001 -e CONNECTOR=connector1,connector2\
    centos:adjoin
```

Here are the examples of running the **docker run** command for Ubuntu container:
```
docker run -d -p 2010:22 --privileged -v /sys/fs/cgroup:/sys/fs/cgroup --cap-add=SYS_ADMIN \
    --name container1 -e NAME=container1 ubuntu:adjoin
```
```
docker run -d -p 2010:22 --privileged -v /sys/fs/cgroup:/sys/fs/cgroup --cap-add=SYS_ADMIN \
    --name container1 -e NAME=container1 \
    -e URL=example.my.centrify.com -e CODE=12345678-ABCD-EFGH-IJKL-12345678ABCD\
    -e ADDRESS=10.11.1.1 -e PORT=2001 -e CONNECTOR=connector1,connector2\
    ubuntu:adjoin
```

Note that you must specify **-d -v /sys/fs/cgroup:/sys/fs/cgroup --cap-add=SYS_ADMIN** in the **docker run** command for both CentOS and Ubuntu container.


## Enable auditing with DirectAudit for CentOS container
If the docker file **dockerfile.centos.adjoinaudit** is used to build the docker image, the DirectAudit agent will be started automatically when the container starts up. The NSS auditing is enabled by default, it can be disabled with the **ENABLE_NSS_AUDITING** parameter.

## Enable auditing with DirectAudit for Ubuntu container
If the docker file **dockerfile.ubuntu.adjoininaudit** is used to build the docker image, the DirectAudit agent will be started automatically when the container starts up. The NSS auditing is enabled by default, it can be disabled with the **ENABLE_NSS_AUDITING** parameter.

Please see more auditing parameters in the above section.

## Setup docker to use multi-factor authentication (MFA)
MFA requires the following setup:
* The computer is granted "Computer Login and Privilege Elevation" administrative rights in Centrify Identity Platform.  One idea is to assign the AD group "Domain Computers" to a Centrify Identity Platform role that was granted such right.
* The IWA root CA certificate must be installed in the docker container.  One idea is to set up the IWA root CA certificate in a Group Policy that applies to the new docker container.

## Stopping the docker image for both Ubuntu and CentOS container.

The docker image always runs **adleave** (and **cunenroll** when Use My Account feature is enabled) itself when it is stopped.  However, the default timeout for the **docker stop** command may be too short to complete the operation.  We recommend to use a longer timeout such as 180 seconds.

An example of the **docker stop** command:
```
docker stop -t 180 container1
```
where *container1* is the name of the docker container.

Note that the docker image automatically runs **adjoin** (based on the parameter settings in the original **docker run** command) when it is restarted.

## Notes

* The docker file is expected to work with the latest Centrify Infrastructure Service release. Problem may arise if a package repository other than the Centrify repository is used.
