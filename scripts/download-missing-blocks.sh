#!/bin/bash
# lifted from https://github.com/MinaProtocol/mina/blob/master/src/app/rosetta/download-missing-blocks.sh

O1BLOCKS_BUCKET=mina_network_block_data
JKWH1_BLOCKS_BUCKET=mina-mainnet-blocks
set -u

MINA_NETWORK=${1}
# Postgres database connection string and related variables
PG_CONN=${2}

function jq_parent_json() {
  jq -rs 'map(select(.metadata.parent_hash != null and .metadata.parent_height != null)) | "\(.[0].metadata.parent_height)-\(.[0].metadata.parent_hash).json"'
}
function jq_skip_parent_json() {
  jq -rs 'map(select(.metadata.parent_hash != null and .metadata.parent_height != null)) | "\(.[1].metadata.parent_height)-\(.[1].metadata.parent_hash).json"'
}

function jq_parent_hash() {
  jq -rs 'map(select(.metadata.parent_hash != null and .metadata.parent_height != null)) | .[0].metadata.parent_hash'
}

function populate_db() {
  echo "Attempting to populate archive db with $2"
  mina-archive-blocks --precomputed --archive-uri "$1" "$2" | jq -rs '"[BOOTSTRAP] Populated database with block: \(.[-1].message)"'
  rm "$2"
}

function download_block() {
  CHECKBLOCK=0
  echo "Downloading $1 block"
  curl -sO "https://storage.googleapis.com/"${JKWH1_BLOCKS_BUCKET}/${1}
  CHECKBLOCK=$(grep '<Error><Code>NoSuchKey</Code>' $1 | wc -l)
  if [[ $CHECKBLOCK -eq 1 ]]; then
    CHECKBLOCK=0
    echo "Block $1 not found in bucket"
    echo "Downloading $1 block from O1 Labs"
    curl -sO "https://storage.googleapis.com/"${O1BLOCKS_BUCKET}/${1}
    CHECKBLOCK=$(grep '<Error><Code>NoSuchKey</Code>' $1 | wc -l)
    if [[ $CHECKBLOCK -eq 1 ]]; then
      echo "Block $1 not found in either bucket"
      exit 1
    else    
      echo "Block $1 found in O1 Labs bucket - copying to Google Cloud Storage for retry"
      gcloud storage cp $1 gs://storage.googleapis.com/${JKWH1_BLOCKS_BUCKET}/
      rm $1
    fi
  else
    echo "Block $1 found in bucket"
  fi
}

HASH='map(select(.metadata.parent_hash != null and .metadata.parent_height != null)) | .[0].metadata.parent_hash'
# Bootstrap finds every missing state hash in the database and imports them from the o1labs bucket of .json blocks
function bootstrap() {
  echo "[BOOTSTRAP] Restoring blocks individually from ${JKWH1_BLOCKS_BUCKET}..."

  until [[ "$PARENT" == "null" ]] ; do
    PARENT_FILE="${MINA_NETWORK}-$(mina-missing-blocks-auditor --archive-uri $PG_CONN | jq_parent_json)"
    echo "[BOOTSTRAP] next block is " $PARENT_FILE
    download_block "${PARENT_FILE}"
    populate_db "$PG_CONN" "$PARENT_FILE"
    PARENT="$(mina-missing-blocks-auditor --archive-uri $PG_CONN | jq_parent_json)"
  done

  echo "[BOOTSTRAP] Top 10 blocks in bootstrapped archiveDB:"
  psql "${PG_CONN}" -c "SELECT state_hash,height FROM blocks ORDER BY height DESC LIMIT 10"
  echo "[BOOTSTRAP] This rosetta node is synced with no missing blocks back to genesis!"

  echo "[BOOTSTRAP] Checking again in 5 minutes..."
  date
  sleep 300
  date
}

# Wait until there is a block missing
PARENT=null
while true; do # Test once every 10 minutes forever, take an hour off when bootstrap completes
#  output=$(mina-missing-blocks-auditor --archive-uri $PG_CONN)
#  if [ $? -ne 0 ]; then
#    echo "Error running mina-missing-blocks-auditor"
#    echo $output
#    exit 1 
#  fi
#  PARENT=$(echo "$output" | jq_parent_hash)
  PARENT="$(mina-missing-blocks-auditor --archive-uri $PG_CONN | jq_parent_hash)"
  echo ran mina-missing-blocks-auditor $PARENT
  [[ "$PARENT" != "null" ]] && echo "[BOOSTRAP] Some blocks are missing, moving to recovery logic..." && bootstrap
done
echo "[BOOTSTRAP] This rosetta node is synced with no missing blocks back to genesis!"