#!/bin/sh

# Lists objects from ou=groups & ou=users matching (mail=*)
# Checks for multiple mail definitions
# Edits objects complying with mail single-value schema change,
# inserting mailAlternateAddresses migrating existing aliases

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
for directoryGroup in users groups
do
    LBS="ou=$directoryGroup,$OPENLDAP_ROOT_DN_SUFFIX"
    ldapsearch -x -H $LADDR -D "$LBRU" -w "$LBRPW" -b "$LBS" "(mail=*)" cn \
	| awk '/^dn: /' | sed 's|dn: ||' \
	| while read objectname
	    do
		eval ADD_ADDRESSES= FIRST_ADDRESS=
		for i in $(ldapsearch -x -H $LADDR -D "$LBRU" -w "$LBRPW" -b "$objectname" mail | awk '/^mail:/{print $2}')
		do
		    if test "$FIRST_ADDRESS"; then
			if test -z "$ADD_ADDRESSES"; then
			    ADD_ADDRESSES="mailAlternateAddress: $i"
			else
			    ADD_ADDRESSES="$ADD_ADDRESSES
mailAlternateAddress: $i"
			fi
		    else
			FIRST_ADDRESS="$i"
		    fi
		done
		if test "$ADD_ADDRESSES"; then
		    cat <<EOLDAP | ldapmodify -x -H $LADDR -D "$LBWU" -w "$LBWPW"
dn: $objectname
changetype: modify
replace: mail
mail: $FIRST_ADDRESS

dn: $objectname
changetype: modify
add: mailAlternateAddress
$ADD_ADDRESSES
EOLDAP
		fi
	    done
done

ret=$?
unset LADDR LBRU LBRPW LBWU LBWPW LBS

exit $ret
