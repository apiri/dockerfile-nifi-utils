#!/bin/sh

tls_toolkit_path=~/Downloads/nifi-toolkit-1.1.1
cert_path=/tmp/nifi/certs
keychain=~/Library/Keychains/Development.keychain

mkdir -p ${cert_path}
/bin/rm -f ${cert_path}/* \
  && (cd ${cert_path} && ${tls_toolkit_path}/bin/tls-toolkit.sh client \
    -t tokenenenenalkjlkdfjlkjdflkasjflksjaflsajdflksajfklsajfklsajfklajsf \
    -T PKCS12 \
    -c nifi-ca \
    -p 18443 && cat config.json | jq -r .keyStorePassword)

# Recreate keychains because OS X has a bug that doesn't let you delete private keys :(
security delete-keychain ${keychain}
security create-keychain -p password ${keychain}

# Add the new keychain into the list of default keychains searched, because create-keychain is supposed to do this, but doesn't :((
security list-keychains -d user -s ~/Library/Keychains/login.keychain ${keychain}

security unlock -p password ${keychain}
sudo security add-trusted-cert -d -k ${keychain} ${cert_path}/nifi-cert.pem
security import ${cert_path}/keystore.pkcs12 -f pkcs12 -k ${keychain} -P $(cat ${cert_path}/config.json | jq -r .keyStorePassword)
