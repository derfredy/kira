#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
exec 2>&1
set -x

HALT_CHECK="${COMMON_DIR}/halt"
BLOCK_HEIGHT_FILE="$SELF_LOGS/latest_block_height"
COMMON_CONSENSUS="$COMMON_READ/consensus"
COMMON_LATEST_BLOCK_HEIGHT="$COMMON_READ/latest_block_height"

touch $BLOCK_HEIGHT_FILE

if [ -f "$HALT_CHECK" ]; then
  exit 0
fi

echo "INFO: Healthcheck => START"
sleep 30 # rate limit

find "$SELF_LOGS" -type f -size +256k -exec truncate --size=128k {} +
find "$COMMON_LOGS" -type f -size +256k -exec truncate --size=128k {} + || echo "INFO: Failed to truncate common logs"

STATUS_NGINX="$(service nginx status)"
SUB_STR="nginx is running"
if [[ "$STATUS_NGINX" != *"$SUB_STR"* ]]; then
  echo "Nginx is not running."
  nginx -t
  service nginx restart
  exit 1
fi

INDEX_HTML="$(curl http://127.0.0.1:80)"

SUB_STR="<!DOCTYPE html>"
if [[ "$INDEX_HTML" != *"$SUB_STR"* ]]; then
  echo "HTML page is not rendering."
  exit 1
fi

INDEX_STATUS_CODE="$(curl -s -o /dev/null -I -w '%{http_code}' 127.0.0.1:80)"

if [ "$INDEX_STATUS_CODE" -ne "200" ]; then
  echo "Index page returns ${INDEX_STATUS_CODE}"
  exit 1
fi

HEIGHT=$(curl http://interx:11000/api/kira/status 2>/dev/null | jq -rc '.SyncInfo.latest_block_height' 2>/dev/null || echo "")
[ -z "${HEIGHT##*[!0-9]*}" ] && HEIGHT=$(curl http://interx:11000/api/kira/status 2>/dev/null | jq -rc '.sync_info.latest_block_height' 2>/dev/null || echo "")
[ -z "${HEIGHT##*[!0-9]*}" ] && HEIGHT=0

PREVIOUS_HEIGHT=$(cat $BLOCK_HEIGHT_FILE)
echo "$HEIGHT" > $BLOCK_HEIGHT_FILE
[ -z "${PREVIOUS_HEIGHT##*[!0-9]*}" ] && PREVIOUS_HEIGHT=0

if [ $PREVIOUS_HEIGHT -ge $HEIGHT ]; then
  echo "WARNING: Blocks are not beeing produced or synced, current height: $HEIGHT, previous height: $PREVIOUS_HEIGHT"
  exit 1
else
  echo "SUCCESS: New blocks were created or synced: $HEIGHT"
fi

echo "INFO: Latest Block Height: $HEIGHT"
exit 0
