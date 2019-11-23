#!/bin/sh

# - Lists core-x objects from ou=wsweet,ou=configs
# 	and add new attribute description with profilesList containing a default profile.
# - List users objects from ou=users and assign 'default' as profileId to each of them

OPENLDAP_BIND_LDAP_PORT=${OPENLDAP_BIND_LDAP_PORT:-389}
OPENLDAP_ROOT_DOMAIN=${OPENLDAP_ROOT_DOMAIN:-'demo.local'}
OPENLDAP_SYNCREPL_PASSWORD=${OPENLDAP_SYNCREPL_PASSWORD:-secret}
OPENLDAP_WSWEET_PASSWORD=${OPENLDAP_WSWEET_PASSWORD:-secret}
if test -z "$OPENLDAP_ROOT_DN_SUFFIX"; then
    OPENLDAP_ROOT_DN_SUFFIX=`echo "dc=$OPENLDAP_ROOT_DOMAIN" | sed 's|\.|,dc=|g'`
fi

LADDR="ldap://127.0.0.1:$OPENLDAP_BIND_LDAP_PORT/"
LBRU="cn=syncrepl,ou=services,$OPENLDAP_ROOT_DN_SUFFIX"
LBRPW="$OPENLDAP_SYNCREPL_PASSWORD"
LBWU="cn=wsweet,ou=services,$OPENLDAP_ROOT_DN_SUFFIX"
LBWPW="$OPENLDAP_WSWEET_PASSWORD"
LBCS="ou=wsweet,ou=config,$OPENLDAP_ROOT_DN_SUFFIX"
LBUS="ou=users,$OPENLDAP_ROOT_DN_SUFFIX"

# Add description to all core-x
ldapsearch -x -H $LADDR -D "$LBRU" -w "$LBRPW" -b "$LBCS" "(&(objectClass=applicationProcess)(cn=core-*))" cn \
	| awk '/^dn: /' | sed 's|dn: ||' \
	| while read objectname
		do
			cat <<EOLDAP | ldapmodify -x -H $LADDR -D "$LBWU" -w "$LBWPW"
dn: $objectname
changetype: modify
add: description
description: {profilesList}{"profiles":[{"id":"default","name":"Internal","defaultPwdPolicy":"cn=autoLockout,ou=policies,OPENLDAP_SUFFIX","groups":["cn=All,ou=groups,dc=OPENLDAP_SUFFIX"],"defaultMailQuota":8589934592,"maxMailQuota":17179869184,"defaultFileShareQuota":8589934592,"maxFileShareQuota":17179869184}]}
EOLDAP
		done

# Add attribute profileId => "default" to all existing users
ldapsearch -x -H $LADDR -D "$LBRU" -w "$LBRPW" -b "$LBUS" "(objectClass=sweetUser)" cn \
	| awk '/^dn: /' | sed 's|dn: ||' \
	| while read objectname
		do
			cat <<EOLDAP | ldapmodify -x -H $LADDR -D "$LBWU" -w "$LBWPW"
dn: $objectname
changetype: modify
add: profileId
profileId: default
EOLDAP
		done

ret=$?
unset LADDR LBRU LBRPW LBWU LBWPW LBS

exit $ret
