#!/bin/bash

# Script configuration with env variables:
# E2E_USER: when defined, new user onboarding is skipped
# E2E_ORG: when defined, new organisation onboarding is skipped
# FCLI_KEY: needed when using either of latter - agent key
# E2E_CRED_DEF_ID: when defined, cred def creation is skipped (needs E2E_ORG)
# E2E_SCHEMA_ID: needed for existing schema

# Use when testing with remote host:
# AGENCY_URL

set -e

# use specific version of chromedriver
full_version=$(google-chrome --product-version || echo "")

if [ -z "$full_version" ]; then
  echo "Unable to detect Chrome version."
else
  chrome_version=$(echo "${full_version%.*.*.*}")
  npm install chromedriver@$chrome_version || echo "Chromedriver version $chrome_version does not exist."
fi

current_dir=$(dirname "$BASH_SOURCE")

read_timeout="60s"
timestamp=$(date +%s)
register_wait_time=$AGENCY_REGISTER_WAIT_TIME
if [ -z "$register_wait_time" ]; then
  register_wait_time=1
fi

user=$E2E_USER
existing="true"
if [ -z "$user" ]; then
  echo "User not defined, creating new..."
  user="user-$timestamp"
  existing="false"
fi

org=$E2E_ORG
if [ -z "$org" ]; then
  echo "Organisation not defined, creating new..."
  org="org-$timestamp"
fi

bot_file="$current_dir/e2e-sa.yaml"

echo "::add-mask::$user"
echo "::add-mask::$org"

if [ -z "$AGENCY_URL" ]; then
  AGENCY_URL="http://localhost:3000"
fi

# fetch needed env variables from agency deployment
source /dev/stdin <<<"$(curl -sS $AGENCY_URL/set-env.sh)"

echo "Running e2e test for $FCLI_URL (origin: $FCLI_ORIGIN, api: $FCLI_SERVER)"

# register web wallet user
if [ -z "$E2E_USER" ]; then
  echo "Register user $user"
  findy-agent-cli authn register -u $user
fi

# login web wallet user
echo "Login user $user"
jwt=$(findy-agent-cli authn login -u $user)

# register org agent
if [ -z "$E2E_ORG" ]; then
  echo "Register org $org"
  if [ -z "$E2E_ORG_SEED" ]; then
    findy-agent-cli authn register -u $org
  else
    findy-agent-cli authn register -u $org --seed $E2E_ORG_SEED
  fi
  # wait for onboard transaction to be written to ledger
  sleep $register_wait_time
fi

# login org
echo "Login org $org"
org_jwt=$(findy-agent-cli authn login -u $org)

# create invitation
echo "Create invitation for organisation"
invitation=$(findy-agent-cli agent invitation --label $org --jwt $org_jwt)

echo $invitation >$current_dir/../test/e2e.invitation.json
connection_id=$(node -pe "require('$current_dir/../test/e2e.invitation.json')['@id']")
echo "::add-mask::$connection_id"
echo "Invitation created with connection id $connection_id"

cred_def_id=$E2E_CRED_DEF_ID
sch_id=$E2E_SCHEMA_ID
if [ -z "$E2E_CRED_DEF_ID" ]; then
  if [ -z "$sch_id" ]; then
    # create schema
    echo "Create schema"
    sch_id=$(findy-agent-cli agent create-schema --jwt $org_jwt --name="email" --version=1.0 email)
    echo "::add-mask::$sch_id"
  fi

  # read schema - make sure it's found in ledger
  echo "Read schema"
  schema=$(findy-agent-cli agent get-schema --jwt $org_jwt --schema-id $sch_id --timeout $read_timeout)

  if [ -z "$schema" ]; then
    echo "Schema creation failed."
    exit 1
  fi

  echo "Schema read successfully: $schema"

  # create cred def
  echo "Create cred def with schema id $sch_id"
  cred_def_id=$(findy-agent-cli agent create-cred-def --jwt $org_jwt --id $sch_id --tag $org)
  echo "::add-mask::$cred_def_id"

  # read cred def - make sure it's found in ledger
  echo "Read cred def"
  cred_def=$(findy-agent-cli agent get-cred-def --jwt $org_jwt --id $cred_def_id --timeout $read_timeout)

  echo "Cred def read successfully: $cred_def"
fi

# store details for testing
echo {\"jwt\": \"$jwt\", \"user\": \"$user\", \"existing\": $existing, \"organisation\": \"$org\", \"key\": \"$FCLI_KEY\", \"credDefId\": \"$cred_def_id\", \"schemaId\": \"$sch_id\" } >$current_dir/../test/e2e.user.json

# start bot in background
echo "Starting bot with connection $connection_id"
export CRED_DEF_ID="$cred_def_id"
findy-agent-cli bot start --jwt $org_jwt --conn-id $connection_id $bot_file &
echo "Bot started"
