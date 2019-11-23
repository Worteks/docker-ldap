#!/bin/sh

# Fixes NextCloud Quota for default users

LBWPW="${OPENLDAP_WSWEET_PASSWORD:-secret}"
OPENLDAP_BIND_LDAP_PORT=${OPENLDAP_BIND_LDAP_PORT:-389}
OPENLDAP_ROOT_DOMAIN=${OPENLDAP_ROOT_DOMAIN:-'demo.local'}
OPENLDAP_WSWEET_PASSWORD=${OPENLDAP_WSWEET_PASSWORD:-secret}
if test -z "$OPENLDAP_ROOT_DN_SUFFIX"; then
    OPENLDAP_ROOT_DN_SUFFIX=`echo "dc=$OPENLDAP_ROOT_DOMAIN" | sed 's|\.|,dc=|g'`
fi
LADDR="ldap://127.0.0.1:$OPENLDAP_BIND_LDAP_PORT/"
LBWU="cn=wsweet,ou=services,$OPENLDAP_ROOT_DN_SUFFIX"

if test "$OPENLDAP_GLOBAL_ADMIN_PASSWORD"; then
    cat <<EOLDAP | ldapmodify -x -H $LADDR -D "$LBWU" -w "$LBWPW"
dn: cn=admin0,ou=users,$OPENLDAP_ROOT_DN_SUFFIX
changetype: modify
replace: ownCloudQuota
ownCloudQuota: 1073741824
EOLDAP
else
    cat <<EOLDAP | ldapmodify -x -H $LADDR -D "$LBWU" -w "$LBWPW"
dn: cn=demoone,ou=users,$OPENLDAP_ROOT_DN_SUFFIX
changetype: modify
replace: ownCloudQuota
ownCloudQuota: 1073741824

dn: cn=demotoo,ou=users,$OPENLDAP_ROOT_DN_SUFFIX
changetype: modify
replace: ownCloudQuota
ownCloudQuota: 1073741824

dn: cn=demotri,ou=users,$OPENLDAP_ROOT_DN_SUFFIX
changetype: modify
replace: ownCloudQuota
ownCloudQuota: 1073741824
EOLDAP
fi

ret=$?
unset LADDR LBWU LBWPW

exit $ret
