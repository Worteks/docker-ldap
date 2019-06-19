# SweetLDAP

TODO?: https://wiki.gnupg.org/LDAPKeyserver

Wsweet OpenLDAP image, customized for StatefulSet auto-configuration, providing
with schema update capabilities, embedding Wsweet custom schemas.

WARNING: updates currently do not support LemonLDAP-NG site re-configuration.
Whenever a service or virtualhost is added or reconfigured, we would have to
update existing deployments configurations. FIXME / some llng cli magic may help
here.

Historically forked from openshift/openldap.

Build with:

```
$ make build
```

If you want to try it quickly on your local machine after make, run:

```
$ make run
```

Start Demo or Cluster in OpenShift:

```
$ make ocdemo
$ make ocprod
```

Cleanup OpenShift assets:

```
$ make ocpurge
```

Schema Sources
---------------

 - NextCloud cloudQuota: https://github.com/ValV/postfix-dovecot-ldap-schema/blob/master/postfix-dovecot.schema
 - BlueMind mailQuota: http://www.openldap.org/lists/openldap-technical/201007/msg00001.html
 - sshPubKey: https://github.com/AndriiGrytsenko/openssh-ldap-publickey/blob/master/misc/openssh-lpk-openldap.schema
 - FusionDirectory: https://github.com/fusiondirectory/fusiondirectory/tree/master/contrib/openldap
 - Qmail / unused: https://github.com/amery/qmail/blob/master/qmail.schema
 - Postfix / unused: https://github.com/ValV/postfix-dovecot-ldap-schema/blob/master/postfix-dovecot.schema

Custom OIDs
------------

|  attribute OID                   | Name                                          | Description               | Equality           | Substring                    | Syntax                               | Single-Value | Introduced In | Last Patched |
| :------------------------------- | --------------------------------------------- | ------------------------- | ------------------ | ---------------------------- | ------------------------------------ | ------------ | ------------- | ------------ |
| `0.9.2342.19200300.100.1.3`      | `mail` `rfc822Mailbox`                        | RFC1274: RFC822 Mailbox   | caseIgnoreIA5Match | caseIgnoreIA5SubstringsMatch | `1.3.6.1.4.1.1466.115.121.1.26{256}` | Yes          | `0.0.0`       | `0.0.7`      |
| `1.3.6.1.4.1.7914.1.2.1.5`       | `mailQuota` `mailQuotaSize`                   | Mail Storage User Quota   | caseExactMatch     | caseIgnoreSubstringsMatch    | `1.3.6.1.4.1.1466.115.121.1.44`      | Yes          | `0.0.0`       |              |
| `1.3.6.1.4.1.24552.500.1.1.1.13` | `sshPublicKey`                                | OpenSSH Public key        | octetStringMatch   |                              | `1.3.6.1.4.1.1466.115.121.1.40`      | No           | `0.0.0`       |              |
| `1.3.6.1.4.1.39430.1.1.1`        | `cloudQuota` `ownCloudQuota` `nextCloudQuota` | Cloud Storage User Quota  | caseExactMatch     | caseIgnoreSubstringsMatch    | `1.3.6.1.4.1.1466.115.121.1.44`      | Yes          | `0.0.0`       |              |
| `1.3.6.1.4.1.39430.1.1.3`        | `mailBackupAddress`                           | User Backup Email Address | caseIgnoreIA5Match | caseIgnoreIA5SubstringsMatch | `1.3.6.1.4.1.1466.115.121.1.26{256}` | Yes          | `0.0.7`       |              |
| `1.3.6.1.4.1.39430.1.1.4`        | `mailAlternateAddress`                        | Email Alias               | caseIgnoreIA5Match | caseIgnoreIA5SubstringsMatch | `1.3.6.1.4.1.1466.115.121.1.26{256}` | No           | `0.0.7`       |              |
| `1.3.6.1.4.1.39430.1.1.5`        | `usedMailQuota`                               | Used Cloud Storage        | caseExactMatch     | caseIgnoreSubstringsMatch    | `1.3.6.1.4.1.1466.115.121.1.44`      | Yes          | `0.0.10`      |              |
| `1.3.6.1.4.1.39430.1.1.6`        | `usedCloudQuota`                              | Used Mail Storage         | caseExactMatch     | caseIgnoreSubstringsMatch    | `1.3.6.1.4.1.1466.115.121.1.44`      | Yes          | `0.0.10`      |              |
| `1.3.6.1.4.1.39430.1.1.7`        | `profileId`                                   | Wsweet Profile Id         | caseIgnoreMatch    | caseIgnoreSubstringsMatch    | `1.3.6.1.4.1.1466.115.121.1.15{40}`  | Yes          | `0.0.10`      |              |

|  objectclass OID               | Name          | Must    | May                                                                                                                                 | Auxiliary | Introduced In | Last Patched |
| :----------------------------- | ------------- | ------- | ----------------------------------------------------------------------------------------------------------------------------------- | --------- | ------------- | ------------ |
| `1.3.6.1.4.1.10098.1.2.1.19.6` | `gosaAccount` | `cn`    |                                                                                                                                     | Yes       | `0.0.9`       |              |
| `1.3.6.1.4.1.39430.1.2.1`      | `sweetUser`   |         | `mailQuota` `nextCloudQuota` `sshPublicKey` `mailAlternateAddress` `mailBackupAddress` `usedMailQuota` `usedCloudQuota` `profileId` | Yes       | `0.0.0`       | `0.0.10`     |
| `1.3.6.1.4.1.39430.1.1.2`      | `sweetGroup`  | `mail`  | `mailAlternateAddress`                                                                                                              | Yes       | `0.0.0`       | `0.0.7`      |

Environment variables and volumes
----------------------------------

The image recognizes the following environment variables that you can set during
initialization by passing `-e VAR=VALUE` to the Docker `run` command.

|    Variable name                                |    Description                                | Default                                                             |
| :---------------------------------------------- | --------------------------------------------- | ------------------------------------------------------------------- |
|  `OPENLDAP_AUTHPROXY_PASSWORD`                  | OpenLDAP AuthProxy Password                   | `secret`                                                            |
|  `OPENLDAP_BIND_LDAP_PORT`                      | OpenLDAP Plaintext Bind Port                  | `389`                                                               |
|  `OPENLDAP_BIND_LDAPS_PORT`                     | OpenLDAP TLS Bind Port                        | `636`                                                               |
|  `OPENLDAP_BLUEMIND_PASSWORD`                   | OpenLDAP BlueMind Password                    | `secret`                                                            |
|  `OPENLDAP_CODIMD_PASSWORD`                     | OpenLDAP CodiMD Password                      | `secret`                                                            |
|  `OPENLDAP_DEBUG_LEVEL`                         | OpenLDAP Server Debug Level                   | `256`                                                               |
|  `OPENLDAP_DEMO_PASSWORD`                       | Password for OpenLDAP Demo Accounts           | unset, defining it toggles Demo Accounts creation                   |
|  `OPENLDAP_DOKUWIKI_PASSWORD`                   | OpenLDAP DokuWiki Password                    | `secret`                                                            |
|  `OPENLDAP_FUSION_PASSWORD`                     | OpenLDAP FusionDirectory Password             | `secret`                                                            |
|  `OPENLDAP_GLOBAL_ADMIN_PASSWORD`               | Password for OpenLDAP Global Admin            | unset, defining it toggles Global Admin and default groups creation |
|  `OPENLDAP_HOST_ENDPOINT`                       | OpenLDAP Endpoint configuring LemonLDAP       | `openldap`                                                          |
|  `OPENLDAP_HOSTNAME`                            | OpenLDAP Hostname - testing replication       | Container hostname                                                  |
|  `OPENLDAP_INIT_DEBUG_LEVEL`                    | OpenLDAP Server Bootstrap Debug Level         | `256`                                                               |
|  `OPENLDAP_JENKINS_SAML_SIGNING_CERTIFICATE`    | Jenkins/LemonLDAP SAML Signing Certificate    | `x509data`                                                          |
|  `OPENLDAP_JENKINS_SAML_ENCRYPTION_CERTIFICATE` | Jenkins/LemonLDAP SAML Encryption Certificate | `x509data`                                                          |
|  `OPENLDAP_LEMONLDAP_HTTPS`                     | LemonLDAP HTTPS Toggle                        | unset, defining it toggles HTTPS-related configuration              |
|  `OPENLDAP_LEMONLDAP_PASSWORD`                  | OpenLDAP LemonLDAP Password                   | `secret`                                                            |
|  `OPENLDAP_LEMONLDAP_SESSIONS_PASSWORD`         | OpenLDAP LemonLDAP Sessions Storage           | `secret`                                                            |
|  `OPENLDAP_LEMON_HTTP_PORT`                     | OpenLDAP LemonLDAP Reload HTTP Port           | `8080`                                                              |
|  `OPENLDAP_LEMON_SAML_ENC_PUBLIC_KEY`           | LemonLDAP SAML Encryption Public Key          | Generated on boot                                                   |
|  `OPENLDAP_LEMON_SAML_ENC_PRIVATE_KEY`          | LemonLDAP SAML Encryption Private Key         | Generated on boot                                                   |
|  `OPENLDAP_LEMON_SAML_SIG_PUBLIC_KEY`           | LemonLDAP SAML Signing Public Key             | Generated on boot                                                   |
|  `OPENLDAP_LEMON_SAML_SIG_PRIVATE_KEY`          | LemonLDAP SAML Signing Private Key            | Generated on boot                                                   |
|  `OPENLDAP_MEDIAWIKI_PASSWORD`                  | OpenLDAP MediaWiki Password                   | `secret`                                                            |
|  `OPENLDAP_MONITOR_PASSWORD`                    | OpenLDAP Monitor Password                     | `secret`                                                            |
|  `OPENLDAP_NEXTCLOUD_PASSWORD`                  | OpenLDAP NextCloud Password                   | `secret`                                                            |
|  `OPENLDAP_ORG_SHORT`                           | LemonLDAP Organization Name                   | Based on `OPENLDAP_ROOT_DOMAIN`, default produces `demo`            |
|  `OPENLDAP_ROCKET_PASSWORD`                     | OpenLDAP Rocket Password                      | `secret`                                                            |
|  `OPENLDAP_ROOT_DN_RREFIX`                      | OpenLDAP `olcRootDN` Prefix                   | `cn=admin`                                                          |
|  `OPENLDAP_ROOT_DN_SUFFIX`                      | OpenLDAP `olcSuffix` Suffix                   | seds `OPENLDAP_ROOT_DOMAIN`, default produces `dc=demo,dc=local`    |
|  `OPENLDAP_ROOT_DOMAIN`                         | Wsweet Endpoint Root Domain Name              | `demo.local`                                                        |
|  `OPENLDAP_ROOT_PASSWORD`                       | OpenLDAP `olcRootPW` Password                 | `secret`                                                            |
|  `OPENLDAP_SMTP_SERVER`                         | LemonLDAP SMTP relay                          | `smtp.demo.local`                                                   |
|  `OPENLDAP_SSO_CLIENT_PASSWORD`                 | OpenLDAP Generic SSO/SAML Password            | `secret`                                                            |
|  `OPENLDAP_SSP_CLIENT_PASSWORD`                 | OpenLDAP SelfServicePassword Password         | `secret`                                                            |
|  `OPENLDAP_STATEFULSET_NAME`                    | OpenLDAP StatefulSet Name - setting up repl   | `openldap`                                                          |
|  `OPENLDAP_SYNCREPL_PASSWORD`                   | OpenLDAP Syncrepl Password                    | `secret`                                                            |
|  `OPENLDAP_WEKAN_PASSWORD`                      | OpenLDAP Wekan Password                       | `secret`                                                            |
|  `OPENLDAP_WHITEPAGES_PASSWORD`                 | OpenLDAP WhitePages Password                  | `secret`                                                            |
|  `OPENLDAP_WSWEET_PASSWORD`                     | OpenLDAP Wsweet Password                      | `secret`                                                            |

The following table details the possible debug levels.

| Debug Level | Description                                   |
| ----------- | --------------------------------------------- |
| -1          | Enable all debugging                          |
|  0          | Enable no debugging                           |
|  1          | Trace function calls                          |
|  2          | Debug packet handling                         |
|  4          | Heavy trace debugging                         |
|  8          | Connection management                         |
|  16         | Log packets sent and recieved                 |
|  32         | Search filter processing                      |
|  64         | Configuration file processing                 |
|  128        | Access control list processing                |
|  256        | Stats log connections, operations and results |
|  512        | Stats log entries sent                        |
|  1024       | Log communication with shell backends         |
|  2048       | Log entry parsing debugging                   |

You can also set the following mount points by passing the `-v /host:/container` flag to Docker.

|  Volume mount point | Description                        |
| :------------------ | ---------------------------------- |
|  `/var/lib/ldap`    | OpenLDAP data directory            |
|  `/etc/openldap/`   | OpenLDAP configuration directory.  |

Cluster Auto Configuration
---------------------------

This image can be used setting up N-Way clusters.

It has been made with Kubernetes StatefulSets in mind, and would assume that
members from a cluster are named according to a deployment name and an
incremental numeric identifier. Assuming our statefulset is named `openldap` and
has `3` replicas, in the `sample` project, then the following DNS records would
eventually identify our cluster members:

 * openldap-0.openldap.sample.svc
 * openldap-1.openldap.sample.svc
 * openldap-2.openldap.sample.svc

Knowing this, containers started from our image would check for their hostname.
If we can match such a numeric identifier suffixing our hostname, then we would
try and detect other members, starting from `0` and incrementing a counter
until `ldapsearch` fails querying for an OpenLDAP service.

Having identified potentials members to join our cluster, our containers would
check for a `/etc/openldap/.repl-configured` file, which holds the list of
members we've already configured replication with. For every detected neighbor
missing in that list, we would add an `olcSyncRepl` entry to the hdb database.

This process has a critical implication: bootstrapping a cluster, using a Serial
deployment policy would be recommended, ensuring services start in an orderly
manner. The first node would boot and provision either the demo or production
initial dataset. Then the second one would setup replication against the first
one. And the third one, against the first and second nodes.

At which point, we would want to reboot the first member of our cluster, such
as it would detect the second and third nodes, setting up its replication.
And eventually, the second node, ensuring it would have a link replicating
data from the third node.

There is no easy way to know about a StatefulSet size from a Kubernetes
container point of view. DNS records for non-existing members of a cluster would
still resolve, there is no environment variable, the only way to know for sure
would be to use the OpenShift client querying its API. Although doing so would
imply adding +150-200M binary to our image, which doesn't make much sense.

Updating Schemas
-----------------

Updating existing databases can be done applying LDIFs while booting a new image.

In the `./config/config-updates` folder, we would find our first patches:

```
$ ls config/config-updates
0.0.1  0.0.2  0.0.3  ...  0.0.X
```

All OpenLDAP servers would have a file `/etc/openldap/VERSION`, marking which
patch was last applied, allowing us to update schemas refreshing our images.
Create your own version:

```
$ mkdir -p config/config-updates/0.0.42
```

Depending on what we'll want to update, we could create several folders in
there. Say we want to apply changes to the `cn=config` database, then we
would create a `cn=config` sub-directory. Those changes would be applied
*to all OpenLDAP members* of a cluster, as a first step applying a new version.

```
$ mkdir -p config/config-updates/0.0.42/cn=config
$ cat <<EOF >config/config-updates/0.0.42/cn=config/00-acl.ldif
dn: olcDatabase={2}hdb,cn=config
changetype: modify
replace: olcAccess
olcAccess: {0}to attrs=userPassword xxxx
EOF
```

The second step applying an update would be to load new schemas. Doing so, we
would create a `schemas` sub-directory. Schemas are loaded
*on all OpenLDAP members* of a cluster. Loading OpenLDAP main schemas, we could
link them out of `/etc/openldap/schemas`, instead of re-installing new copies:

```
$ mkdir -p config/config-updates/0.0.42/schemas
$ ln -sf /etc/openldap/schemas/nis.ldif config/config-updates/0.0.42/schemas/00-nis.ldif
```

Once our OpenLDAP configuration and schemas are up-to-date, we may want to apply
patches to our hdb databases. Those updates would only apply
*on the first OpenLDAP member* of a cluster, as they are meant to be replicated
and, as such, shouldn't be applied twice. We could store ldifs creating new
objects into a `main` sub-directory:

```
$ mkdir -p config/config-updates/0.0.42/main
$ cat <<EOF >config/config-updates/0.0.42/main/00-mediawiki.ldif
dn: cn=mediawiki,ou=services,OPENLDAP_SUFFIX
objectClass: top
objectClass: person
cn: mediawiki
description: Service Account for MediaWiki
sn: MediaWiki service account
userPassword: MEDIAWIKI_SA_PASSWORD_HASH
EOF
```

That being done, we could want to run a few shell scripts applying some logic
plain ldifs won't be able to offer:

```
$ mkdir -p config/config-updates/0.0.42/scripts
$ cat <<EOF >config/config-updates/0.0.42/scripts/00-do-something.sh
#!/bin/sh

ldapsearch -D cn=wsweet,ou=services,\$OPENLDAP_ROOT_DN .... | while read line
    do
	if test something; then
	    ldapmodify xxx
	fi
    done

exit \$?
EOF
$ chmod +x config/config-updates/0.0.42/scripts/00-do-something.sh
```

Finally, we may want to apply ldifs patching existing objects. A `patch`
sub-directory could be used:

```
$ mkdir -p config/config-updates/0.0.42/patch
$ cat <<EOF >config/config-updates/0.0.42/patch/00-ppolicy.ldf
dn: cn=autoLockout,ou=policies,OPENLDAP_SUFFIX
changetype: modify
replace: pwdSafeModify
pwdSafeModify: FALSE
EOF
```

Having installed all our ldifs, you'ld have noticed we used several placeholders
such as `OPENLDAP_SUFFIX`, or `MEDIAWIKI_SA_PASSWORD_HASH`. We would want to
check for their proper substitions with runtime variables:

```
$ vi ./config/run-openldap.sh
```
