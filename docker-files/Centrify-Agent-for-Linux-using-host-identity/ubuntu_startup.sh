#!/bin/bash

# start rsyslog
/etc/init.d/rsyslog start
status=$?
if [ $status -ne 0 ]; then
	echo "Cannot start rsyslog"
fi

# untar the copied files
tar xf /var/centrify/tmp/docker.copy.tar -C /

# start sshd
/etc/init.d/ssh start
status=$?

if [ $status -ne 0 ]; then
    echo "Cannot start sshd"
fi

# sleep forever
while /bin/true; do
    sleep 600
done
