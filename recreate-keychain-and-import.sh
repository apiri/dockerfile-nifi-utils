#!/bin/sh -e

cert_path_base=/tmp/nifi-docker-certs
keychain=~/Library/Keychains/Development.keychain
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

# Recreate keychains because OS X has a bug that doesn't let you delete private keys :(
security delete-keychain ${keychain}
security create-keychain -p password ${keychain}

# Add the new keychain into the list of default keychains searched, because create-keychain is supposed to do this, but doesn't :((
security list-keychains -d user -s ~/Library/Keychains/login.keychain ${keychain}

security unlock -p password ${keychain}

for dn_folder in $(find ${cert_path_base} -type d -mindepth 1 -maxdepth 1); do
  sudo security add-trusted-cert -d -k ${keychain} ${dn_folder}/nifi-cert.pem
  security import ${dn_folder}/keystore.pkcs12 -f pkcs12 -k ${keychain} -P $(cat ${dn_folder}/config.json | jq -r .keyStorePassword)
done

# Determine where NiFi is accessible
forwarded_port=$(docker port unsecured_nifi-node_1 | grep 8443 | cut -d':' -f 2)
docker_nifi_url="https://localhost:${forwarded_port}/nifi"
echo "NiFi Node 1 is available at: ${docker_nifi_url}"

# Have to close and start browser as per:  https://bugs.chromium.org/p/chromium/issues/detail?id=315084
# Restart Safari and open to node 1's forwarded address on localhost
if [ "Running" = "$(osascript -e 'if application "Safari" is running then return "Running"')" ]; then
    echo 'Safari was running... exiting'
    osascript -e 'quit app "Safari"'
    sleep 2
fi

open -a "Safari" ${docker_nifi_url}
open -a "Safari" http://localhost:9000/
