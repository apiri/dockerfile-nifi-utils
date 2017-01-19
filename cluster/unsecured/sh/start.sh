#!/bin/bash -ex

# NIFI_HOME is defined by an ENV command in the backing Dockerfile
nifi_props_file=${NIFI_HOME}/conf/nifi.properties

hr() {
    width=20
    if [[ -s "$TERM" ]]
    then
        width=$(tput cols)
    fi
    printf '\n%*s\n\n' "${COLUMNS:-${width}}" '' | tr ' ' '*'
}


# setup zookeeper
sed -i -e "s|^nifi.zookeeper.connect.string=.*$|nifi.zookeeper.connect.string=zookeeper:2181|" ${nifi_props_file}
sed -i -e "s|^nifi.zookeeper.connect.timeout=.*$|nifi.zookeeper.connect.timeout=3 secs|" ${nifi_props_file}
sed -i -e "s|^nifi.zookeeper.session.timeout=.*$|nifi.zookeeper.session.timeout=3 secs|" ${nifi_props_file}
sed -i -e "s|^nifi.zookeeper.root.node=.*$|nifi.zookeeper.root.node=/nifi|" ${nifi_props_file}

# setup clustering
sed -i -e "s|^nifi.cluster.is.node=.*$|nifi.cluster.is.node=true|" ${nifi_props_file}
sed -i -e "s|^nifi.cluster.node.protocol.port=.*$|nifi.cluster.node.protocol.port=8082|" ${nifi_props_file}


sed -i -e "s|^nifi.web.http.host=.*$|nifi.web.http.host=$(hostname)|" ${nifi_props_file}
sed -i -e "s|^nifi.cluster.node.address=.*$|nifi.cluster.node.address=$(hostname)|" ${nifi_props_file}
sed -i -e "s|^nifi.remote.input.host=.*$|nifi.remote.input.host=$(hostname)|" ${nifi_props_file}

# Continuously provide logs so that 'docker logs' can produce them
tail -F ${NIFI_HOME}/logs/nifi-app.log &
${NIFI_HOME}/bin/nifi.sh run
