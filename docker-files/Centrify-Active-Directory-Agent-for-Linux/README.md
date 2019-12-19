# Enable DirectControl and DirectAudit agents for Linux in a CentOS container

## Setup the docker image

### Build your own docker image
You can just download the docker file [dockerfile.centos.adjoin](dockerfile.centos.adjoin) as a template and modify it for your own requirements.  You need to download the following files to your docker working directory:
* [dockerfile.centos.adjoin](dockerfile.centos.adjoin): docker file for enabling DirectControl agent only
* [dockerfile.centos.adjoinaudit](dockerfile.centos.adjoinaudit): docker file for enabling DirectControl and DirectAudit agents
* [centrify.repo](centrify.repo): information for Centrify repository
* [adjoin_startup.sh](adjoin_startup.sh): start up file
* [centrifydc-adleave.service](centrifydc-adleave.service): service definition for CentrifyDC service.  Used to leave the AD domain when the docker container is stopped.

You also need to prepare a Kerberos keytab file with name **adjoiner.keytab** in your docker working directory.  This keytab file contains the user credential to use for automatic joining the docker container to Active Directory.  See the following section "Prepare the adjoiner.keytab file" on detailed instructions.

* **adjoiner.keytab**: Kerberos keytab file that contains the credential for automatic adjoin

#### Prepare the adjoiner.keytab file

First, make sure the AD user has proper permissions to join the computer to the domain and zone. The domain Administrator  can delegate the required permissions to the user using the Delegation Wizard in Access Manager.  In addition,
* If you need to specify the container to create computer account using **adjoin \-\-container** opton, additional permissions to that container is required.
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

#### Modify the centrify.repo file for you

Before using the docker file, please modify the **centrify.repo** file and replace the $CENTRIFY_REPOSITORY_KEY with your key in the file. The key is required to download packages from Centrify repository. This is an example of a modified **centrify.repo** file:
```
baseurl=https://1234567890ABCDEFGHIJKLMNOPQRS%40centrify:1234567890abcdef1234567890abcdef12345678@repo.centrify.com/rpm-redhat/
```
If you don't have a centrify repo then create an account in the Centrify Support website (http://www.centrify.com/support). Follow the instruction in https://www.centrify.com/support/customer-support-portal/repos to generate the repo key. Use the string before @repo.centrify.com to set up the parameter CENTRIFY_REPO_CREDENTIAL. For example, if the repo key is **1111111122222233333333333333344444555555:777888880000099999991234567890abcdefghij@repo.centrify.com**, set **CENTRIFY_REPO_CREDENIIAL=1111111122222233333333333333344444555555:777888880000099999991234567890abcdefghij**

#### Build arguments for docker build command

There are couple of build arguments that need to be specified in order to build the docker image.  The following table describes all the arguments.

| Argument | Description | Optional | Example | Comments |
| --- | --- | --- | --- | --- |
| DOMAIN | The AD domain to join to | NO | example.com | |
| ADJOINER | The AD user that has proper permissions to join the zone | NO | zoneadm@EXAMPLE.COM | |
| ZONE | The Centrify zone to join to | Yes | default | Use as the default value of environment ZONE |
| TENANT_URL | The tenant URL | Yes | example.my.centrify.com:443 | Use as the default value of environment URL |

#### Build the docker image

Follow these steps to build the CentOS docker image:
1. Create a working directory in your CoreOS host (e.g., ~/sandbox) and make it the current working directory.
1. Download the above four files to the working directory.
1. Modify the **centrify.repo** file and replace $CENTRIFY_REPOSITORY_KEY with your key.
1. Prepare the **adjoiner.keytab** file, which contains the credential for adjoin when the container is being started.
1. Select the docker file to use (**dockerfile.centos.adjoin** or **dockerfile.centos.adjoinaudit**), modify the docker file if needed.
1. Run **docker build** to build the image:
```
docker build -t "centos:adjoin" \
    --build-arg DOMAIN=example.com --build-arg ADJOINER=zoneadm@EXAMPLE.COM -f ./dockerfile.centos.adjoin .
```
```
docker build -t "centos:adjoinaudit" \
    --build-arg DOMAIN=example.com --build-arg ADJOINER=zoneadm@EXAMPLE.COM -f ./dockerfile.centos.adjoinaudit .
```

## Environment variables for docker run command
You can customize your docker container by specifying environment variables using the -e option in the **docker run** command.  The following table describes all the parameters.

| Parameter | Description | Optional | Example | Comments |
| --- | --- | --- | --- | --- |
| ZONE | The Centrify zone to join to | Yes* | default | |
| OU | The OU or container to create the computer account, in DN format | Yes | cn=Computers | |
| NAME | The name of the computer account | Yes | container1 | |
| ENABLE_USE_MY_ACCOUNT | Enable the "Use My Account" feature | Yes* | yes | |
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

Here are the examples of running the **docker run** command:
```
docker run -d -p 2010:22 -v /sys/fs/cgroup:/sys/fs/cgroup --cap-add=SYS_ADMIN \
    --name container1 -e NAME=container1 centos:adjoin
```
```
docker run -d -p 2010:22 -v /sys/fs/cgroup:/sys/fs/cgroup --cap-add=SYS_ADMIN \
    --name container1 -e NAME=container1 \
    -e ENABLE_USE_MY_ACCOUNT=yes -e URL=example.my.centrify.com -e CODE=12345678-ABCD-EFGH-IJKL-12345678ABCD\
    -e ADDRESS=10.11.1.1 -e PORT=2001 -e CONNECTOR=connector1,connector2\
    centos:adjoin
```
Note that you must specify **-d -v /sys/fs/cgroup:/sys/fs/cgroup --cap-add=SYS_ADMIN** in the **docker run** command.

## Enable auditing with DirectAudit
If the docker file **dockerfile.centos.adjoinaudit** is used to build the docker image, the DirectAudit agent will be started automatically when the container starts up. The NSS auditing is enabled by default, it can be disabled with the **ENABLE_NSS_AUDITING** parameter.

Please see more auditing parameters in the above section.

## Setup docker to use multi-factor authentication (MFA)
MFA requires the following setup:
* The computer is granted "Computer Login and Privilege Elevation" administrative rights in Centrify Identity Platform.  One idea is to assign the AD group "Domain Computers" to a Centrify Identity Platform role that was granted such right.
* The IWA root CA certificate must be installed in the docker container.  One idea is to set up the IWA root CA certificate in a Group Policy that applies to the new docker container.

## Stopping the docker image

The docker image always runs **adleave** (and **cunenroll** when Use My Account feature is enabled) itself when it is stopped.  However, the default timeout for the **docker stop** command may be too short to complete the operation.  We recommend to use a longer timeout such as 180 seconds.

An example of the **docker stop** command:
```
docker stop -t 180 container1
```
where *container1* is the name of the docker container.

Note that the docker image automatically runs **adjoin** (based on the parameter settings in the original **docker run** command) when it is restarted.

## Notes

* The docker file is expected to work with the latest Centrify Infrastructure Service release. Problem may arise if a package repository other than the Centrify repository is used.
