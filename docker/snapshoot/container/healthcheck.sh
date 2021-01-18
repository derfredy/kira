#!/bin/bash

exec 2>&1
set -x

set +e && source "/etc/profile" &>/dev/null && set -e

HALT_CHECK="${COMMON_DIR}/halt"
SNAP_STATUS="$SNAP_DIR/status"
SNAP_DONE="$SNAP_STATUS/done"

if [ -f "$HALT_CHECK" ] || [ -f "$SNAP_DONE" ] ; then
  exit 0
fi

echo "INFO: Healthcheck => START"
sleep 30 # rate limit

find "/var/log/journal" -type f -size +256k -exec truncate --size=128k {} +
find "$SELF_LOGS" -type f -size +256k -exec truncate --size=128k {} +

BLOCK_HEIGHT_FILE="$SELF_LOGS/latest_block_height.txt" && touch $BLOCK_HEIGHT_FILE
HEIGHT=$(sekaid status 2>/dev/null | jq -r '.sync_info.latest_block_height' 2>/dev/null | xargs || echo "")

if [ -z "$HEIGHT" ] || [ -z "${HEIGHT##*[!0-9]*}" ]; then # not a number
  HEIGHT=0
fi

if [ ! -z "$HALT_HEIGHT" ] && [ $HALT_HEIGHT -le $HEIGHT ] ; then
    echo "INFO: Success, target height reached!"
    exit 0
fi

PREVIOUS_HEIGHT=$(cat $BLOCK_HEIGHT_FILE)

echo "$HEIGHT" > $BLOCK_HEIGHT_FILE

if [ -z "$PREVIOUS_HEIGHT" ] || [ -z "${PREVIOUS_HEIGHT##*[!0-9]*}" ]; then # not a number
  PREVIOUS_HEIGHT=0
fi

BLOCK_CHANGED="True"
if [ $PREVIOUS_HEIGHT -ge $HEIGHT ]; then
  echo "WARNING: Blocks are not beeing produced or synced, current height: $HEIGHT, previous height: $PREVIOUS_HEIGHT"
  BLOCK_CHANGED="False"
  exit 1
else
  echo "SUCCESS: New blocks were created or synced: $HEIGHT"
fi

echo "INFO: Latest Block Height: $HEIGHT"
