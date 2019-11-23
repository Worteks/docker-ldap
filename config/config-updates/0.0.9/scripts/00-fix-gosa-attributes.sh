#!/bin/sh

# Lists objects from ou=users & ou=groups matching (objectClass=sweetUser)
# and (objectClass=sweetGroup) respectively
# Adds gosaAccount, gosaMailAccount & organizationalPerson to sweetUsers,
# and gosaGroupOfNames to sweetGroup

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
    if test "$directoryGroup" = users; then
	ADDCLASS=gosaAccount
	FILTER="(objectClass=sweetUser)"
	GROUPOBJECT=
    else
	ADDCLASS=gosaGroupOfNames
	FILTER="(objectClass=sweetGroup)"
	GROUPOBJECT="-
add: gosaGroupObjects
gosaGroupObjects: [U]"
    fi
    ldapsearch -x -H $LADDR -D "$LBRU" -w "$LBRPW" -b "$LBS" "$FILTER" cn \
	| awk '/^dn: /' | sed 's|dn: ||' \
	| while read objectname
	    do
		if ! ldapsearch -x -H $LADDR -D "$LBRU" -w "$LBRPW" \
		    -b "$objectname" objectClass | grep "$ADDCLASS" \
		    >/dev/null; then
		    cat <<EOLDAP | ldapmodify -x -H $LADDR -D "$LBWU" -w "$LBWPW"
dn: $objectname
changetype: modify
add: objectClass
objectClass: $ADDCLASS
$GROUPOBJECT
EOLDAP
		fi
		if test "$ADDCLASS" = gosaAccount; then
		    for also in gosaMailAccount organizationalPerson
		    do
			if ! ldapsearch -x -H $LADDR -D "$LBRU" -w "$LBRPW" \
			    -b "$objectname" objectClass \
			    | grep "objectClass: $also" >/dev/null; then
			    cat <<EOLDAP | ldapmodify -x -H $LADDR -D "$LBWU" -w "$LBWPW"
dn: $objectname
changetype: modify
add: objectClass
objectClass: $also
EOLDAP
			fi
		    done
		fi
	    done
done

ret=$?
unset LADDR LBRU LBRPW LBWU LBWPW LBS

exit $ret
