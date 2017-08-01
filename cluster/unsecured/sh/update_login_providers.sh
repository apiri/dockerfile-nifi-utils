#!/bin/sh -ex

echo '!!! Updating login providers file...'

login_providers_file=${NIFI_HOME}/conf/login-identity-providers.xml
property_xpath='//loginIdentityProviders/provider/property'

edit_property() {
  property_name=$1
  property_value=$2

  xmlstarlet ed --inplace -u "${property_xpath}[@name='${property_name}']" -v "${property_value}" "${login_providers_file}"
}


# Remove comments to enable the ldap-provider
sed -i.bak -e '66d;96d' "${login_providers_file}"

edit_property 'Authentication Strategy' "SIMPLE"
edit_property 'Manager DN' 'cn=admin,dc=example,dc=org'
edit_property 'Manager Password' 'password'
edit_property 'TLS - Keystore' 'keystore'
edit_property 'TLS - Keystore Password' 'keystorepassword'
edit_property 'TLS - Keystore Type' 'keystoretype'
edit_property 'TLS - Truststore' 'truststore'
edit_property 'TLS - Truststore Password' 'truststorepassword'
edit_property 'TLS - Truststore Type' 'truststoretype'
edit_property 'TLS - Client Auth' 'clientauth'
edit_property 'TLS - Protocol' 'protocol'
edit_property 'TLS - Shutdown Gracefully' '10 secs'
edit_property 'Referral Strategy' 'FOLLOW'
edit_property 'Connect Timeout' '10 secs'
edit_property 'Read Timeout' '10 secs'
edit_property 'Url' 'ldap://ldap:389'
edit_property 'User Search Base' 'dc=example,dc=org'
edit_property 'User Search Filter' 'cn={0}'
edit_property 'Identity Strategy' 'USE_DN'
edit_property 'Authentication Expiration' '12 days'
