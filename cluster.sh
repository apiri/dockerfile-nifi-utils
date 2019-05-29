#!/bin/sh -e


if ! compose_path=$(readlink -f .); then
  if ! compose_path=$(greadlink -f .); then
    echo 'You are likely on OS X and do not have greadlink.'
  fi
fi

echo Using path ${compose_path}

operation=$1
case $operation in
  up)
    echo Starting cluster
    docker-compose -f ${compose_path}/cluster/docker-compose.yml up --build -d
    ;;
  down)
    echo Tearing down cluster
    docker-compose -f ${compose_path}/cluster/docker-compose.yml down
    ;;
  scale)
    num_nodes=$2
    if [ -z "${num_nodes}" ]; then
      echo "Need a number of nodes to scale!"
      exit 1
    fi
    echo Scaling cluster to ${num_nodes} nodes.
    docker-compose -f ${compose_path}/cluster/docker-compose.yml scale nifi-node=${num_nodes}
    ;;
esac
