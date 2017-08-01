#!/bin/bash -ex

# 1 - value to search for
# 2 - value to replace
prop_replace () {
  sed -i -e "s|^$1=.*$|$1=$2|"  ${nifi_props_file}
}

# NIFI_HOME is defined by an ENV command in the backing Dockerfile
nifi_props_file=${NIFI_HOME}/conf/nifi.properties

hostname=$(hostname)

prop_replace 'nifi.remote.input.host' "${hostname}"

if [ -n "${LDAP_AUTHENTICATION_STRATEGY}" ]; then
  . ${NIFI_BASE_DIR}/sh/update_login_providers.sh

  echo "Found that LDAP was set, updating properties for secure mode."
  sed -i -e 's|<property name="Initial Admin Identity"></property>|<property name="Initial Admin Identity">cn=admin,dc=example,dc=org</property>|'  ${NIFI_HOME}/conf/authorizers.xml

  echo "Requesting certificate with CSR."
  mkdir -p /opt/nifi/certs
  cd /opt/nifi/certs && /opt/nifi/nifi-toolkit-1.3.0/bin/tls-toolkit.sh client -t ${tls_token} -c nifi-ca

  # Disable HTTP and enable HTTPS
  prop_replace 'nifi.web.http.host' ""
  prop_replace 'nifi.web.http.port' ""

  prop_replace 'nifi.web.https.host' "${hostname}"
  prop_replace 'nifi.web.https.port' '8443'
  prop_replace 'nifi.remote.input.secure' 'true'
  prop_replace 'nifi.security.needClientAuth' 'WANT'
  prop_replace 'nifi.security.user.login.identity.provider' 'ldap-provider'

  # Setup keystore
  prop_replace 'nifi.security.keystore' '/opt/nifi/certs/keystore.jks'
  prop_replace 'nifi.security.keystoreType' 'JKS'
  prop_replace 'nifi.security.keystorePasswd' "$(cat /opt/nifi/certs/config.json | jq -r .keyStorePassword)"
  prop_replace 'nifi.security.keyPasswd' "$(cat /opt/nifi/certs/config.json | jq -r .keyPassword)"


  # Setup truststore
  prop_replace 'nifi.security.truststore' '/opt/nifi/certs/truststore.jks'
  prop_replace 'nifi.security.truststoreType' 'JKS'
  prop_replace 'nifi.security.truststorePasswd' "$(cat /opt/nifi/certs/config.json | jq -r .trustStorePassword)"

elif [ -n "${tls_token}" ]; then
  echo "Found that tls was set, updating properties for secure mode."

  echo "Requesting certificate with CSR."
  mkdir -p /opt/nifi/certs
  cd /opt/nifi/certs && /opt/nifi/nifi-toolkit-1.3.0/bin/tls-toolkit.sh client -t ${tls_token} -c nifi-ca

  sed -i -e 's|<property name="Initial Admin Identity"></property>|<property name="Initial Admin Identity">CN=InitialAdmin, OU=NIFI</property>|'  ${NIFI_HOME}/conf/authorizers.xml

  echo "My conf directory looks like the following: "
  cat ${NIFI_HOME}/conf/*

  # configure secure settings


  # Disable HTTP and enable HTTPS
  prop_replace 'nifi.web.http.host' ""
  prop_replace 'nifi.web.http.port' ""

  prop_replace 'nifi.web.https.host' "${hostname}"
  prop_replace 'nifi.web.https.port' '8443'
  prop_replace 'nifi.remote.input.secure' 'true'
  prop_replace 'nifi.cluster.protocol.is.secure' 'true'
  prop_replace 'nifi.security.needClientAuth' 'true'

  # Setup keystore
  prop_replace 'nifi.security.keystore' '/opt/nifi/certs/keystore.jks'
  prop_replace 'nifi.security.keystoreType' 'JKS'
  prop_replace 'nifi.security.keystorePasswd' "$(cat /opt/nifi/certs/config.json | jq -r .keyStorePassword)"
  prop_replace 'nifi.security.keyPasswd' "$(cat /opt/nifi/certs/config.json | jq -r .keyPassword)"


  # Setup truststore
  prop_replace 'nifi.security.truststore' '/opt/nifi/certs/truststore.jks'
  prop_replace 'nifi.security.truststoreType' 'JKS'
  prop_replace 'nifi.security.truststorePasswd' "$(cat /opt/nifi/certs/config.json | jq -r .trustStorePassword)"

  # Update authorizers
  prop_replace 'nifi.security.user.login.identity.provider' 'ldap-provider'
else

  prop_replace 'nifi.web.http.host' "${hostname}" ${nifi_props_file}
  prop_replace 'nifi.cluster.node.address' "${hostname}" ${nifi_props_file}
  prop_replace 'nifi.remote.input.host' "${hostname}" ${nifi_props_file}

fi


#echo 'java.arg.15=-Djsse.enableSNIExtension=false' >> /opt/nifi/nifi-1.3.0/conf/bootstrap.conf


# Continuously provide logs so that 'docker logs' can produce them
tail -F ${NIFI_HOME}/logs/nifi-app.log &
${NIFI_HOME}/bin/nifi.sh run &
PID="$!"

trap "for i in {1..10}; do echo Received SIGTERM, beginning shutdown...; done" SIGKILL SIGTERM SIGHUP SIGINT EXIT;

echo NiFi running with PID ${PID}.
wait $PID
