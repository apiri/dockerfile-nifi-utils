#!/bin/sh -e

cert_path_base=/tmp/nifi-docker-certs
tls_toolkit_image=aldrin/apache-nifi-tls-toolkit

mkdir -p ${cert_path_base}

generate_for_dn() {
  dn=$1

  dn_arg=''

  if [ ! -z "${dn}" ]; then
    dn_arg="--dn ${dn}"
  else
    dn='default'
  fi

  dn_cert_path=${cert_path_base}/${dn}

  mkdir -p ${dn_cert_path}

  (cd ${dn_cert_path} && docker run -it --rm \
      --network $(docker inspect -f '{{range $k, $v := .NetworkSettings.Networks}} {{$k}} {{end}}' $(docker ps -q --filter="ancestor=${tls_toolkit_image}")) \
      -v ${dn_cert_path}:/generated \
      ${tls_toolkit_image} client \
      -t tokenenenenalkjlkdfjlkjdflkasjflksjaflsajdflksajfklsajfklsajfklajsf \
      -T PKCS12 \
      -c nifi-ca \
      -p 8443 ${dn_arg} && cat config.json | jq -r .keyStorePassword)
}

/bin/rm -rf ${cert_path_base}/*

# Create the default user who is our admin
generate_for_dn 'CN=InitialAdmin,OU=NIFI'

# Create a random user
generate_for_dn 'CN=GuyRandomUser,OU=NIFI'

# Determine where NiFi is accessible
forwarded_port=$(docker port unsecured_nifi-node_1 | grep 8443 | cut -d':' -f 2)
docker_nifi_url="https://localhost:${forwarded_port}/nifi"
echo "NiFi Node 1 is available at: ${docker_nifi_url}"
