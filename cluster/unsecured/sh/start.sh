#!/bin/bash -ex

# 1 - value to search for
# 2 - value to replace
prop_replace () {
  sed -i -e "s|^$1=.*$|$1=$2|"  ${nifi_props_file}
}

# NIFI_HOME is defined by an ENV command in the backing Dockerfile
nifi_props_file=${NIFI_HOME}/conf/nifi.properties

# setup zookeeper

zk_string='zookeeper:2181'
if [ -n "${zookeeper_connect_string}" ]; then
  zk_string=${zookeeper_connect_string}
fi

prop_replace 'nifi.zookeeper_connect_string' "${zookeeper_connect_string}"
prop_replace 'nifi.zookeeper.connect.timeout' '3 secs'
prop_replace 'nifi.zookeeper.session.timeout' '3 secs'
prop_replace 'nifi.zookeeper.root.node' '/nifi'
prop_replace 'nifi.cluster.flow.election.max.wait.time' '10 secs'

# setup clustering
prop_replace 'nifi.cluster.is.node' 'true'
prop_replace 'nifi.cluster.node.protocol.port' '8082'


hostname=$(hostname)

# Setup host based off container properties
prop_replace 'nifi.cluster.node.address' "${hostname}"
prop_replace 'nifi.remote.input.host' "${hostname}"

if [ -n "${tls_token}" ]; then
  echo "Found that tls was set, updating properties for secure mode."

  echo "Requesting certificate with CSR."
  mkdir -p /opt/nifi/certs
  cd /opt/nifi/certs && /opt/nifi/nifi-toolkit-1.3.0/bin/tls-toolkit.sh client -t ${tls_token} -c nifi-ca

  # check if there is already a cluster running, if not, treat this as initial node
  if ! zookeepercli --servers zookeeper -c ls /nifi/leaders ; then
    sed -i -e 's|<property name="Initial Admin Identity"></property>|<property name="Initial Admin Identity">CN=InitialAdmin, OU=NIFI</property>|'  ${NIFI_HOME}/conf/authorizers.xml
    sed -i -e 's|<property name="Node Identity 1"></property>|<property name="Node Identity 1">CN='${hostname}', OU=NIFI</property>|'  ${NIFI_HOME}/conf/authorizers.xml
    # Move the comment line for our Node Identities down 1
    sed -i -n '59{h;n;G};p' /opt/nifi/nifi-1.3.0/conf/authorizers.xml
  fi

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

trap "for i in {1..1000}; do echo Received SIGTERM, beginning shutdown...; done" SIGKILL SIGTERM SIGHUP SIGINT EXIT;

echo NiFi running with PID ${PID}.
wait $PID
