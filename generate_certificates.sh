#!/bin/sh -e

tmp_dir=$(mktemp -d /tmp/nifi-docker-certs-$(date +%s).XXX)
export cert_path_base=${tmp_dir}/cert-tmp/nifi-docker-certs
tls_toolkit_image=aldrin/apache-nifi-tls-toolkit
uid=$(id -u)
gid=$(id -g)

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

  (cd ${dn_cert_path} && docker run --rm \
      --network $(docker inspect -f '{{range $k, $v := .NetworkSettings.Networks}} {{$k}} {{end}}' $(docker ps -q --filter="ancestor=${tls_toolkit_image}")) \
      -v ${dn_cert_path}:/generated \
      ${tls_toolkit_image} client \
      -t tokenenenenalkjlkdfjlkjdflkasjflksjaflsajdflksajfklsajfklsajfklajsf \
      -T PKCS12 \
      -c nifi-ca \
      -p 8443 ${dn_arg})
}

/bin/rm -rf ${cert_path_base}/*

# Create the default user who is our admin
generate_for_dn 'CN=InitialAdmin,OU=NIFI'

# Create a random user
generate_for_dn 'CN=GuyRandomUser,OU=NIFI'

# Update permissions to work around docker being root
certs_volume='/generated'
docker run --rm -v ${cert_path_base}:${certs_volume} alpine chown -R ${uid}:${gid} ${certs_volume}

echo "Certificates are available in directory ${cert_path_base}"
