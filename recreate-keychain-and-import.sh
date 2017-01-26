#!/bin/sh

cert_path=/tmp/nifi/certs
keychain=~/Library/Keychains/Development.keychain

mkdir -p /tmp/nifi/certs
/bin/rm /tmp/nifi/certs/*
  && ../bin/tls-toolkit.sh client
    -t tokenenenenalkjlkdfjlkjdflkasjflksjaflsajdflksajfklsajfklsajfklajsf \
    -T PKCS12 \
    -c nifi-ca \
    -p 18443 && cat config.json | jq -r .keyStorePassword

# Remove keychains
security delete-keychain ${keychain}
security create-keychain -p password ${keychain}
security list-keychains -d user -s ~/Library/Keychains/login.keychain ${keychain}
security unlock -p password ${keychain}
sudo security add-trusted-cert -d -k ${keychain} nifi-cert.pem
security import keystore.pkcs12 -f pkcs12 -k ${keychain} -P $(cat config.json | jq -r .keyStorePassword)
