#Credit to _thanos for the original snarkstopper - https://forums.minaprotocol.com/t/guide-script-automagically-stops-snark-work-prior-of-getting-a-block-proposal/299
MINA_STATUS=""
STAT=""
CONNECTINGCOUNT=0
OFFLINECOUNT=0
CATCHUPCOUNT=0
HEIGHTOFFCOUNT=0
SIDECARREPORTING=0
TOTALCONNECTINGCOUNT=0
TOTALOFFLINECOUNT=0
TOTALSTUCKCOUNT=0
TOTALCATCHUPCOUNT=0
TOTALHEIGHTOFFCOUNT=0
ARCHIVEDOWNCOUNT=0
BLOCKCHAINLENGTH=0
DELTAVALIDATED=0
DELTAHEIGHT=0
SYNCCOUNT=0
SNARKWORKERTURNEDOFF=1 ### assume snark worker not turned on for the first run
SNARKWORKERSTOPPEDCOUNT=0
readonly SECONDS_PER_MINUTE=60
readonly SECONDS_PER_HOUR=3600
readonly FEE=YOUR_SW_FEE ### SET YOUR SNARK WORKER FEE HERE ###
readonly SW_ADDRESS=YOUR_SW_ADDRESS ### SET YOUR SNARK WORKER ADDRESS HERE ###

while :; do
  ARCHIVERUNNING="$(ps -A | grep coda-archive | wc -l)"
  MINA_STATUS="$(mina client status -json)"

  # to enable sidecar monitoring, the user requires journalctl rights
  # this command will provide access, but requires you to log out and log back in / restart service
  # sudo usermod -aG systemd-journal [USER]
  SIDECARREPORTING="$(journalctl --user-unit mina-sidecar.service --since "10 minutes ago" | grep -c 'Got block data')"
  
  STAT="$(echo $MINA_STATUS | jq .sync_status)"
  HIGHESTBLOCK="$(echo $MINA_STATUS | jq .highest_block_length_received)"
  HIGHESTUNVALIDATEDBLOCK="$(echo $MINA_STATUS | jq .highest_unvalidated_block_length_received)"
  BLOCKCHAINLENGTH="$(echo $MINA_STATUS | jq .blockchain_length)"

  if [[ "$STAT" == "\"Synced\"" ]]; then
    # Calculate whether block producer will run within the next 5 mins
    # If up for a block within 5 mins, stop snarking, resume on next pass
    # First check if we are going to produce a block
    PRODUCER="$(echo $MINA_STATUS | jq .next_block_production.timing[0])"
    if [[ "$PRODUCER" == "\"Produce\"" ]]; then
      NEXTPROP="$(echo $MINA_STATUS | jq .next_block_production.timing[1].time)"
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
        if [[ "$SNARKWORKERTURNEDOFF" -gt 0 ]]; then
            mina client set-snark-worker -address ${SW_ADDRESS}
            mina client set-snark-work-fee $FEE
            SNARKWORKERTURNEDOFF=0
        fi
      fi
    else
      if [[ "$SNARKWORKERTURNEDOFF" -gt 0 ]]; then
          mina client set-snark-worker -address ${SW_ADDRESS}
          mina client set-snark-work-fee $FEE
          SNARKWORKERTURNEDOFF=0
      fi
    fi

    # if in sync, confirm that blockchain length ~= max observed
    DELTAHEIGHT="$(($BLOCKCHAINLENGTH-$HIGHESTBLOCK))"
    if [[ "$DELTAHEIGHT" -gt 3 ]] || [[ "$DELTAHEIGHT" -lt -3 ]]; then
      ((HEIGHTOFFCOUNT++))
    else  
      HEIGHTOFFCOUNT=0
    fi 
  fi

  # Calculate difference between validated and unvalidated blocks
  # If block height is more than 10 block behind, somthing is likely wrong
  DELTAVALIDATED="$(($HIGHESTUNVALIDATEDBLOCK-$HIGHESTBLOCK))"
  if [[ "$DELTAVALIDATED" -gt 5 ]]; then
    echo "Node stuck validated block height delta more than 5 blocks. Difference from Max obvserved and max observied unvalidated:", $DELTAVALIDATED
    ((TOTALSTUCKCOUNT++))
    SYNCCOUNT=0
    systemctl --user restart mina
  fi

  if [[ "$HEIGHTOFFCOUNT" -gt 2 ]]; then
    echo "Block Chain Length differs from Highest Observed Block by 3 or more", $DELTAHEIGHT, $BLOCKCHAINLENGTH, $HIGHESTBLOCK, $HIGHESTUNVALIDATEDBLOCK
    ((TOTALHEIGHTOFFCOUNT++))
    systemctl --user restart mina
  fi

  if [[ "$STAT" == "\"Synced\"" ]]; then
    OFFLINECOUNT=0
    CONNECTINGCOUNT=0
    CATCHUPCOUNT=0
    ((SYNCCOUNT++))
  fi

  if [[ "$STAT" == "\"Connecting\"" ]]; then
    ((CONNECTINGCOUNT++))
    ((TOTALCONNECTINGCOUNT++))
  fi

  if [[ "$STAT" == "\"Offline\"" ]]; then
    ((OFFLINECOUNT++))
    ((TOTALOFFLINECOUNT++))
  fi

  if [[ "$STAT" == "\"Catchup\"" ]]; then
    ((CATCHUPCOUNT++))
    ((TOTALCATCHUPCOUNT++))
  fi

  if [[ "$CONNECTINGCOUNT" -gt 1 ]]; then
    echo "Restarting mina - too long in Connecting state (~10 mins)"
    systemctl --user restart mina
    CONNECTINGCOUNT=0
    SYNCCOUNT=0
  fi

  if [[ "$OFFLINECOUNT" -gt 3 ]]; then
    echo "Restarting mina - too long in Offline state (~20 mins)"
    systemctl --user restart mina
    OFFLINECOUNT=0
    SYNCCOUNT=0
  fi

  if [[ "$CATCHUPCOUNT" -gt 8 ]]; then
    echo "Restarting mina - too long in Catchup state (~45 mins)"
    systemctl --user restart mina
    CATCHUPCOUNT=0
    SYNCCOUNT=0  
  fi

  if [[ "$ARCHIVERUNNING" -gt 0 ]]; then
    ARCHIVERUNNING=0
  else
    ((ARCHIVEDOWNCOUNT++))
    echo "Restarting Mina-Archive Service. Archive Down Count:", $ARCHIVEDOWNCOUNT
    systemctl --user restart mina-archive.service
  fi

  if [[ "$SIDECARREPORTING" -lt 3 && "$SYNCCOUNT" -gt 2 ]]; then
    echo "Restarting mina-sidecar - only reported " $SIDECARREPORTING " times out in 10 mins and node in sync longer than 15 mins."
    SYNCCOUNT=0
    systemctl --user restart mina-sidecar.service
  fi

  echo "Status:" $STAT, "Connecting Count, Total:" $CONNECTINGCOUNT $TOTALCONNECTINGCOUNT, "Offline Count, Total:" $OFFLINECOUNT $TOTALOFFLINECOUNT, "Archive Down Count:" $ARCHIVEDOWNCOUNT, "Node Stuck Below Tip:" $TOTALSTUCKCOUNT, "Total Catchup:" $TOTALCATCHUPCOUNT, "Total Height Mismatch:" $TOTALHEIGHTOFFCOUNT, "Time Until Block:" $TIMEBEFORENEXTMIN
  sleep 300s
  #check if sleep exited with break (ctrl+c) to exit the loop
  test $? -gt 128 && break;
done
