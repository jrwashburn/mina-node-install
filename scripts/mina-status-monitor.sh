MINA_STATUS=""
STAT=""
ARCHIVESTAT=0
CONNECTINGCOUNT=0
OFFLINECOUNT=0
TOTALCONNECTINGCOUNT=0
TOTALOFFLINECOUNT=0
TOTALSTUCK=0
ARCHIVEDOWNCOUNT=0
SNARKWORKERTURNEDOFF=1 ### assume snark worker not turned on for the first run
SNARKWORKERSTOPPEDCOUNT=0
readonly SECONDS_PER_MINUTE=60
readonly SECONDS_PER_HOUR=3600
readonly FEE=YOUR_SW_FEE ### SET YOUR SNARK WORKER FEE HERE ###
readonly SW_ADDRESS=YOUR_SW_ADDRESS ### SET YOUR SNARK WORKER ADDRESS HERE ###

while :; do
  MINA_STATUS="$(mina client status -json)"

  STAT="$(echo $MINA_STATUS | jq .sync_status)"
  NEXTPROP="$(echo $MINA_STATUS | jq .next_block_production.timing[1].time)"
  HIGHESTBLOCK="$(echo $MINA_STATUS | jq .highest_block_length_received)"
  HIGHESTUNVALIDATEDBLOCK="$(echo $MINA_STATUS | jq .highest_unvalidated_block_length_received)"
  ARCHIVERUNNING=`ps -A | grep coda-archive | wc -l`

  # Calculate whether block producer will run within the next 5 mins
  # If up for a block within 5 mins, stop snarking, resume on next pass
  NEXTPROP="${NEXTPROP:1}"
  NEXTPROP="${NEXTPROP:0:-1}"
  NOW="$(date +%s%N | cut -b1-13)"
  TIMEBEFORENEXT="$(($NEXTPROP-$NOW))"
  TIMEBEFORENEXTSEC="${TIMEBEFORENEXT:0:-3}"
  TIMEBEFORENEXTMIN="$((${TIMEBEFORENEXTSEC} / ${SECONDS_PER_MINUTE}))"
  if [ $TIMEBEFORENEXTMIN -lt 5 ]; then
    echo "Stop snarking"
    mina client set-snark-worker
    ((SNARKWORKERTURNEDOFF++))
  else
    if [[ "$SNARKWORKERTURNEDOFF" > 0 ]]; then
      mina client set-snark-worker -address ${SW_ADDRESS}
      mina client set-snark-work-fee $FEE
      SNARKWORKERTURNEDOFF=0
    fi
  fi

  # Calculate difference between validated and unvalidated blocks
  # If block height is more than 10 block behind, somthing is likely wrong
  DELTAVALIDATED="$(($HIGHESTUNVALIDATEDBLOCK-$HIGHESTBLOCK))"
  echo "DELTA VALIDATE: ", $DELTAVALIDATED
  if [[ "$DELTAVALIDATED" > 10 ]]; then
    echo "Node stuck validated block height delta more than 10 blocks"
    ((TOTALSTUCK++))
    systemctl --user restart mina
  fi

  if [[ "$STAT" == "\"Synced\"" ]]; then
    OFFLINECOUNT=0
    CONNECTINGCOUNT=0
  fi

  if [[ "$STAT" == "\"Connecting\"" ]]; then
    ((CONNECTINGCOUNT++))
    ((TOTALCONNECTINGCOUNT++))
  fi

  if [[ "$STAT" == "\"Offline\"" ]]; then
    ((OFFLINECOUNT++))
    ((TOTALOFFLINECOUNT++))
  fi

  if [[ "$CONNECTINGCOUNT" > 1 ]]; then
    systemctl --user restart mina
    CONNECTINGCOUNT=0
  fi

  if [[ "$OFFLINECOUNT" > 3 ]]; then
    systemctl --user restart mina
    OFFLINECOUNT=0
  fi

  if [[ "$ARCHIVERUNNING" > 0 ]]; then
    ARCHIVERRUNNING=0
  else
    ((ARCHIVEDOWNCOUNT++))
  fi 
  echo "Status:" $STAT, "Connecting Count, Total:" $CONNECTINGCOUNT $TOTALCONNECTINGCOUNT, "Offline Count, Total:" $OFFLINECOUNT $TOTALOFFLINECOUNT, "Archive Down Count:" $ARCHIVEDOWNCOUNT, "Node Stuck Below Tip:" $TOTALSTUCK, "Time Until Block:" $TIMEBEFORENEXTMIN
  sleep 300s
  test $? -gt 128 && break;
done
