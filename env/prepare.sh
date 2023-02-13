#!/bin/bash

set -e

current_dir=$(dirname "$BASH_SOURCE")

service=$1
service_image_path=$2

if [ -z "$service" ]; then
  echo "ERROR: input parameter service missing"
  exit 1
fi

if [ -z "$service_image_path" ]; then
  echo "ERROR: input parameter service image path missing"
  exit 1
fi

find_string=""
if [[ "$service" == "vault" ]]; then
  find_string="image: ghcr.io/findy-network/findy-agent-vault:latest"
fi

if [ -z "$find_string" ]; then
  echo "ERROR: invalid service"
  exit 1
fi

# replace image attribute with build path
sub_cmd='{sub("'$find_string'","build: '$GITHUB_WORKSPACE/$service_image_path'")}1'
awk "$sub_cmd" "$current_dir/docker-compose.yml" >"$current_dir/docker-compose.yml".tmp &&
  mv "$current_dir/docker-compose.yml".tmp "$current_dir/docker-compose.yml"
