#!/bin/sh
set -e

INSTANCE_DIR=$1
DISABLER_TAG="<!-- Remove this tag to enable custom configuration -->"

declare -a CONFIG_FILES=("BROKER_XML" "LOGGING_PROPERTIES")

function find_env() {
  var=${!1}
  echo "${var:-$2}"
}

function swapVars() {
  sslDir=$(find_env "AMQ_KEYSTORE_TRUSTSTORE_DIR" "")
  echo " SSL Directory : '$AMQ_KEYSTORE_TRUSTSTORE_DIR'"
  
  sed -i "s/\${BROKER_IP}/$BROKER_IP/g" $1
  sed -i "s/\${AMQ_NAME}/$AMQ_NAME/g" $1
  sed -i "s/\${AMQ_ROLE}/$AMQ_ROLE/g" $1
  sed -i "s/\${AMQ_STORAGE_USAGE_LIMIT}/$AMQ_STORAGE_USAGE_LIMIT/g" $1
  sed -i "s/\${AMQ_CLUSTER_USER}/$AMQ_CLUSTER_USER/g" $1
  sed -i "s/\${AMQ_CLUSTER_PASSWORD}/$AMQ_CLUSTER_PASSWORD/g" $1
  sed -i "s/\${AMQ_KEYSTORE_TRUSTSTORE_DIR}/$sslDir/g" $1

}

for config_file in ${CONFIG_FILES[@]};
do

  file_text="${!config_file}"
  file_text=$(echo "$file_text" | sed  "/^$/d") # Remove empty lines

  # Format env var into filename
  fname=$(echo "$config_file" | tr '[:upper:]' '[:lower:]' | sed -e 's/_/./g')

  #If file_text has disabler tag or is an empty/whitspace string
  if echo "$file_text" | grep -q "$DISABLER_TAG" || [[ -z "${file_text// }" ]]; then

    echo "Custom Configuration file '$config_file' is disabled"

  else

    echo "Custom Configuration file '$config_file' is enabled"

    # Overwrite default configuration file
    echo "$file_text" > $INSTANCE_DIR/etc/$fname

  fi

    # Swap env vars into configuration file
    swapVars $INSTANCE_DIR/etc/$fname

done
