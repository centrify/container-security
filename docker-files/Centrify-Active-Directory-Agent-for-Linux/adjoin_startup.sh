#! /bin/bash
#
echo "domain:" $DOMAIN
echo "user to join:" $ADJOINER
echo "zone:" $ZONE 
echo "container:" $OU
echo "host name to use:" $NAME

# setup value for UseMyAccount
echo "ENABLE_USE_MY_ACCOUNT: $ENABLE_USE_MY_ACCOUNT" 
UseMyAccount='N'

if [ "$ENABLE_USE_MY_ACCOUNT" != "" ] ; then
   UseMyAccount=${ENABLE_USE_MY_ACCOUNT::1}
fi
echo "current tenant URL: " $URL
echo "UseMyAccount: $UseMyAccount" 

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

if [[ "$UseMyAccount" == "Y" || "$UseMyAccount" == "y" || "$UseMyAccount" == "T" || "$UseMyAccount" == "t" ]] ; then
  if [ "$URL" = "" ]; then
    echo "UseMyAccount is enabled but tenant URL is not specified."
    exec /usr/sbin/init
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

if [[ "$UseMyAccount" == "Y" || "$UseMyAccount" == "y" || "$UseMyAccount" == "T" || "$UseMyAccount" == "t" ]] ; then
  # set up sshd config
  if [ ! -f /etc/ssh/sshd_config.bak ] ; then
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
    sed -i -e '/^TrustedUserCAKeys/d' -e '/^AuthorizedPrincipalsCommand/d' /etc/ssh/sshd_config
    echo "AuthorizedPrincipalsCommand /usr/bin/adquery user -P %u" >> /etc/ssh/sshd_config
    echo "AuthorizedPrincipalsCommandUser root" >> /etc/ssh/sshd_config
    echo "TrustedUserCAKeys /etc/ssh/cps_ca.pub" >> /etc/ssh/sshd_config
  fi
  /usr/share/centrifydc/bin/curl -o /etc/ssh/cps_ca.pub https://$URL/servermanage/getmastersshkey
fi

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
    # note that systemd does not start yet so adjoin will show error because
    # the service cannot be started, this error (15) can be ignored
    echo "joining the system to AD ..."
    RC=0
    /usr/sbin/adjoin -V $DOMAIN -z $ZONE "${CMDPARAM[@]}" --force || RC=$?
    if [ $RC -eq 0 -o $RC -eq 15 ]; then
        # enable the service so that it will be started by systemd later on
        systemctl enable centrifydc.service
    else
        echo "adjoin failed."
        false
    fi

#   change password if specified
    if [ "$ROOT_PASSWORD" != "" ] ; then
       echo "set root password "
       echo "$ROOT_PASSWORD" | passwd --stdin root
    else
       echo "generate root password "
       /usr/share/centrifydc/bin/openssl rand -base64 16 | passwd --stdin root
    fi

) 2>&1 | tee -a /var/centrify/adjoin.log


echo "start the container"
exec /usr/sbin/init

