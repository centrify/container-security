# services

FROM centos:latest
#MAINTAINER
#LABEL 

RUN yum -y update && yum install -y openssh-server vim openssh-clients
RUN mkdir /var/run/sshd
RUN ssh-keygen -t rsa -f /etc/ssh/ssh_host_rsa_key -N ''
RUN echo 'root:$ROOT_PASSWORD' | chpasswd
RUN sed -i '/^#\?PermitRootLogin/c\PermitRootLogin yes' /etc/ssh/sshd_config
RUN sed -i '/^#\?ChallengeResponseAuthentication/c\ChallengeResponseAuthentication yes' /etc/ssh/sshd_config

# SSH login fix. Otherwise user is kicked off after login
RUN sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd

# install systemd
RUN yum -y install systemd; yum clean all; \
(cd /lib/systemd/system/sysinit.target.wants/; for i in *; do [ $i == systemd-tmpfiles-setup.service ] || rm -f $i; done ); 

VOLUME [ "/sys/fs/cgroup" ]

# download and install CentrifyCC agent
RUN curl --fail -s -o /tmp/CentrifyCC-rhel6.x86_64.rpm \
  https://downloads.centrify.com/products/cloud-service/CliDownload/Centrify/CentrifyCC-rhel6.x86_64.rpm \
  && yum -y install /tmp/CentrifyCC-rhel6.x86_64.rpm && yum clean all

# note that systemd comes with journald in CentOS...no need to install rsyslog

# enable and start services
RUN systemctl enable sshd.service

# update nss and pam stack
RUN if [ -f /usr/share/centrifycc/sbin/config_editor.pl ] ; then /usr/share/centrifycc/sbin/config_editor.pl add /etc/centrifycc/autoedit ; else /opt/centrify/perl/scripts/config_editor.pl add /etc/centrifycc/autoedit ; fi

# restore key directories
RUN mkdir -p -m 0400 /var/centrify/tmp
COPY docker.copy.tar /var/centrify/tmp
RUN chmod 400 /var/centrify/tmp/docker.copy.tar

# create start up file
# 
RUN echo "#! /bin/bash" > /var/centrify/tmp/startup.sh
RUN echo "tar xf /var/centrify/tmp/docker.copy.tar -C /" >> /var/centrify/tmp/startup.sh
RUN echo "exec /usr/sbin/init" >> /var/centrify/tmp/startup.sh
#
RUN chmod 500 /var/centrify/tmp/startup.sh

# set selinux to permissive
RUN sed -i 's/SELINUX=enforcing/SELINUX=permissive/g' /etc/selinux/config

ENV NOTVISIBLE "in users profile"
RUN echo "export VISIBLE=now" >> /etc/profile


EXPOSE 22

CMD ["/var/centrify/tmp/startup.sh"]

