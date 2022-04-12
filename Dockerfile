# Use osixia/light-baseimage
# sources: https://github.com/osixia/docker-light-baseimage
FROM osixia/light-baseimage:1.3.2

ARG OPENLDAP_PACKAGE_VERSION=2.4.57

ENV LDAP_OPENLDAP_GID=1000
ENV LDAP_OPENLDAP_UID=1000

ARG PQCHECKER_VERSION=2.0.0
ARG PQCHECKER_MD5=c005ce596e97d13e39485e711dcbc7e1

# Add openldap user and group first to make sure their IDs get assigned consistently, regardless of whatever dependencies get added
# If explicit uid or gid is given, use it.

# If explicit uid or gid is given, use it.
RUN echo "\n\n\n\n=====================\n"
RUN echo "GID : ${LDAP_OPENLDAP_GID}"
RUN echo "UID : ${LDAP_OPENLDAP_UID}"
RUN echo "\n=====================\n\n\n\n"
 
RUN if [ ${LDAP_OPENLDAP_GID} -eq 1000 ]; then groupadd -g 1000 -r openldap; else groupadd -r -g ${LDAP_OPENLDAP_GID} openldap; fi \
    && if [ ${LDAP_OPENLDAP_UID} -eq 1000 ]; then useradd -u 1000 -r -g openldap openldap; else useradd -r -g openldap -u ${LDAP_OPENLDAP_UID} openldap; fi

# Add buster-backports in preparation for downloading newer openldap components, especially sladp
RUN echo "deb http://ftp.debian.org/debian buster-backports main" >> /etc/apt/sources.list
RUN echo "deb http://mirror.kakao.com/ubuntu focal main" >> /etc/apt/addsources.list
RUN echo "wget -qO - http://mirror.kakao.com/ubuntu/project/ubuntu-archive-keyring.gpg | apt-key add - "

# Install OpenLDAP, ldap-utils and ssl-tools from the (backported) baseimage and clean apt-get files
# sources: https://github.com/osixia/docker-light-baseimage/blob/master/image/tool/add-service-available
#          https://github.com/osixia/docker-light-baseimage/blob/master/image/service-available/:ssl-tools/download.sh
RUN echo "path-include /usr/share/doc/krb5*" >> /etc/dpkg/dpkg.cfg.d/docker && apt-get -y update \
    && /container/tool/add-service-available :ssl-tools \
    && LC_ALL=C DEBIAN_FRONTEND=noninteractive apt-get -t buster-backports install -y --no-install-recommends \
    ca-certificates \
    curl \
    ldap-utils=${OPENLDAP_PACKAGE_VERSION}\* \
    libsasl2-modules \
    libsasl2-modules-db \
    libsasl2-modules-gssapi-mit \
    libsasl2-modules-ldap \
    libsasl2-modules-otp \
    libsasl2-modules-sql \
    net-tools \
    vim \
    openssl \
    slapd=${OPENLDAP_PACKAGE_VERSION}\* \
    slapd-contrib=${OPENLDAP_PACKAGE_VERSION}\* \
    krb5-kdc-ldap \
    && curl -o pqchecker.deb -SL http://www.meddeb.net/pub/pqchecker/deb/8/pqchecker_${PQCHECKER_VERSION}_amd64.deb \
    && echo "${PQCHECKER_MD5} *pqchecker.deb" | md5sum -c - \
    && dpkg -i pqchecker.deb \
    && rm pqchecker.deb \
    && update-ca-certificates \
    && apt-get remove -y --purge --auto-remove curl ca-certificates \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Add service directory to /container/service
ADD service /container/service

# Use baseimage install-service script
# https://github.com/osixia/docker-light-baseimage/blob/master/image/tool/install-service
RUN /container/tool/install-service

# Add default env variables
ADD environment /container/environment/99-default

# Expose default ldap and ldaps ports
EXPOSE 389 636

# Put ldap config and database dir in a volume to persist data.
VOLUME /etc/ldap/slapd.d /var/lib/ldap

