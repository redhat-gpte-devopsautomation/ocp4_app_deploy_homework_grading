FROM quay.io/openshift/origin-jenkins-agent-maven:4.4.0

# Switch to root user to install things
USER root

ENV DISABLES="--disablerepo=rhel-server-extras --disablerepo=rhel-server --disablerepo=rhel-fast-datapath --disablerepo=rhel-fast-datapath-beta --disablerepo=rhel-server-optional --disablerepo=rhel-server-ose --disablerepo=rhel-server-rhscl"

RUN curl https://copr.fedorainfracloud.org/coprs/alsadi/dumb-init/repo/epel-7/alsadi-dumb-init-epel-7.repo -o /etc/yum.repos.d/alsadi-dumb-init-epel-7.repo \
   && curl https://raw.githubusercontent.com/cloudrouter/centos-repo/master/CentOS-Base.repo -o /etc/yum.repos.d/CentOS-Base.repo \
   && curl http://mirror.centos.org/centos-7/7/os/x86_64/RPM-GPG-KEY-CentOS-7 -o /etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7

RUN yum ${DISABLES} -y install https://centos7.iuscommunity.org/ius-release.rpm \
    && yum ${DISABLES} -y install skopeo git \
    && yum clean all

# Next for FTL (doesn't work though with OCP 4.4 images. Disabling for now)
# RUN yum ${DISABLES} -y install https://centos7.iuscommunity.org/ius-release.rpm \
#     && yum ${DISABLES} -y install python36u python36u-pip skopeo git \
#     && /usr/bin/pip3.6 install pip setuptools --upgrade \
#     && pip install wheel ansible openshift virtualenv \
#     && yum clean all

# Set up Python libraries and FTL
# ADD requirements.yml /tmp/requirements.yml
# ADD install_ftl.yml /tmp/install_ftl.yml
# RUN ansible-galaxy install -r /tmp/requirements.yml \
#     && ansible-playbook --connection=local -i localhost, /tmp/install_ftl.yml -e install_dependencies=false \
#     && rm /tmp/install_ftl.yml /tmp/requirements.yml

# Enable setting of opentlc_student in global vars file
# RUN chown 1001 /opt/ftl-repo-clone/vars/global_vars.yml \
#     && chmod 666 /opt/ftl-repo-clone/vars/global_vars.yml

# Switch back to user 1001 to execute the agent pod
USER 1001
