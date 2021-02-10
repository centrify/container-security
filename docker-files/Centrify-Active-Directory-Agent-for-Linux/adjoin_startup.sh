#! /bin/bash
#
echo "domain:" $DOMAIN
echo "user to join:" $ADJOINER
echo "zone:" $ZONE 
echo "container:" $OU
echo "host name to use:" $NAME

# setup value for NSS auditing
echo "NSS auditing:" $ENABLE_NSS_AUDITING
NSSAuditing='Y'

if [ "$ENABLE_NSS_AUDITING" != "" ] ; then
   NSSAuditing=${ENABLE_NSS_AUDITING::1}
fi

# setup value for UseMyAccount
echo "ENABLE_USE_MY_ACCOUNT: $ENABLE_USE_MY_ACCOUNT" 

if [ "$ENABLE_USE_MY_ACCOUNT" = "Yes" ]  || [ "$ENABLE_USE_MY_ACCOUNT" = "yes" ] || [ "$ENABLE_USE_MY_ACCOUNT" = "True" ] || [ "$ENABLE_USE_MY_ACCOUNT" = "true" ]; then
    UseMyAccount="yes" 
fi

echo "current tenant URL: " $URL
echo "UseMyAccount: $UseMyAccount" 
echo "Enrollment Code: " $CODE
echo "IP address to use:" $ADDRESS
echo "current setting for PORT:" $PORT
echo "connectors setting: " $CONNECTOR

# check required parameters

if [ "$DOMAIN" = "" ]; then
    echo "No DOMAIN specified."
    exec /usr/sbin/init
fi

if [ "$ADJOINER" = "" ]; then
    echo "No ADJOINER specified."
    exec /usr/sbin/init
fi

if [ "$ZONE" = "" ]; then
    echo "No ZONE specified."
    exec /usr/sbin/init
fi

if [[ "$UseMyAccount" == "yes" ]] ; then
    if [ "$URL" = "" ]; then
        echo "UseMyAccount is enabled but tenant URL is not specified."
        exec /usr/sbin/init
    fi
    if [ "$CODE" = "" ]; then
        echo "UseMyAccount is enabled but Enrollment code is not specified."
        exec /usr/sbin/init
    fi
    if [ "$ADDRESS" = "" ]; then
        echo "UseMyAccount is enabled but IP Address of host is not specified."
        exec /usr/sbin/init
    fi
    if [ "$PORT" = "" ]; then
        echo "UseMyAccount is enabled but External Port of host is not specified."
        exec /usr/sbin/init
    fi
    if [ "$CONNECTOR" = "" ]; then
        echo "if UseMyAccount is enabled and an appropriate Connector is not specified, it may fail."
    fi
fi

# touch all ignore files to set link count to 1

touch /etc/centrifydc/*.ignore

# set up command line parameters

CMDPARAM=()

if [ "$OU" != "" ]; then
    CMDPARAM=("${CMDPARAM[@]}" "--container" "$OU")
fi

if [ "$NAME" != "" ]; then
    CMDPARAM=("${CMDPARAM[@]}" "--name" "$NAME")
fi

if [ "$COMPUTER_ROLES" != "" ] ; then
    # convert the string into an array for set up roles
    IFS=","
    for computer_role in $COMPUTER_ROLES
    do 
      CMDPARAM=("${CMDPARAM[@]}" "-R" "$computer_role")
    done
fi
    
if [ "$ADJOIN_OPTION" != "" ] ; then
    # convert the string into an array for passing into adjoin
    IFS=' ' read -a tempoption <<< "${ADJOIN_OPTION}"
    CMDPARAM=("${CMDPARAM[@]}" "${tempoption[@]}")
fi

# setup for "Use My Account" feature

if [[ "$UseMyAccount" == "yes" ]] ; then

    # modifying the SSHD configuration file for Centrify Client
    /usr/share/centrifydc/bin/curl -o /etc/ssh/centrify_tenant_ca.pub https://$URL/servermanage/getmastersshkey 
    if [ ! -f /etc/ssh/sshd_config.bak ]; then
        cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
    fi
    echo "TrustedUserCAKeys /etc/ssh/centrify_tenant_ca.pub" >> /etc/ssh/sshd_config
    echo "AuthorizedPrincipalsCommand /usr/bin/adquery user -P %u" >> /etc/ssh/sshd_config
    echo "AuthorizedPrincipalsCommandUser root" >> /etc/ssh/sshd_config

fi

# setting and obtaining the credential to join the system with AD
(
    echo "`date`: ready to join "
    echo " parameters: [${CMDPARAM[@]}]"
    set -e

    # obtain credential to join
    echo "obtaining credential ..."
    mv /etc/krb5.conf /etc/krb5.conf.bak || true
    /usr/share/centrifydc/kerberos/bin/kinit -kt \
        /etc/centrifydc/adjoiner.keytab -C "$ADJOINER"
    
    # leave the system from the domain if joined
    /usr/sbin/adleave -r && sleep 3 || true

    # join system to AD
    #
    # the adjoin option -I requires Release 18.11 or later.
    #
    echo "joining the system to AD ..."
    RC=0
    /usr/sbin/adjoin -V -I $DOMAIN -z $ZONE "${CMDPARAM[@]}" --force || RC=$?
    if [ $RC -eq 0 ]; then
        # enable the service so that it will be started by systemd later on
        echo "enabling adclient service"
        systemctl enable centrifydc.service
    else
        echo "adjoin failed."
    fi

) 2>&1 | tee -a /var/centrify/adjoin.log

if [ -x /usr/sbin/dad ]; then
    (
        echo "Installation name for Direct Auditing: " $INSTALLATION
        echo "`date`: enable auditing service"
        set -e

        # enable auditing service, it should be running at anytime
        systemctl enable centrifyda.service || true

        # start auditing service for configuration
        /usr/share/centrifydc/bin/centrifyda start || true

        # enable or disable NSS auditing
        if [[ "$NSSAuditing" == "Y" || "$NSSAuditing" == "y" || "$NSSAuditing" == "T" || "$NSSAuditing" == "t" ]] ; then
            echo "enable NSS auditing "
            /usr/sbin/dacontrol -e || true
        else
            echo "disable NSS auditing "
            /usr/sbin/dacontrol -d || true
        fi

        # appending the installation parameter to the configuration file if the system is enrolled in the cloud.
        
        if [[ "$UseMyAccount" == "yes" ]] ; then
            echo "dad.installation.source: direct_control" >> /etc/centrifyda/centrifyda.conf
        fi  

        # set audit installation
        if [ -n "$INSTALLATION" ]; then

            echo "set audit installation to $INSTALLATION"
            /usr/sbin/dacontrol -i "$INSTALLATION" || true            

            # the new installation setting will take effect once
            # the auditing service is started by systemd later.
        fi

        # check current settings
        /usr/sbin/dacontrol -q || true

    ) 2>&1 | tee -a /var/centrify/adjoin.log
fi

# stop now, the service will be started by systemd later
(
    echo "stop Centrify DirectControl"
    /usr/share/centrifydc/bin/centrifydc stop

    if [ -x /usr/sbin/dad ]; then
        echo "stop Centrify DirectAudit"
        /usr/share/centrifydc/bin/centrifyda stop
    fi

) 2>&1 | tee -a /var/centrify/adjoin.log

# change password if specified
if [ "$ROOT_PASSWORD" != "" ] ; then
    echo "set root password "
    echo "root:$ROOT_PASSWORD" | chpasswd
else
    echo "generate root password "
    echo root:$(/usr/share/centrifydc/bin/openssl rand -base64 16) | chpasswd
fi

if [[ "$UseMyAccount" == "yes" ]] ; then
    (
    # create a new service for unenroll Centrify agent
    systemctl enable centrifycc-unenroll.service

    if [ $RC -eq 0 ]; then
        # enable the service so that it will be started by systemd later on
        echo "enabling centrifycc-cenroll.service"
        systemctl enable centrifycc-cenroll.service
    else
        echo "cenroll service failed."
    fi

    # setting up the port number
    CENROLLPARAM=()
    CENROLLPARAM=("-S" "\"Port:$PORT\"")
    PORTNUMBER="${CENROLLPARAM[@]}"

    # setting up the connector name
    CENROLLPARAM=()
    if [ "$CONNECTOR" != "" ] ; then
        CENROLLPARAM=("-S" "\"Connectors:$CONNECTOR\"")
    fi
    CONNECTORNAME="${CENROLLPARAM[@]}"

    #creating the suitable environment file for centrifycc-cenroll.service
    FILENAME="/etc/sysconfig/cenroll"
    if [ -d /etc/default ]; then
        FILENAME="/etc/default/cenroll"
    fi
    touch $FILENAME
    echo "URL=$URL" >> $FILENAME
    echo "CODE=$CODE" >> $FILENAME
    echo "NAME=$NAME" >> $FILENAME
    echo "ADDRESS=$ADDRESS" >> $FILENAME
    echo "PORT=$PORTNUMBER" >> $FILENAME
    echo "CONNECTOR=$CONNECTORNAME" >> $FILENAME

    #setting up the SELinux policy for centos docker containers.
    if [ -f /etc/selinux/config ]; then
        sed -i 's/SELINUX=enforcing/SELINUX=permissive/g' /etc/selinux/config
    fi

    if [ -f /etc/systemd/system/multi-user.target.wants/centrifycc.service ]; then
        rm /etc/systemd/system/multi-user.target.wants/centrifycc.service
    fi
        
    touch /etc/centrifycc/*
    touch /etc/centrifycc/autoedit/*
    /usr/sbin/cunenroll -f
    ) 2>&1 | tee -a /var/centrify/adjoin.log

    # enabling the service to run cenroll command
    systemctl enable centrifycc-cenroll.service
fi

echo "start the container"
exec /usr/sbin/init