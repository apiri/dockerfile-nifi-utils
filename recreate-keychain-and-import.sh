#!/bin/sh -e

usage() { echo "Usage: $0 [-h <host running cluster>]" 1>&2; exit 1; }

while getopts ":h:" option; do
    case "${option}" in
        h)
            docker_host=${OPTARG}
            echo "Using specified host ${docker_host}"
            ;;
        *)
            usage
            ;;
    esac
done

if [ -z "${docker_host}" ]; then
    echo 'No host specified.  Assuming local Docker compose environment'
fi

source generate_certificates.sh

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

  for dn_folder in $(find ${cert_path_base} -type d -mindepth 1 -maxdepth 1); do
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
