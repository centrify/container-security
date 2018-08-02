#! /bin/bash
#
echo "current tenant URL: " $URL
echo "IP address to use:" $ADDRESS
echo "host name to use:" $NAME
echo "current setting for PORT:" $PORT
echo "connectors setting: " $CONNECTOR
echo "login role: " $LOGIN_ROLE

# setup value for UseMyAccount
echo "ENABLE_USE_MY_ACCOUNT: $ENABLE_USE_MY_ACCOUNT" 
UseMyAccount='N'

if [ "$ENABLE_USE_MY_ACCOUNT" != "" ] ; then
   UseMyAccount=${ENABLE_USE_MY_ACCOUNT::1}
fi
echo "UseMyAccount: $UseMyAccount" 

# setup value for vault root account
echo "VAULT_ROOT_PASSWD: $VAULT_ROOT_PASSWD"
VaultRootPasswd='N'

if [ "$VAULT_ROOT_PASSWD" != "" ] ; then
  VaultRootPasswd=${VAULT_ROOT_PASSWD::1}
  if [[ "$VaultRootPasswd" == "y" || "$VaultRootPasswd" == "t" || "$VaultRootPasswd" == "T" ]] ; then
    VaultRootPasswd='Y'
  fi
fi
echo "VaultRootPasswd: $VaultRootPasswd"

ManageRootPasswd='false'
if [ "$VaultRootPasswd" == "Y" ] ; then
  echo "LOGIN_AS_ROOT_ROLES: $LOGIN_AS_ROOT_ROLES"
# handle MANAGE_ROOT_PASSWD
  echo "MANAGE_ROOT_PASSWD: $MANAGE_ROOT_PASSWD"
  if [ "$MANAGE_ROOT_PASSWD" != "" ] ; then
    ManageRootPasswd=${MANAGE_ROOT_PASSWD::1}
    if [[ "$ManageRootPasswd" == "y" || "$ManageRootPasswd" == "Y"  || "$ManageRootPasswd" == "t" || "$ManageRootPasswd" == "T" ]] ; then
      ManageRootPasswd='true'
    fi
  fi
  echo "ManageRootPasswd: $ManageRootPasswd"
fi 

# check required parameters

if [ "$URL" = "" ] ; then
  echo No tenant URL specified.
  exec /usr/sbin/init
fi

if [ "$CODE" = "" ] ; then
  echo No enrollment code specified.
  exec /usr/sbin/init
fi

if [ "$LOGIN_ROLE" = "" ] ; then
  echo No login role specified.
  exec /usr/sbin/init
fi

# set up command line parameters
CMDPARAM=()

if [ "$PORT" != "" ] ; then
  CMDPARAM=("${CMDPARAM[@]}" "-S" "Port:$PORT")
fi

if [ "$NAME" != "" ] ; then
  CMDPARAM=("${CMDPARAM[@]}" "--name" "$NAME")
fi

if [ "$ADDRESS" != "" ] ; then
  CMDPARAM=("${CMDPARAM[@]}" "--address" "$ADDRESS")
fi

if [ "$CONNECTOR" != "" ] ; then
  CMDPARAM=("${CMDPARAM[@]}" "-S" "\"Connectors:$CONNECTOR\"")
fi

# grant permission for each role that is authorized

IFS=","
for role in $LOGIN_ROLE 
do
  CMDPARAM=("${CMDPARAM[@]}" "--resource-permission" "role:$role:View")
done

# setup for "Use My Account" feature

if [[ "$UseMyAccount" == "Y" || "$UseMyAccount" == "y" || "$UseMyAccount" == "T" || "$UseMyAccount" == "t" ]] ; then
# set up sshd config
  if [ ! -f /etc/ssh/sshd_config.bak ] ; then
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
    sed -i '/^TrustedUserCAKeys/d' /etc/ssh/sshd_config
    echo "TrustedUserCAKeys /etc/ssh/cps_ca.pub" >> /etc/ssh/sshd_config
  fi
  curl -o /etc/ssh/cps_ca.pub https://$URL/servermanage/getmastersshkey
  CMDPARAM=("${CMDPARAM[@]}" "-S" "CertAuthEnable:true")
fi

if [ "$OPTION" != "" ] ; then
# convert the string into an array for passing into cenroll
  IFS=' ' read -a tempoption <<< "${OPTION}"
  CMDPARAM=("${CMDPARAM[@]}" "${tempoption[@]}")
fi

if [ -f /etc/systemd/system/multi-user.target.wants/centrifycc.service ]; then
  rm /etc/systemd/system/multi-user.target.wants/centrifycc.service
fi

# need to touch all files in /etc/centrifycc and /etc/centrifycc/autoedit
touch /etc/centrifycc/*
touch /etc/centrifycc/autoedit/*

# if need to vault root password, set up another shell script to do that

if [ "$VaultRootPasswd" == "Y" ] ; then
  mkdir -p -m=755 /var/centrify/tmp
  if [ -f /var/centrify/tmp/setpasswd.sh ] ; then
    rm /var/centrify/tmp/setpasswd.sh
  fi

  echo '#!/bin/bash' > /var/centrify/tmp/setpasswd.sh
  echo "export PASS=\`openssl rand -base64 16\`" >> /var/centrify/tmp/setpasswd.sh
  echo "echo \$PASS | passwd --stdin root" >> /var/centrify/tmp/setpasswd.sh
  echo "Permissions=()" >> /var/centrify/tmp/setpasswd.sh
  echo "IFS=\",\" read -a roles <<< \"$LOGIN_AS_ROOT_ROLES\"" >> /var/centrify/tmp/setpasswd.sh
  echo "for role in \${roles[@]} " >> /var/centrify/tmp/setpasswd.sh
  echo " do " >> /var/centrify/tmp/setpasswd.sh
  echo "  Permissions=(\"\${Permissions[@]}\" \"-p\" \"\\\"role:\$role:Edit,Checkout,View,Login\\\"\" )" >> /var/centrify/tmp/setpasswd.sh
  echo "done" >> /var/centrify/tmp/setpasswd.sh
  echo 'echo `date` setting root account >> /var/centrify/enroll.log' >> /var/centrify/tmp/setpasswd.sh
  echo "echo \$PASS | /usr/sbin/csetaccount --stdin -m $ManageRootPasswd \${Permissions[@]} root" >> /var/centrify/tmp/setpasswd.sh
  echo 'echo `date` setting root account done >> /var/centrify/enroll.log' >> /var/centrify/tmp/setpasswd.sh
  chmod 700 /var/centrify/tmp/setpasswd.sh

# also, for each role that can login as root, grant them view permission to the resource
  IFS=","
  for role in $LOGIN_AS_ROOT_ROLES 
  do
    CMDPARAM=("${CMDPARAM[@]}" "--resource-permission" "role:$role:View")
  done

# set up post-enroll hook
  if [ ! -f /etc/centrifycc/centrifycc.conf.bak ] ; then
    cp /etc/centrifycc/centrifycc.conf /etc/centrifycc/centrifycc.conf.bak
    echo "cli.hook.cenroll: /var/centrify/tmp/setpasswd.sh" >> /etc/centrifycc/centrifycc.conf
  fi
else
# set up password
  if [ "$ROOT_PASSWORD" != "" ] ; then
# use specified password
    echo "`date`: set root password" >> /var/centrify/enroll.log
    echo "$ROOT_PASSWORD" | passwd --stdin root
  else
# set up root password
    echo "`date`: set random root password" >> /var/centrify/enroll.log
    openssl rand -base64 16 | passwd --stdin root
  fi
fi

set +e
/usr/sbin/cunenroll -f

echo "`date`: ready to enroll" >> /var/centrify/enroll.log
echo " parameters: [${CMDPARAM[@]}]" >> /var/centrify/enroll.log

/usr/sbin/cenroll -t $URL -F all --agentauth "$LOGIN_ROLE" --code $CODE "${CMDPARAM[@]}" -f  &
set -e

exec /usr/sbin/init
