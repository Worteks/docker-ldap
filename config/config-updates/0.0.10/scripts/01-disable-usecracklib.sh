#!/bin/sh

# - In /etc/openldap/check_password.conf change "#useCracklib 1" to "useCracklib 0"

sed 's/\#useCracklib 1/useCracklib 0/' /etc/openldap/check_password.conf > /etc/openldap/check_password.conf2
mv /etc/openldap/check_password.conf2 /etc/openldap/check_password.conf

ret=$?
exit $ret
