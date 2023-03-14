#!/bin/bash

set -e

current_dir=$(dirname "$BASH_SOURCE")

service=$1
service_context=$2
service_dockerfile=$3

if [ -z "$service" ]; then
  echo "ERROR: input parameter service missing"
  exit 1
fi

if [ -z "$service_context" ]; then
  echo "ERROR: input parameter service image path missing"
  exit 1
fi

if [ -z "$service_dockerfile" ]; then
  echo "Using default dockerfile path"
  service_dockerfile="Dockerfile"
fi

find_string=""

if [[ "$service" == "cli" ]]; then
  echo "Nothing to do, testing CLI."
  exit 0
elif [[ "$service" == "core" ]]; then
  find_string="image: ghcr.io/findy-network/findy-agent:latest"
elif [[ "$service" == "auth" ]]; then
  find_string="image: ghcr.io/findy-network/findy-agent-auth:latest"
elif [[ "$service" == "vault" ]]; then
  find_string="image: ghcr.io/findy-network/findy-agent-vault:latest"
elif [[ "$service" == "pwa" ]]; then
  find_string="image: ghcr.io/findy-network/findy-wallet-pwa/local:latest"
fi

if [ -z "$find_string" ]; then
  echo "ERROR: invalid service"
  exit 1
fi

dc_file="$current_dir/docker-compose.yml"

# instead of using a ready image, build it
sub_cmd='{sub("'$find_string'","build:")}1'
awk "$sub_cmd" $dc_file >"$dc_file.tmp" && mv "$dc_file.tmp" $dc_file

# context path for the image to build
sub_cmd='{sub("#'$service'   context: .","  context: '$GITHUB_WORKSPACE/$service_context'")}1'
awk "$sub_cmd" $dc_file >"$dc_file.tmp" && mv "$dc_file.tmp" $dc_file

# dockerfile path for the image to build
sub_cmd='{sub("#'$service'   dockerfile: Dockerfile","  dockerfile: '$GITHUB_WORKSPACE/$service_dockerfile'")}1'
awk "$sub_cmd" $dc_file >"$dc_file.tmp" && mv "$dc_file.tmp" $dc_file

# arguments
sub_cmd='{sub("#'$service'   args:","  args:")}1'
awk "$sub_cmd" $dc_file >"$dc_file.tmp" && mv "$dc_file.tmp" $dc_file

# for go services we enable instrumentation to measure coverage
sub_cmd='{sub("#'$service'     GOBUILD_ARGS","    GOBUILD_ARGS")}1'
awk "$sub_cmd" $dc_file >"$dc_file.tmp" && mv "$dc_file.tmp" $dc_file

#cat $dc_file
