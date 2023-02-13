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

# replace image with build settings
# todo: support multiple services
#build:
#  context: .
#  args:
#    GOBUILD_ARGS: ${GOBUILD_ARGS}

dc_file="$current_dir/docker-compose.yml"

sub_cmd='{sub("'$find_string'","build:")}1'
awk "$sub_cmd" $dc_file >"$dc_file.tmp" && mv "$dc_file.tmp" $dc_file

sub_cmd='{sub("#  context: .","  context: '$GITHUB_WORKSPACE/$service_image_path'")}1'
awk "$sub_cmd" $dc_file >"$dc_file.tmp" && mv "$dc_file.tmp" $dc_file

sub_cmd='{sub("#  args:","  args:")}1'
awk "$sub_cmd" $dc_file >"$dc_file.tmp" && mv "$dc_file.tmp" $dc_file

sub_cmd='{sub("#    GOBUILD_ARGS: ${GOBUILD_ARGS}","    GOBUILD_ARGS: ${GOBUILD_ARGS}")}1'
awk "$sub_cmd" $dc_file >"$dc_file.tmp" && mv "$dc_file.tmp" $dc_file
