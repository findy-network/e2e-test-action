#!/bin/bash

set -e

service=$1

if [[ "$service" == "cli" ]]; then
  go build -cover -o findy-agent-cli
  sudo cp findy-agent-cli /bin
else
  curl https://raw.githubusercontent.com/findy-network/findy-agent-cli/HEAD/install.sh >install.sh
  chmod a+x install.sh
  sudo ./install.sh -b /bin
fi
