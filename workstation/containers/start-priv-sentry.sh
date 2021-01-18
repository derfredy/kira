#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e

CONTAINER_NAME="priv_sentry"
SNAP_DESTINATION="$DOCKER_COMMON/$CONTAINER_NAME/snap.zip"
COMMON_PATH="$DOCKER_COMMON/$CONTAINER_NAME"

set +x
echo "------------------------------------------------"
echo "| STARTING $CONTAINER_NAME NODE"
echo "|-----------------------------------------------"
echo "|   NODE ID: $SENTRY_NODE_ID"
echo "|   NETWORK: $KIRA_SENTRY_NETWORK"
echo "|  HOSTNAME: $KIRA_PRIV_SENTRY_DNS"
echo "| SNAPSHOOT: $KIRA_SNAP_PATH"
echo "------------------------------------------------"

echo "INFO: Loading secrets..."
source $KIRAMGR_SCRIPTS/load-secrets.sh
set -x
set -e

mkdir -p "$COMMON_PATH"
cp -a -v $KIRA_SECRETS/priv_sentry_node_key.json $COMMON_PATH/node_key.json

rm -fv $SNAP_DESTINATION
if [ -f "$KIRA_SNAP_PATH" ] ; then
    echo "INFO: State snapshoot was found, cloning..."
    cp -a -v $KIRA_SNAP_PATH $SNAP_DESTINATION
fi

echo "INFO: Setting up $CONTAINER_NAME config vars..."
# * Config sentry/configs/config.toml

VALIDATOR_SEED=$(echo "${VALIDATOR_NODE_ID}@validator:$DEFAULT_P2P_PORT" | xargs | tr -d '\n' | tr -d '\r')

echo "INFO: Starting $CONTAINER_NAME node..."

docker run -d \
    -p $KIRA_PRIV_SENTRY_P2P_PORT:$DEFAULT_P2P_PORT \
    --hostname $KIRA_PRIV_SENTRY_DNS \
    --restart=always \
    --name $CONTAINER_NAME \
    --net=$KIRA_SENTRY_NETWORK \
    -e DEBUG_MODE="True" \
    -e NETWORK_NAME="$NETWORK_NAME" \
    -e CFG_moniker="KIRA ${CONTAINER_NAME^^} NODE" \
    -e CFG_pex="false" \
    -e CFG_rpc_laddr="tcp://0.0.0.0:$DEFAULT_RPC_PORT" \
    -e CFG_persistent_peers="tcp://$VALIDATOR_SEED" \
    -e CFG_private_peer_ids="$VALIDATOR_NODE_ID,$SNAPSHOOT_NODE_ID,$SENTRYT_NODE_ID,$PRIV_SENTRYT_NODE_ID" \
    -e CFG_unconditional_peer_ids="$VALIDATOR_NODE_ID" \
    -e CFG_addr_book_strict="true" \
    -e CFG_version="v2" \
    -e CFG_seed_mode="false" \
    -e NODE_TYPE=$CONTAINER_NAME \
    -v $COMMON_PATH:/common \
    kira:latest

docker network connect $KIRA_VALIDATOR_NETWORK $CONTAINER_NAME

echo "INFO: Waiting for $CONTAINER_NAME to start..."
$KIRAMGR_SCRIPTS/await-sentry-init.sh "$CONTAINER_NAME" "$SENTRY_NODE_ID" || exit 1

$KIRAMGR_SCRIPTS/restart-networks.sh "true" "$KIRA_SENTRY_NETWORK"
$KIRAMGR_SCRIPTS/restart-networks.sh "true" "$KIRA_VALIDATOR_NETWORK"
