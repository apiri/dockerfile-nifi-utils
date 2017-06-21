#!/bin/sh -e

usage() { echo "Usage: $0 [-h <host running cluster>]" 1>&2; exit 1; }

# By default we are working against a local instance
docker_host=localhost
while getopts ":h:u:" option; do
    case "${option}" in
        h)
            docker_host=${OPTARG}
            echo "Using specified host ${docker_host}"
            ;;
        u)
            file_owner=${OPTARG}
            ;;
        *)
            usage
            ;;
    esac
done


cert_path_base=$(mktemp -d)
forwarded_port_cmd='docker port unsecured_nifi-node_1 | grep 8443 | cut -d':' -f 2'
# If we are working locally, source the file.  Otherwise, execute across ssh, and copy locally
if [ "${docker_host}" == 'localhost' ]; then
    echo 'localhost or no host specified.  Assuming local Docker compose environment'
    source generate_certificates.sh
    forwarded_port=$(docker port unsecured_nifi-node_1 | grep 8443 | cut -d':' -f 2)
else
  cat generate_certificates.sh | ssh -t ${docker_host}
  remote_cert_directory=$(ssh ${docker_host} find /tmp -maxdepth 1 -type d -name '*-docker-nifi-certs' | sort -r | head -n 1 )
  echo "Generated certificates are available at ${remote_cert_directory}"
  rsync -r $docker_host:${remote_cert_directory}/ ${cert_path_base}/
  echo "Rsync completed to ${cert_path_base}"
  forwarded_port=$(ssh ${docker_host} docker port unsecured_nifi-node_1 | grep 8443 | cut -d':' -f 2)
fi

# Determine where NiFi is accessible
docker_nifi_url="https://${docker_host}:${forwarded_port}/nifi"
echo "NiFi Node 1 is available at: ${docker_nifi_url}"

# Provide automation of handling certificate import and opening browser when in OS X
if [ "$(uname)" == 'Darwin' ]; then
  keychain=~/Library/Keychains/Development.keychain

  echo 'Detected we are running from OS X, creating keychain and importing certificates.'

  # Recreate keychains because OS X has a bug that doesn't let you delete private keys :(
  security delete-keychain ${keychain}
  security create-keychain -p password ${keychain}

  # Add the new keychain into the list of default keychains searched, because create-keychain is supposed to do this, but doesn't :((
  security list-keychains -d user -s ~/Library/Keychains/login.keychain ${keychain}

  security unlock -p password ${keychain}

  for dn_folder in $(find ${cert_path_base} -type d -name 'CN=*' ); do
    sudo security add-trusted-cert -d -k ${keychain} ${dn_folder}/nifi-cert.pem
    security import ${dn_folder}/keystore.pkcs12 -f pkcs12 -k ${keychain} -P $(cat ${dn_folder}/config.json | jq -r .keyStorePassword)
  done

  # Have to close and start browser as per:  https://bugs.chromium.org/p/chromium/issues/detail?id=315084
  # Restart Safari and open to node 1's forwarded address on localhost
  if [ "Running" = "$(osascript -e 'if application "Safari" is running then return "Running"')" ]; then
      echo 'Safari was running... exiting'
      osascript -e 'quit app "Safari"'
      sleep 2
  fi

  open -a "Safari" ${docker_nifi_url}
  open -a "Safari" http://localhost:9000/
fi
