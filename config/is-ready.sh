#!/bin/sh

OPENLDAP_ROOT_DOMAIN=${OPENLDAP_ROOT_DOMAIN:-'demo.local'}
OPENLDAP_WSWEET_PASSWORD=${OPENLDAP_WSWEET_PASSWORD:-secret}
if test -z "$OPENLDAP_ROOT_DN_SUFFIX"; then
    OPENLDAP_ROOT_DN_SUFFIX=`echo "dc=$OPENLDAP_ROOT_DOMAIN" | sed 's|\.|,dc=|g'`
fi
exec /usr/bin/ldapsearch \
    -H ldap://127.0.0.1:1389/ \
    -b "ou=policies,$OPENLDAP_ROOT_DN_SUFFIX" \
    -D "cn=wsweet,ou=services,$OPENLDAP_ROOT_DN_SUFFIX" \
    -w "$OPENLDAP_WSWEET_PASSWORD"
