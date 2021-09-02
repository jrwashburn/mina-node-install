#Credit to _thanos for the original snarkstopper - https://forums.minaprotocol.com/t/guide-script-automagically-stops-snark-work-prior-of-getting-a-block-proposal/299

#Set Controlling Variables for what status monitor will watch
#General Parameters
readonly MONITORCYCLE=300 #how many seconds between mina client status checks
readonly CATCHUPWINDOW=12 #how many intervals to wait for catchup before restart (12*5mins = 60 mins)
readonly MAXUNVALIDATEDDELTA=3 #will count as out of compliance if more than this many blocks ahead or behind unvalidated count
readonly GARBAGE="Using password from environment variable CODA_PRIVKEY_PASS" #strip this out of the status

#Snark Stopper
readonly USESNARKSTOPPER=1 #set to 1 to run snark stopper, 0 to turn it off (will stop snarking if not in sync, or producing a block soon)
SNARKWORKERTURNEDOFF=0 #set to 1 to assume snark worker should always be turned on for first run, otherwise 0
readonly STOPSNARKINGLESSTHAN=5 #threshold in minutes to stop snarking - if minutes until produce block < this value, will stop snark worker
readonly FEE=YOUR_SW_FEE ### *** SET YOUR SNARK WORKER FEE HERE *** ###
readonly SW_ADDRESS=YOUR_SW_ADDRESS ### *** SET YOUR SNARK WORKER ADDRESS HERE *** ###

#Archive Monitoring
readonly USEARCHIVEMONITOR=1 #set to 1 to monitor archive service, 0 ignores archive monitoring

#Sidecar Monitoring
readonly USESIDECARMONITOR=1 #set to 1 to monitor sidecar service, 0 ignores sidecar monitoring

#Compare to Mina Explorer Height
readonly USEMINAEXPLORERMONITOR=1 #set to 1 to compare synced height vs. Mina Explorer reported height, 0 does not check MinaExplorer
readonly MINAEXPLORERMAXDELTA=3 #number of blocks to tolerate in synced blockheight vs. Mina Explorers reported height
readonly MINAEXPLORERTOLERANCEWINDOW=5 #how many intervals to wait to restart with coninual out of sync vs. mina explorer
readonly MINAEXPLORERURL=https://api.minaexplorer.com #url to get status from mina explorer -- devnet: https://devnet.api.minaexplorer.com

#File Descriptor Monitoring
readonly USEFILEDESCRIPTORSMONITOR=1 #set to 1 to turn on file descriptor logging, 0 to turn it on
readonly MINAUSER="minar" #set to userid the mina service runs under (will be used to monitor file descriptor of that user)

function INITIALIZEVARS {
  readonly SECONDS_PER_MINUTE=60
  readonly SECONDS_PER_HOUR=3600
  readonly FDLIMIT=$(ulimit -n)
  MINA_STATUS=""
  STAT=""
  KNOWNSTATUS=0
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
  DELTAME=0
  SYNCCOUNT=0
  MINAEXPLORERBLOCKCHAINLENGTH=0
  VSMECOUNT=0
  TOTALVSMECOUNT=0
  SNARKWORKERSTOPPEDCOUNT=0
  FDCOUNT=0
  FDCHECK=0
  FDINCREMENT=100
}

function CHECKFILEDESCRIPTORS {
  FDCOUNT="$(lsof -u $MINAUSER | wc -l)"
  if [ $FDCOUNT -gt $FDCHECK ]; then
    lsof -u $MINAUSER > "/tmp/lsof$(date +%m-%d-%H-%M)".txt
    FDCHECK=$(( $FDCOUNT + $FDINCREMENT ))
    if [ $FDLIMIT -lt $FDCHECK ]; then
      FDINCREMENT=$(( $FDINCREMENT / 2 ))
      FDCHECK=$(( $FDCOUNT + $FDINCREMENT ))
    fi
    echo Logged lsof to /tmp at $FDCOUNT FD - Next log at $FDCHECK FD
  fi
}

function CHECKARCHIVE {
  ARCHIVERUNNING="$(ps -A | grep coda-archive | wc -l)"
  if [[ "$ARCHIVERUNNING" -gt 0 ]]; then
    ARCHIVERUNNING=0
  else
    ((ARCHIVEDOWNCOUNT++))
    echo "Restarting mina-Archive Service. Archive Down Count:", $ARCHIVEDOWNCOUNT
    systemctl --user restart mina-archive.service
  fi
}

function CHECKSIDECAR {
  # to enable sidecar monitoring, the user requires journalctl rights
  # this command will provide access, but requires you to log out and log back in / restart service
  # sudo usermod -aG systemd-journal [USER]
  SIDECARREPORTING="$(journalctl --user-unit mina-sidecar.service --since "10 minutes ago" | grep -c 'Got block data')"

  if [[ "$SIDECARREPORTING" -lt 3 && "$SYNCCOUNT" -gt 2 ]]; then
    echo "Restarting mina-sidecar - only reported " $SIDECARREPORTING " times out in 10 mins and node in sync longer than 15 mins."
    systemctl --user restart mina-sidecar.service
  fi
}

function CHECKSNARKWORKER {
  if [[ "$STAT" == "\"Synced\"" ]]; then
    # Calculate whether block producer will run within the next X mins
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
      if [ $TIMEBEFORENEXTMIN -lt $"STOPSNARKINGLESSTHAN" ]; then
        echo "Stop snarking - producing a block soon"
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
  else
    # stop snarking if not in sync!
    if [[ ! "$SNARKWORKERTURNEDOFF" -gt 0 ]]; then
      echo "Stop snarking - node is not in sync"
      mina client set-snark-worker
      ((SNARKWORKERTURNEDOFF++))
    fi
  fi
}

function CHECKMINAEXPLORER {
  MINAEXPLORERBLOCKCHAINLENGTH="$(curl -s "$MINAEXPLORERURL" | jq .blockchainLength)"
  DELTAME="$(($BLOCKCHAINLENGTH-$MINAEXPLORERBLOCKCHAINLENGTH))"
  if [[ "$DELTAME" -gt "$MINAEXPLORERMAXDELTA" ]] || [[ "$DELTAME" -lt -"$MINAEXPLORERMAXDELTA" ]]; then
    ((VSMECOUNT++))
  else
    VSMECOUNT=0
  fi
  if [[ "$VSMECOUNT" -gt "$MINAEXPLORERTOLERANCEWINDOW" ]]; then
    echo "Restarting mina - block heigh varied from ME too much / too long:", $DELTAHEIGHT, $BLOCKCHAINLENGTH, $HIGHESTBLOCK, $HIGHESTUNVALIDATEDBLOCK, $MINAEXPLORERBLOCKCHAINLENGTH, $DELTAME, $VSMECOUNT
    ((TOTALVSMECOUNT++))
    systemctl --user restart mina
  fi
}

function VALIDATEHEIGHTS {
  # if in sync, confirm that blockchain length ~= max observed
  DELTAHEIGHT="$(($BLOCKCHAINLENGTH-$HIGHESTBLOCK))"
  if [[ "$DELTAHEIGHT" -gt "$MAXUNVALIDATEDDELTA" ]] || [[ "$DELTAHEIGHT" -lt -"$MAXUNVALIDATEDDELTA" ]]; then
    ((HEIGHTOFFCOUNT++))
  else
    HEIGHTOFFCOUNT=0
  fi
  DELTAVALIDATED="$(($HIGHESTUNVALIDATEDBLOCK-$HIGHESTBLOCK))"

  if [[ "$DELTAVALIDATED" -gt 5 ]]; then
    echo "Node stuck validated block height delta more than 5 blocks. Difference from Max obvserved and max observied unvalidated:", $DELTAVALIDATED
    ((TOTALSTUCKCOUNT++))
    SYNCCOUNT=0
    systemctl --user restart mina
  fi

  if [[ "$HEIGHTOFFCOUNT" -gt 2 ]]; then
    echo "Restarting mina - Block Chain Length differs from Highest Observed Block by 3 or more", $DELTAHEIGHT, $BLOCKCHAINLENGTH, $HIGHESTBLOCK, $HIGHESTUNVALIDATEDBLOCK, $MINAEXPLORERBLOCKCHAINLENGTH, $DELTAME
    ((TOTALHEIGHTOFFCOUNT++))
    HEIGHTOFFCOUNT=0
    systemctl --user restart mina
  fi
}

INITIALIZEVARS

while :; do
  KNOWNSTATUS=0
  MINA_STATUS="$(mina client status -json | grep -v --regexp="$GARBAGE" )"
  STAT="$(echo $MINA_STATUS | jq .sync_status)"

  if [[ "$STAT" == "\"Synced\"" ]]; then
    KNOWNSTATUS=1
    HIGHESTBLOCK="$(echo $MINA_STATUS | jq .highest_block_length_received)"
    HIGHESTUNVALIDATEDBLOCK="$(echo $MINA_STATUS | jq .highest_unvalidated_block_length_received)"
    BLOCKCHAINLENGTH="$(echo $MINA_STATUS | jq .blockchain_length)"
    VALIDATEHEIGHTS

    if [[ "$USEMINAEXPLORERMONITOR" -eq 1 ]]; then
      CHECKMINAEXPLORER
    fi

    OFFLINECOUNT=0
    CONNECTINGCOUNT=0
    CATCHUPCOUNT=0
    ((SYNCCOUNT++))
  else
    SYNCCOUNT=0
  fi

  if [[ "$STAT" == "\"Connecting\"" ]]; then
    KNOWNSTATUS=1
    ((CONNECTINGCOUNT++))
    ((TOTALCONNECTINGCOUNT++))
  fi
  if [[ "$CONNECTINGCOUNT" -gt 1 ]]; then
    echo "Restarting mina - too long in Connecting state (~10 mins)"
    systemctl --user restart mina
    CONNECTINGCOUNT=0
  fi

  if [[ "$STAT" == "\"Offline\"" ]]; then
    KNOWNSTATUS=1
    ((OFFLINECOUNT++))
    ((TOTALOFFLINECOUNT++))
  fi
  if [[ "$OFFLINECOUNT" -gt 3 ]]; then
    echo "Restarting mina - too long in Offline state (~20 mins)"
    systemctl --user restart mina
    OFFLINECOUNT=0
  fi

  if [[ "$STAT" == "\"Catchup\"" ]]; then
    KNOWNSTATUS=1
    ((CATCHUPCOUNT++))
    ((TOTALCATCHUPCOUNT++))
  fi
  if [[ "$CATCHUPCOUNT" -gt $CATCHUPWINDOW ]]; then
    echo "Restarting mina - too long in Catchup state"
    systemctl --user restart mina
    CATCHUPCOUNT=0
  fi

  if [[ "$STAT" == "\"Bootstrap\"" ]]; then
    #TODO should there be a limit here?
    KNOWNSTATUS=1
  fi

  if [[ "$STAT" == "\"Listening\"" ]]; then
    #TODO limit? what does it mean if hanging out in listening?
    KNOWNSTATUS=1
  fi

  if [[ "$KNOWNSTATUS" -eq 0 ]]; then
    echo "Returned Status is unkown or not handled." $STAT
    echo "Restarting MINA because status unkown"
    systemctl --user restart mina
  fi

  if [[ "$USESNARKSTOPPER" -eq 1 ]]; then
    CHECKSNARKWORKER
  fi

  if [[ "$USEARCHIVEMONITOR" -eq 1 ]]; then
    CHECKARCHIVE
  fi

  if [[ "$USESIDECARMONITOR" -eq 1 ]]; then
    CHECKSIDECAR
  fi

  if [[ "$USEFILEDESCRIPTORSMONITOR" -eq 1 ]]; then
    CHECKFILEDESCRIPTORS
  fi

  echo "Status:" $STAT, "Connecting Count, Total:" $CONNECTINGCOUNT $TOTALCONNECTINGCOUNT, "Offline Count, Total:" $OFFLINECOUNT $TOTALOFFLINECOUNT, "Archive Down Count:" $ARCHIVEDOWNCOUNT, "Node Stuck Below Tip:" $TOTALSTUCKCOUNT, "Total Catchup:" $TOTALCATCHUPCOUNT, "Total Height Mismatch:" $TOTALHEIGHTOFFCOUNT, "Total Mina Explorer Mismatch:" $TOTALVSMECOUNT, "Time Until Block:" $TIMEBEFORENEXTMIN

  sleep 300s
  #check if sleep exited with break (ctrl+c) to exit the loop
  test $? -gt 128 && break;
done
