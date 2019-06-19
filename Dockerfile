FROM centos:centos7

# OpenLDAP server image for OpenShift Origin

LABEL io.k8s.description="OpenLDAP is an open source implementation of the Lightweight Directory Access Protocol." \
      io.k8s.display-name="OpenLDAP 2.4.44" \
      io.openshift.expose-services="389:ldap,636:ldaps" \
      io.openshift.non-scalable="false" \
      io.openshift.tags="directory,ldap,openldap,openldap2444" \
      help="For more information visit https://github.com/Worteks/docker-ldap" \
      maintainer="Paul CURIE <paucur@worteks.com>, Samuel MARTIN MORO <sammar@worteks.com>" \
      version="2.4.44"

COPY config/genrsa config/is-ready.sh config/run-openldap.sh config/hack-slapd-ldapi /usr/local/bin/
COPY config/*.ldif config/*.schema config/DB_CONFIG /usr/local/etc/openldap/
COPY config/config-updates /usr/local/etc/openldap/config-updates/

RUN yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm \
    && yum install -y ldapvi \
    && yum-config-manager --enable "CentOS-7 - Base" --enable "CentOS-7 - Extras" --enable "CentOS-7 - Updates" \
    && yum install -y openldap openldap-servers openldap-clients openssl-devel perl-Crypt-OpenSSL-RSA perl-Archive-Zip \
    && if test "$DO_UPGRADE"; then \
	yum -y upgrade; \
    fi \
    && yum clean all -y \
    && setcap 'cap_net_bind_service=+ep' /usr/sbin/slapd \
    && for dir in /etc/openldap /var/lib/ldap /var/run/openldap; \
	do \
	    mkdir -p $dir 2>/dev/null; \
	    chmod a+rwx -R $dir; \
	done \
    && cp -rp /etc/openldap /usr/local/etc/openldap/root-conf-orig \
    && rm -rf /var/cache/yum /usr/share/doc /usr/share/man \
    && unset HTTP_PROXY HTTPS_PROXY NO_PROXY DO_UPGRADE http_proxy https_proxy

CMD [ "/usr/local/bin/run-openldap.sh" ]
