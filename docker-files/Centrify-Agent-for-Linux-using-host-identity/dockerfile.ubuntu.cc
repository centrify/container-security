# sshd

FROM ubuntu:latest
#MAINTAINER
#LABEL 

RUN apt-get update && apt-get install -y openssh-server vim
RUN mkdir /var/run/sshd
RUN echo 'root:$ROOT_PASSWORD' | chpasswd
RUN sed -i '/^#\?PermitRootLogin/c\PermitRootLogin yes' /etc/ssh/sshd_config
RUN sed -i '/^#\?ChallengeResponseAuthentication/c\ChallengeResponseAuthentication yes' /etc/ssh/sshd_config

# SSH login fix. Otherwise user is kicked off after login
RUN sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd

# download CentrifyCC agent
RUN wget -O /tmp/centrifycc-deb8-x86_64.deb \
  https://downloads.centrify.com/products/cloud-service/CliDownload/Centrify/centrifycc-deb8-x86_64.deb \
  && apt-get install -y /tmp/centrifycc-deb8-x86_64.deb

# update NSS and PAM stacks
RUN if [ -f /usr/share/centrifycc/sbin/config_editor.pl ] ; then /usr/share/centrifycc/sbin/config_editor.pl add /etc/centrifycc/autoedit ; else /opt/centrify/perl/scripts/config_editor.pl add /etc/centrifycc/autoedit ; fi

#
# restore key directories
RUN mkdir -p -m 0400 /var/centrify/tmp
COPY  docker.copy.tar /var/centrify/tmp
RUN chmod 400 /var/centrify/tmp/docker.copy.tar

# set up rsyslog
RUN apt-get install -y rsyslog

ENV NOTVISIBLE "in users profile"
RUN echo "export VISIBLE=now" >> /etc/profile

EXPOSE 22

COPY ubuntu_startup.sh /var/centrify/tmp/startup.sh
RUN chmod 500 /var/centrify/tmp/startup.sh
CMD /var/centrify/tmp/startup.sh

