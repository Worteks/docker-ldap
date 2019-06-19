#!/bin/sh

# https://github.com/docker/docker/issues/8231
ulimit -n 1024
if test "$DEBUG"; then
    set -x
fi

OPENLDAP_AUTHPROXY_PASSWORD=${OPENLDAP_AUTHPROXY_PASSWORD:-secret}
OPENLDAP_BIND_LDAP_PORT=${OPENLDAP_BIND_LDAP_PORT:-389}
OPENLDAP_BIND_LDAPS_PORT=${OPENLDAP_BIND_LDAPS_PORT:-636}
OPENLDAP_BLUEMIND_PASSWORD=${OPENLDAP_BLUEMIND_PASSWORD:-secret}
OPENLDAP_CODIMD_PASSWORD=${OPENLDAP_CODIMD_PASSWORD:-secret}
OPENLDAP_DEBUG_LEVEL=${OPENLDAP_DEBUG_LEVEL:-256}
OPENLDAP_DOKUWIKI_PASSWORD=${OPENLDAP_DOKUWIKI_PASSWORD:-secret}
OPENLDAP_FULL_INIT=true
OPENLDAP_FUSION_PASSWORD=${OPENLDAP_FUSION_PASSWORD:-secret}
OPENLDAP_HOST_ENDPOINT=${OPENLDAP_HOST_ENDPOINT:-openldap}
OPENLDAP_INIT_DEBUG_LEVEL=${OPENLDAP_INIT_DEBUG_LEVEL:-256}
OPENLDAP_JENKINS_SAML_SIGNING_CERTIFICATE=${OPENLDAP_JENKINS_SAML_SIGNING_CERTIFICATE:-x509data}
OPENLDAP_JENKINS_SAML_ENCRYPTION_CERTIFICATE=${OPENLDAP_JENKINS_SAML_ENCRYPTION_CERTIFICATE:-x509data}
OPENLDAP_LEMON_HTTP_PORT=${OPENLDAP_LEMON_HTTP_PORT:-8080}
OPENLDAP_LEMON_SAML_ENC_PRIVATE_KEY=${OPENLDAP_LEMON_SAML_ENC_PRIVATE_KEY:-x509data}
OPENLDAP_LEMON_SAML_SIG_PRIVATE_KEY=${OPENLDAP_LEMON_SAML_SIG_PRIVATE_KEY:-x509data}
OPENLDAP_LEMONLDAP_PASSWORD=${OPENLDAP_LEMONLDAP_PASSWORD:-secret}
OPENLDAP_LEMONLDAP_SESSIONS_PASSWORD=${OPENLDAP_LEMONLDAP_SESSIONS_PASSWORD:-secret}
OPENLDAP_MONITOR_PASSWORD=${OPENLDAP_MONITOR_PASSWORD:-secret}
OPENLDAP_MEDIAWIKI_PASSWORD=${OPENLDAP_MEDIAWIKI_PASSWORD:-secret}
OPENLDAP_NEXTCLOUD_PASSWORD=${OPENLDAP_NEXTCLOUD_PASSWORD:-secret}
OPENLDAP_ROCKET_PASSWORD=${OPENLDAP_ROCKET_PASSWORD:-secret}
OPENLDAP_ROOT_DN_PREFIX=${OPENLDAP_ROOT_DN_PREFIX:-'cn=Directory Manager'}
OPENLDAP_ROOT_DOMAIN=${OPENLDAP_ROOT_DOMAIN:-'demo.local'}
OPENLDAP_ROOT_PASSWORD=${OPENLDAP_ROOT_PASSWORD:-secret}
OPENLDAP_SMTP_SERVER=${OPENLDAP_SMTP_SERVER:-'smtp.demo.local'}
OPENLDAP_SSO_CLIENT_PASSWORD=${OPENLDAP_SSO_CLIENT_PASSWORD:-secret}
OPENLDAP_SSP_PASSWORD=${OPENLDAP_SSP_PASSWORD:-secret}
OPENLDAP_STATEFULSET_NAME=${OPENLDAP_STATEFULSET_NAME:-openldap}
OPENLDAP_SYNCREPL_PASSWORD=${OPENLDAP_SYNCREPL_PASSWORD:-secret}
OPENLDAP_WEKAN_PASSWORD=${OPENLDAP_WEKAN_PASSWORD:-secret}
OPENLDAP_WHITEPAGES_PASSWORD=${OPENLDAP_WHITEPAGES_PASSWORD:-secret}
OPENLDAP_WSWEET_PASSWORD=${OPENLDAP_WSWEET_PASSWORD:-secret}

if ! test -f /etc/openldap/VERSION; then
    VERSION=0.0.0
else
    VERSION=`cat /etc/openldap/VERSION`
fi

list_elligible_patches()
{
    eval `echo $VERSION | sed 's|^\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)$|left1=\1 left2=\2 left3=\3|'`
    ls /usr/local/etc/openldap/config-updates| sort -V |while read UPGRADE
	do
	    eval `echo $UPGRADE | sed 's|^\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)$|right1=\1 right2=\2 right3=\3|'`
	    if test "$left1" -gt "$right1"; then
		continue
	    elif test "$left2" -gt "$right2"; then
		continue
	    elif test "$left3" -ge "$right3"; then
		continue
	    fi
	    echo $UPGRADE
	done
}

list_missing_replicates()
{
    check=0
    while :
    do
	if test "$check" = "$OPENLDAP_SERVER_ID"; then
	    echo NOTICE: do not configure replication against local / $OPENLDAP_BASENAME-$OPENLDAP_SERVER_ID
	    check=`expr $check + 1`
	    continue
	elif grep "^$OPENLDAP_BASENAME-$check:" /etc/openldap/.repl-configured >/dev/null 2>&1; then
	    echo NOTICE: do not reconfigure replication against remote / $OPENLDAP_BASENAME-$check
	    check=`expr $check + 1`
	    continue
	elif ldapsearch -o nettimeout=5 -H ldap://$OPENLDAP_BASENAME-$check.$OPENLDAP_STATEFULSET_NAME:$OPENLDAP_BIND_LDAP_PORT/ 2>&1 | grep "No such attribute" >/dev/null; then
	    echo NOTICE: $OPENLDAP_BASENAME-$check is alive
	else
	    echo NOTICE: $OPENLDAP_BASENAME-$check.$OPENLDAP_STATEFULSET_NAME:$OPENLDAP_BIND_LDAP_PORT unreachable, assuming remote does not exist
	    if ! test -s /etc/openldap/.repl-configured; then
		cat <<EOF
WARNING: when first deploying a statefulset, once done starting all members of
	 your cluster, make sure to sequentially reboot all your containers but
	 the last one, as we've only configured replication against remotes that
	 were reachable during service initialization
EOF
	    fi
	    break
	fi >&2
	echo $check
	check=`expr $check + 1`
    done
}

start_with_ldapi()
{
    slapd -h "ldap://:$OPENLDAP_BIND_LDAP_PORT/ ldaps://:$OPENLDAP_BIND_LDAPS_PORT/ ldapi:///" -d $OPENLDAP_INIT_DEBUG_LEVEL &
    cpt=0
    while test "$cpt" -lt 30
    do
	ldapsearch -H ldap://localhost:$OPENLDAP_BIND_LDAP_PORT/ 2>&1 | grep "Can.t contact LDAP server" >/dev/null || break
	cpt=`expr $cpt + 1`
	sleep 1
    done
    if test "$cpt" -eq 30; then
	echo "slapd did not start correctly"
	exit 1
    fi
}

stop_ldapi()
{
    cpt=0
    pid=$(ps -A | awk '/sla[p]d/{print $1}')
    kill -2 $pid || echo $?
    while test "$cpt" -lt 30
    do
	ps -A 2>/dev/null | grep -E "^[ ]*$pid[ ]" >/dev/null || break
	cpt=`expr $cpt + 1`
	sleep 1
    done
    if test "$cpt" -eq 30; then
	echo "slapd did not stop correctly"
	exit 1
    fi
}

if test -z "$OPENLDAP_ROOT_DN_SUFFIX"; then
    OPENLDAP_ROOT_DN_SUFFIX=`echo "dc=$OPENLDAP_ROOT_DOMAIN" | sed 's|\.|,dc=|g'`
fi
if test -z "$OPENLDAP_HOSTNAME"; then
    OPENLDAP_HOSTNAME=`hostname 2>/dev/null`
fi
if test "$OPENLDAP_DEBUG"; then
    OPENLDAP_HOSTNAME=test-0
fi
OPENLDAP_SERVER_ID=`echo "$OPENLDAP_HOSTNAME" | sed 's|^.*-\([0-9][0-9]*\)$|\1|'`
if ! test "$OPENLDAP_SERVER_ID" = "$OPENLDAP_HOSTNAME"; then
    OPENLDAP_BASENAME=`echo $OPENLDAP_HOSTNAME | sed "s|-$OPENLDAP_SERVER_ID$||"`
    if test "$OPENLDAP_SERVER_ID" -ne 0; then
	OPENLDAP_FULL_INIT=false
    fi
else
    OPENLDAP_BASENAME=
fi
ls /usr/local/etc/openldap/root-conf-orig | while read item
    do
	test -f "/etc/openldap/$item" -o -d "/etc/openldap/$item" && continue
	cp -rf "/usr/local/etc/openldap/root-conf-orig/$item" /etc/openldap/
    done
for d in /var/run/openldap /etc/openldap/slapd.d
do
    test -d "$d" || mkdir -p "$d"
done
if ! test -f /etc/openldap/CONFIGURED; then
    OPENLDAP_ROOT_PASSWORD_HASH=$(slappasswd -s "$OPENLDAP_ROOT_PASSWORD")
    WSWEET_SA_PASSWORD_HASH=$(slappasswd -s "$OPENLDAP_WSWEET_PASSWORD")
    /usr/local/bin/hack-slapd-ldapi
    cp /usr/local/etc/openldap/DB_CONFIG /var/lib/ldap/DB_CONFIG
    start_with_ldapi
    sed -e "s OPENLDAP_ROOT_PASSWORD $OPENLDAP_ROOT_PASSWORD_HASH g" \
	-e "s/OPENLDAP_ROOT_DN/$OPENLDAP_ROOT_DN_PREFIX/g" \
	-e "s OPENLDAP_WSWEET_PASSWORD $WSWEET_SA_PASSWORD_HASH g" \
	-e "s OPENLDAP_SUFFIX $OPENLDAP_ROOT_DN_SUFFIX g" /usr/local/etc/openldap/first_config.ldif |
	ldapmodify -Y EXTERNAL -H ldapi:/// -d $OPENLDAP_INIT_DEBUG_LEVEL
    for ldif in /etc/openldap/schema/cosine \
	/etc/openldap/schema/inetorgperson /etc/openldap/schema/ppolicy \
	/usr/local/etc/openldap/sweetUser /usr/local/etc/openldap/sweetGroup \
	/usr/local/etc/openldap/template-fd \
	/usr/local/etc/openldap/rfc2307bis /usr/local/etc/openldap/mail-fd \
	/usr/local/etc/openldap/mail-fd-conf /usr/local/etc/openldap/ldapns \
	/usr/local/etc/openldap/core-fd /usr/local/etc/openldap/core-fd-conf \
	/usr/local/etc/openldap/load_modules \
	/usr/local/etc/openldap/configure_ppolicy \
	/usr/local/etc/openldap/configure_memberof \
	/usr/local/etc/openldap/configure_refint \
	/usr/local/etc/openldap/configure_unique \
	/usr/local/etc/openldap/configure_syncrepl \
	/usr/local/etc/openldap/configure_indexes
    do
	if ! test -s $ldif.ldif; then
	    WARNING: missing $ldif
	    continue
	fi
	sed -e "s OPENLDAP_SUFFIX $OPENLDAP_ROOT_DN_SUFFIX g" \
	    -e "s OPENLDAP_PORT $OPENLDAP_BIND_LDAP_PORT g" $ldif.ldif | \
	    ldapadd -Y EXTERNAL -H ldapi:/// -d $OPENLDAP_INIT_DEBUG_LEVEL || \
	    echo WARNING: failed importing $ldif
    done
    if test "$OPENLDAP_BASENAME"; then
	SERVER_ID=`expr $OPENLDAP_SERVER_ID + 1`
	sed "s OPENLDAP_SERVER_ID $SERVER_ID g" /usr/local/etc/openldap/syncrepl.ldif | \
	    ldapmodify -Y EXTERNAL -H ldapi:/// -d $OPENLDAP_INIT_DEBUG_LEVEL || \
	    echo WARNING: failed importing /usr/local/etc/openldap/syncrepl.ldif
	unset SERVER_ID
    fi
    if test -s /etc/openldap/tls/server.crt -a -s /etc/openldap/tls/server.key; then
	cat /usr/local/etc/openldap/configure_tls.ldif | \
	    ldapadd -Y EXTERNAL -H ldapi:/// -d $OPENLDAP_INIT_DEBUG_LEVEL
    fi
    if test -s /etc/openldap/tls/cachain.pem; then
	cat /usr/local/etc/openldap/configure_ca.ldif | \
	    ldapadd -Y EXTERNAL -H ldapi:/// -d $OPENLDAP_INIT_DEBUG_LEVEL
    fi
    if test -s /etc/openldap/tls/dhparam.pem; then
	cat /usr/local/etc/openldap/configure_dh.ldif | \
	    ldapadd -Y EXTERNAL -H ldapi:/// -d $OPENLDAP_INIT_DEBUG_LEVEL
    fi
    if $OPENLDAP_FULL_INIT; then
	BLUEMIND_SA_PASSWORD_HASH=$(slappasswd -s "$OPENLDAP_BLUEMIND_PASSWORD")
	LEMONLDAP_SA_PASSWORD_HASH=$(slappasswd -s "$OPENLDAP_LEMONLDAP_PASSWORD")
	LEMONLDAP_SESSIONS_SA_PASSWORD_HASH=$(slappasswd -s "$OPENLDAP_LEMONLDAP_SESSIONS_PASSWORD")
	NEXTCLOUD_SA_PASSWORD_HASH=$(slappasswd -s "$OPENLDAP_NEXTCLOUD_PASSWORD")
	test -z "$OPENLDAP_ORG_SHORT" && OPENLDAP_ORG_SHORT=`echo "$OPENLDAP_ROOT_DOMAIN" | cut -d. -f1`
	OPENLDAP_SSO_CLIENT_SA_PASSWORD_HASH=$(slappasswd -s "$OPENLDAP_SSO_CLIENT_PASSWORD")
	ROCKET_SA_PASSWORD_HASH=$(slappasswd -s "$OPENLDAP_ROCKET_PASSWORD")
	SYNCREPL_SA_PASSWORD_HASH=$(slappasswd -s "$OPENLDAP_SYNCREPL_PASSWORD")
	VHOST_EXTERNAL_HTTPS_MAINT='"vhostHttps":"1","vhostPort":-1,"vhostMaintenance":0'
	if test "$OPENLDAP_LEMONLDAP_HTTPS"; then
	    OPENLDAP_LEMONLDAP_HTTPS=1
	    OPENLDAP_LEMONLDAP_PROTO=https
	    LEMONLDAP_PORT=443
	    VHOST_HTTPS_MAINT='"vhostHttps":-1,"vhostPort":-1,"vhostMaintenance":0'
	    VHOST_HTTPS_ON='"vhostHttps":1,"vhostPort":-1'
	    VHOST_HTTPS_OFF='"vhostHttps":-1,"vhostPort":-1'
	else
	    OPENLDAP_LEMONLDAP_HTTPS=0
	    OPENLDAP_LEMONLDAP_PROTO=http
	    LEMONLDAP_PORT=80
	    VHOST_HTTPS_MAINT='"vhostMaintenance":0'
	    VHOST_HTTPS_ON=
	    VHOST_HTTPS_OFF=
	fi
	DC_PREFIX=$(echo "${OPENLDAP_ROOT_DN_SUFFIX}" | grep -Po "(?<=^dc\=)[\w\d]+")
	OPENLDAP_ORG_SHORT=`echo "$OPENLDAP_ORG_SHORT" | sed 's| ||g'`
	if test -x /usr/local/bin/genrsa; then
	    if test "${OPENLDAP_LEMON_SAML_ENC_PRIVATE_KEY}" = x509data; then
		eval `/usr/local/bin/genrsa`
		if test "$RSA_PRIVATE"; then
		    OPENLDAP_LEMON_SAML_ENC_PRIVATE_KEY="${RSA_PRIVATE}"
		fi
		if test "$RSA_PUBLIC"; then
		    OPENLDAP_LEMON_SAML_ENC_PUBLIC_KEY="${RSA_PUBLIC}"
		fi
	    fi
	    if test "${OPENLDAP_LEMON_SAML_SIG_PRIVATE_KEY}" = x509data; then
		eval `/usr/local/bin/genrsa`
		if test "$RSA_PRIVATE"; then
		    OPENLDAP_LEMON_SAML_SIG_PRIVATE_KEY="${RSA_PRIVATE}"
		fi
		if test "$RSA_PUBLIC"; then
		    OPENLDAP_LEMON_SAML_SIG_PUBLIC_KEY="${RSA_PUBLIC}"
		fi
	    fi
	    unset RSA_PUBLIC RSA_PRIVATE
	fi
	SAML_ENC_PUB=$(echo -en "{samlServicePublicKeyEnc}$OPENLDAP_LEMON_SAML_ENC_PUBLIC_KEY" | base64 -w 0)
	SAML_ENC_PRIV=$(echo -en "{samlServicePrivateKeyEnc}$OPENLDAP_LEMON_SAML_ENC_PRIVATE_KEY" | base64 -w 0)
	SAML_SIG_PUB=$(echo -en "{samlServicePublicKeySig}$OPENLDAP_LEMON_SAML_SIG_PUBLIC_KEY" | base64 -w 0)
	SAML_SIG_PRIV=$(echo -en "{samlServicePrivateKeySig}$OPENLDAP_LEMON_SAML_SIG_PRIVATE_KEY" | base64 -w 0)
	sed -e "s OPENLDAP_SUFFIX $OPENLDAP_ROOT_DN_SUFFIX g" \
	    -e "s BLUEMIND_SA_PASSWORD_HASH $BLUEMIND_SA_PASSWORD_HASH g" \
	    -e "s FIRST_PART $DC_PREFIX g" \
	    -e "s HTTP_PORT $OPENLDAP_LEMON_HTTP_PORT g" \
	    -e "s|JENKINS_SAML_SIGNING_CERTIFICATE|$OPENLDAP_JENKINS_SAML_SIGNING_CERTIFICATE|g" \
	    -e "s|JENKINS_SAML_ENCRYPTION_CERTIFICATE|$OPENLDAP_JENKINS_SAML_ENCRYPTION_CERTIFICATE|g" \
	    -e "s LEMONLDAP_HTTPS $OPENLDAP_LEMONLDAP_HTTPS g" \
	    -e "s LEMONLDAP_PORT $LEMONLDAP_PORT g" \
	    -e "s LEMONLDAP_PROTO $OPENLDAP_LEMONLDAP_PROTO g" \
	    -e "s~LEMONLDAP_PASSWORD~$OPENLDAP_LEMONLDAP_PASSWORD~g" \
	    -e "s LEMONLDAP_SA_PASSWORD_HASH $LEMONLDAP_SA_PASSWORD_HASH g" \
	    -e "s~LEMONSESSIONS_PASSWORD~$OPENLDAP_LEMONLDAP_SESSIONS_PASSWORD~g" \
	    -e "s NEXTCLOUD_SA_PASSWORD_HASH $NEXTCLOUD_SA_PASSWORD_HASH g" \
	    -e "s OPENLDAP_DOMAIN $OPENLDAP_ROOT_DOMAIN g" \
	    -e "s OPENLDAP_HOST $OPENLDAP_HOST_ENDPOINT g" \
	    -e "s OPENLDAP_PORT $OPENLDAP_BIND_LDAP_PORT g" \
	    -e "s OPENLDAP_PROTO ldap g" \
	    -e "s OPENLDAP_SMTP $OPENLDAP_SMTP_SERVER g" \
	    -e "s|ORG_SHORT|$OPENLDAP_ORG_SHORT|g" \
	    -e "s ROCKET_SA_PASSWORD_HASH $ROCKET_SA_PASSWORD_HASH g" \
	    -e "s VHOST_EXTERNAL_HTTPS_MAINT $VHOST_EXTERNAL_HTTPS_MAINT g" \
	    -e "s VHOST_HTTPS_MAINT $VHOST_HTTPS_MAINT g" \
	    -e "s VHOST_HTTPS_ON $VHOST_HTTPS_ON g" \
	    -e "s VHOST_HTTPS_OFF $VHOST_HTTPS_OFF g" \
	    -e "s|SAML_ENC_PUB_KEY|$SAML_ENC_PUB|g" \
	    -e "s|SAML_ENC_PRIV_KEY|$SAML_ENC_PRIV|g" \
	    -e "s|SAML_SIG_PUB_KEY|$SAML_SIG_PUB|g" \
	    -e "s|SAML_SIG_PRIV_KEY|$SAML_SIG_PRIV|g" \
	    -e "s SESSIONS_SA_PASSWORD_HASH $LEMONLDAP_SESSIONS_SA_PASSWORD_HASH g" \
	    -e "s SSO_CLIENT_SA_PASSWORD_HASH $OPENLDAP_SSO_CLIENT_SA_PASSWORD_HASH g" \
	    -e "s SYNCREPL_SA_PASSWORD_HASH $SYNCREPL_SA_PASSWORD_HASH g" \
	    -e "s WSWEET_SA_PASSWORD_HASH $WSWEET_SA_PASSWORD_HASH g" usr/local/etc/openldap/base.ldif | \
	    ldapadd -x -H ldap://localhost:$OPENLDAP_BIND_LDAP_PORT/ \
		-D "$OPENLDAP_ROOT_DN_PREFIX,$OPENLDAP_ROOT_DN_SUFFIX" -w "$OPENLDAP_ROOT_PASSWORD"
	if test "$OPENLDAP_DEMO_PASSWORD"; then
	    DEMO_SA_PASSWORD_HASH=$(slappasswd -s "$OPENLDAP_DEMO_PASSWORD")
	    sed -e "s OPENLDAP_SUFFIX $OPENLDAP_ROOT_DN_SUFFIX g" -e "s|LDAP_DOMAIN|$OPENLDAP_ROOT_DOMAIN|g" \
		-e "s OPENLDAP_DEMO_PASSWORD_HASH $DEMO_SA_PASSWORD_HASH g" usr/local/etc/openldap/demo.ldif | \
		ldapadd -x -H ldap://localhost:$OPENLDAP_BIND_LDAP_PORT/ \
		    -D "$OPENLDAP_ROOT_DN_PREFIX,$OPENLDAP_ROOT_DN_SUFFIX" -w "$OPENLDAP_ROOT_PASSWORD"
	    unset DEMO_SA_PASSWORD_HASH
	elif test "$OPENLDAP_GLOBAL_ADMIN_PASSWORD"; then
	    GLOBAL_ADMIN_SA_PASSWORD_HASH=$(slappasswd -s "$OPENLDAP_GLOBAL_ADMIN_PASSWORD")
	    sed -e "s OPENLDAP_SUFFIX $OPENLDAP_ROOT_DN_SUFFIX g" -e "s|LDAP_DOMAIN|$OPENLDAP_ROOT_DOMAIN|g" \
		-e "s OPENLDAP_GLOBAL_ADMIN_PASSWORD_HASH $GLOBAL_ADMIN_SA_PASSWORD_HASH g" usr/local/etc/openldap/prod.ldif | \
		ldapadd -x -H ldap://localhost:$OPENLDAP_BIND_LDAP_PORT/ \
		    -D "$OPENLDAP_ROOT_DN_PREFIX,$OPENLDAP_ROOT_DN_SUFFIX" -w "$OPENLDAP_ROOT_PASSWORD"
	    unset GLOBAL_ADMIN_SA_PASSWORD_HASH
	fi
	unset BLUEMIND_SA_PASSWORD_HASH NEXTCLOUD_SA_PASSWORD_HASH
	unset LEMONLDAP_SA_PASSWORD_HASH LEMONLDAP_SESSIONS_SA_PASSWORD_HASH
	unset OPENLDAP_SSO_CLIENT_SA_PASSWORD_HASH
	unset ROCKET_SA_PASSWORD_HASH SYNCREPL_SA_PASSWORD_HASH
	unset SAML_ENC_PUB SAML_ENC_PRIV SAML_SIG_PUB SAML_SIG_PRIV
	unset OPENLDAP_LEMONLDAP_HTTPS LEMONLDAP_PORT OPENLDAP_LEMONLDAP_PROTO
	unset VHOST_HTTPS_MAINT VHOST_HTTPS_ON VHOST_HTTPS_OFF
    fi
    stop_ldapi
    LOG=`slaptest 2>&1`
    CHECKSUM_ERR=$(echo "$LOG" | grep -Po "(?<=ldif_read_file: checksum error on \").+(?=\")")
    for err in $CHECKSUM_ERR
    do
	echo "The file $err has a checksum error. Ensure that this file was not edited manually, or re-calculate its checksum."
    done >&2
    date +%s >/etc/openldap/CONFIGURED
    unset CHECKSUM_ERR DC_PREFIX OPENLDAP_ORG_SHORT OPENLDAP_ROOT_PASSWORD_HASH WSWEET_SA_PASSWORD_HASH
fi

APPLY_VERSIONS=`list_elligible_patches`
if test "$APPLY_VERSIONS"; then
    start_with_ldapi
    FINE=true
    AUTHPROXY_SA_PASSWORD_HASH=$(slappasswd -s "$OPENLDAP_AUTHPROXY_PASSWORD")
    CODIMD_SA_PASSWORD_HASH=$(slappasswd -s "$OPENLDAP_CODIMD_PASSWORD")
    DOKUWIKI_SA_PASSWORD_HASH=$(slappasswd -s "$OPENLDAP_DOKUWIKI_PASSWORD")
    FUSION_SA_PASSWORD_HASH=$(slappasswd -s "$OPENLDAP_FUSION_PASSWORD")
    MONITOR_SA_PASSWORD_HASH=$(slappasswd -s "$OPENLDAP_MONITOR_PASSWORD")
    SSP_SA_PASSWORD_HASH=$(slappasswd -s "$OPENLDAP_SSP_PASSWORD")
    MEDIAWIKI_SA_PASSWORD_HASH=$(slappasswd -s "$OPENLDAP_MEDIAWIKI_PASSWORD")
    WEKAN_SA_PASSWORD_HASH=$(slappasswd -s "$OPENLDAP_WEKAN_PASSWORD")
    WHITEPAGES_SA_PASSWORD_HASH=$(slappasswd -s "$OPENLDAP_WHITEPAGES_PASSWORD")
    for TARGET in $APPLY_VERSIONS
    do
	ls /usr/local/etc/openldap/config-updates/$TARGET/cn=config/*.ldif 2>/dev/null | while read ldif
	    do
		sed "s OPENLDAP_SUFFIX $OPENLDAP_ROOT_DN_SUFFIX g" $ldif | \
		    ldapmodify -Y EXTERNAL -H ldapi:/// -d $OPENLDAP_INIT_DEBUG_LEVEL
		if test $? -ne 0; then
		    echo WARNING: failed importing $ldif
		    FINE=false
		    break
		fi
	    done
	if $FINE; then
	    ls /usr/local/etc/openldap/config-updates/$TARGET/schemas/*.ldif 2>/dev/null | while read ldif
		do
		    sed "s OPENLDAP_SUFFIX $OPENLDAP_ROOT_DN_SUFFIX g" $ldif | \
			ldapadd -Y EXTERNAL -H ldapi:/// -d $OPENLDAP_INIT_DEBUG_LEVEL
		    if test $? -ne 0; then
			echo WARNING: failed importing $ldif
			FINE=false
			break
		    fi
		done
	fi
	if $OPENLDAP_FULL_INIT; then
	    if $FINE; then
		ls /usr/local/etc/openldap/config-updates/$TARGET/main/*.ldif 2>/dev/null | while read ldif
		    do
			sed -e "s OPENLDAP_SUFFIX $OPENLDAP_ROOT_DN_SUFFIX g" \
			    -e "s AUTHPROXY_SA_PASSWORD_HASH $AUTHPROXY_SA_PASSWORD_HASH g" \
			    -e "s CODIMD_SA_PASSWORD_HASH $CODIMD_SA_PASSWORD_HASH g" \
			    -e "s DOKUWIKI_SA_PASSWORD_HASH $DOKUWIKI_SA_PASSWORD_HASH g" \
			    -e "s MEDIAWIKI_SA_PASSWORD_HASH $MEDIAWIKI_SA_PASSWORD_HASH g" \
			    -e "s MONITOR_SA_PASSWORD_HASH $MONITOR_SA_PASSWORD_HASH g" \
			    -e "s SSP_SA_PASSWORD_HASH $SSP_SA_PASSWORD_HASH g" \
			    -e "s WEKAN_SA_PASSWORD_HASH $WEKAN_SA_PASSWORD_HASH g" \
			    -e "s WHITEPAGES_SA_PASSWORD_HASH $WHITEPAGES_SA_PASSWORD_HASH g" $ldif | \
			    ldapadd -x -H ldap://localhost:$OPENLDAP_BIND_LDAP_PORT/ \
				-D "$OPENLDAP_ROOT_DN_PREFIX,$OPENLDAP_ROOT_DN_SUFFIX" -w "$OPENLDAP_ROOT_PASSWORD"
			if test $? -ne 0; then
			    echo WARNING: failed importing $ldif
			    FINE=false
			    break
			fi
		    done
	    fi
	    if $FINE; then
		ls /usr/local/etc/openldap/config-updates/$TARGET/scripts/*.sh 2>/dev/null | while read fix
		    do
			if ! $fix; then
			    echo WARNING: failed applying "$fix"
			    FINE=false
			    break
			fi
		    done
	    fi
	    if $FINE; then
		GOSA_ACL_ROLE=`echo -n "cn=fusion-admin,ou=aclroles,$OPENLDAP_ROOT_DN_SUFFIX" | base64 -w0`
		if test "$OPENLDAP_DEMO_PASSWORD"; then
		    GOSA_ACL_USER=`echo -n "cn=demoone,ou=users,$OPENLDAP_ROOT_DN_SUFFIX" | base64 -w0`
		else
		    GOSA_ACL_USER=`echo -n "cn=admin0,ou=users,$OPENLDAP_ROOT_DN_SUFFIX" | base64 -w0`
		fi
		ls /usr/local/etc/openldap/config-updates/$TARGET/patch/*.ldif 2>/dev/null | while read ldif
		    do
			sed -e "s OPENLDAP_SUFFIX $OPENLDAP_ROOT_DN_SUFFIX g" \
			    -e "s FUSION_SA_PASSWORD_HASH $FUSION_SA_PASSWORD_HASH g" \
			    -e "s GOSA_ACL_USER $GOSA_ACL_USER g" \
			    -e "s GOSA_ACL_ROLE $GOSA_ACL_ROLE g" $ldif | \
			    ldapmodify -x -H ldap://localhost:$OPENLDAP_BIND_LDAP_PORT/ \
				-D "$OPENLDAP_ROOT_DN_PREFIX,$OPENLDAP_ROOT_DN_SUFFIX" -w "$OPENLDAP_ROOT_PASSWORD"
			if test $? -ne 0; then
			    echo WARNING: failed importing $ldif
			    FINE=false
			    break
			fi
		    done
		unset GOSA_ACL_ROLE GOSA_ACL_USER
	    fi
	fi
	if $FINE; then
	    echo $TARGET >/etc/openldap/VERSION
	elif test "$CRASH_ON_FAILED_UPDATES"; then
	    echo CRITICAL: configuration update failed >&2
	    echo bailing out, as CRASH_ON_FAILED_UPDATES was set >&2
	    exit 1
	else
	    echo WARNING: configuration update failed >&2
	    echo stop applying patches, starting slapd >&2
	    echo NOTICE: define CRASH_ON_FAILED_UPDATES to force container shutdown on such failures
	    echo proper deploymentconfig should then rollback to previous image
	fi
    done
    unset CODIMD_SA_PASSWORD_HASH FINE FUSION_SA_PASSWORD_HASH WHITEPAGES_SA_PASSWORD_HASH \
	MONITOR_SA_PASSWORD_HASH SSP_SA_PASSWORD_HASH MEDIAWIKI_SA_PASSWORD_HASH WEKAN_SA_PASSWORD_HASH \
	AUTHPROXY_SA_PASSWORD_HASH DOKUWIKI_SA_PASSWORD_HASH
    stop_ldapi
fi

if test "$OPENLDAP_BASENAME"; then
    MISSING=`list_missing_replicates`
    if test "$MISSING"; then
	start_with_ldapi
	if ! ls /etc/openldap/slapd.d/cn=config/olcDatabase={2}hdb/ 2>/dev/null | grep syncprov >/dev/null; then
	    cat /usr/local/etc/openldap/configure_syncrepl.ldif |
		ldapadd -Y EXTERNAL -H ldapi:/// -d $OPENLDAP_INIT_DEBUG_LEVEL || \
		echo WARNING: failed loading syncrepl overlay
	    SERVER_ID=`expr $OPENLDAP_SERVER_ID + 1`
	    sed "s OPENLDAP_SERVER_ID $SERVER_ID g" /usr/local/etc/openldap/syncrepl.ldif | \
		ldapmodify -Y EXTERNAL -H ldapi:/// -d $OPENLDAP_INIT_DEBUG_LEVEL || \
		echo WARNING: failed importing $ldif
	fi
	for add in $MISSING
	do
	    echo NOTICE: $OPENLDAP_BASENAME-$add not yet configured as syncrepl remote, adding it now
	    SERVER_ID=`expr $add + 1`
	    sed -e "s OPENLDAP_SUFFIX $OPENLDAP_ROOT_DN_SUFFIX g" \
	        -e "s CLUSTER_DOMAIN $OPENLDAP_STATEFULSET_NAME g" \
		-e "s LDAP_PORT $OPENLDAP_BIND_LDAP_PORT g" \
		-e "s LDAP_PROTO ldap g" -e "s NID $SERVER_ID g" -e "s RID $add g" \
		-e "s|OPENLDAP_SYNCREPL_PASSWORD|$OPENLDAP_SYNCREPL_PASSWORD|g" \
		-e "s BASENAME $OPENLDAP_BASENAME g" /usr/local/etc/openldap/syncrepl_repl.ldif | \
		ldapadd -Y EXTERNAL -H ldapi:/// -d $OPENLDAP_INIT_DEBUG_LEVEL
	    if test $? -eq 0; then
		echo $OPENLDAP_BASENAME-$add:`date +%s` >>/etc/openldap/.repl-configured
	    else
		echo WARNING: failed initializing replication with $OPENLDAP_BASENAME-$add
	    fi
	done
	if test -s /etc/openldap/.repl-configured -a \! -s /etc/openldap/.repl-mirror; then
	    cat /usr/local/etc/openldap/syncrepl_mirror.ldif | \
		ldapmodify -Y EXTERNAL -H ldapi:/// -d $OPENLDAP_INIT_DEBUG_LEVEL && \
		date >/etc/openldap/.repl-mirror || \
		echo WARNING: failed importing /usr/local/etc/openldap/syncrepl_mirror.ldif
	fi
	stop_ldapi
    fi
    echo Running multi-master cluster composed from:
    (
	echo $OPENLDAP_BASENAME-$OPENLDAP_SERVER_ID
        cat /etc/openldap/.repl-configured 2>/dev/null
    ) | sort | sed 's|^\(.*\)$|  - \1|'
    unset MISSING OPENLDAP_BASENAME SERVER_ID
else
    cat <<EOF >&2
WARNING: running standalone OpenLDAP server is not recommended for production
         consider setting up some kind of replication. This image offers with
	 OpenShift-compliant multi-master support.
EOF
fi

unset APPLY_VERSIONS OPENLDAP_BLUEMIND_PASSWORD OPENLDAP_DEMO_PASSWORD OPENLDAP_FULL_INIT OPENLDAP_GLOBAL_ADMIN_PASSWORD OPENLDAP_MONITOR_PASSWORD \
    OPENLDAP_HTTP_PORT OPENLDAP_HOST_ENDPOINT OPENLDAP_HOSTNAME OPENLDAP_JENKINS_SAML_SIGNING_CERTIFICATE OPENLDAP_JENKINS_SAML_ENCRYPTION_CERTIFICATE \
    OPENLDAP_LEMON_SAML_ENC_PUBLIC_KEY OPENLDAP_LEMON_SAML_ENC_PRIVATE_KEY OPENLDAP_LEMON_SAML_SIG_PUBLIC_KEY OPENLDAP_LEMON_SAML_SIG_PRIVATE_KEY \
    OPENLDAP_LEMONLDAP_PASSWORD OPENLDAP_LEMONLDAP_SESSIONS_PASSWORD OPENLDAP_NEXTCLOUD_PASSWORD OPENLDAP_ROCKET_PASSWORD OPENLDAP_ROOT_DN_PREFIX \
    OPENLDAP_ROOT_DN_SUFFIX OPENLDAP_ROOT_DOMAIN OPENLDAP_ROOT_PASSWORD OPENLDAP_SERVER_ID OPENLDAP_SMTP_SERVER OPENLDAP_SSP_PASSWORD OPENLDAP_INIT_DEBUG_LEVEL \
    OPENLDAP_SSO_CLIENT_PASSWORD OPENLDAP_SYNCREPL_PASSWORD OPENLDAP_WHITEPAGES_PASSWORD OPENLDAP_WSWEET_PASSWORD VERSION OPENLDAP_MEDIAWIKI_PASSWORD \
    OPENLDAP_CODIMD_PASSWORD OPENLDAP_WEKAN_PASSWORD OPENLDAP_DOKUWIKI_PASSWORD OPENLDAP_AUTHPROXY_PASSWORD
if test "$DEBUG"; then
    exec slapd -h "ldapi:/// ldap://:$OPENLDAP_BIND_LDAP_PORT/ ldaps://:$OPENLDAP_BIND_LDAPS_PORT/" -d $OPENLDAP_DEBUG_LEVEL
else
    exec slapd -h "ldap://:$OPENLDAP_BIND_LDAP_PORT/ ldaps://:$OPENLDAP_BIND_LDAPS_PORT/" -d $OPENLDAP_DEBUG_LEVEL
fi
