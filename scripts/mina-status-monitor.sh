# Not sure why this is still in shell...but...we're here now.
#Credit to _thanos for the original snarkstopper - https://forums.minaprotocol.com/t/guide-script-automagically-stops-snark-work-prior-of-getting-a-block-proposal/299
#Credit to @vanphandinh for docker port, re-integrating some of those changes here from https://github.com/vanphandinh/mina-status-monitor/blob/master/mina-status-monitor.sh

#General Parameters
readonly MONITORCYCLE=300 #how many seconds between mina client status checks (e.g. 60s * 5min = 300)
readonly CATCHUPWINDOW=18 #how many MONITORCYCLE intervals to wait for catchup before restart (12 * 5mins = 60 mins)
readonly MAXUNVALIDATEDDELTA=3 #will count as out of compliance if more than this many blocks ahead or behind unvalidated count
readonly MAXSTATUSFAILURE=2 #will allow upt to this number of cycles to of status failure before force restart
readonly STANDOFFAFTERRESTART=2 #how many MONITORSYCLCE intervals should be allowed for daemon to try to restart before issuing another restart
readonly GARBAGE="Using password from environment variable CODA_PRIVKEY_PASS" #strip this out of the status

# Monitoring docker containers via graphql instead of daemon locally
# Set MONITORVIAGRAPHQL = 0 to use local `mina client` commands. If set to 1, provide GRAPHQL_URI, or it will attempt to detect from docker - assumes instance named mina
readonly USEDOCKER=0

#Snark Stopper
readonly USESNARKSTOPPER=1 #set to 1 to run snark stopper, 0 to turn it off (will stop snarking if not in sync, or producing a block soon)
SNARKWORKERTURNEDOFF=1 #set to 1 to assume snark worker should always be turned on for first run, otherwise 0
readonly STOPSNARKINGLESSTHAN=5 #threshold in minutes to stop snarking - if minutes until produce block < this value, will stop snark worker
readonly FEE=YOUR_SW_FEE ### *** SET YOUR SNARK WORKER FEE HERE *** ###
readonly SW_ADDRESS=YOUR_SW_ADDRESS ### *** SET YOUR SNARK WORKER ADDRESS HERE *** ###

#Sidecar Monitoring
readonly USESIDECARMONITOR=1 #set to 1 to monitor sidecar service, 0 ignores sidecar monitoring

#Archive Monitoring - Not currently supported with Docker - set to 0 if USEDOCKER=1
readonly USEARCHIVEMONITOR=1 #set to 1 to monitor archive service, 0 ignores archive monitoring

#Compare to Mina Explorer Height
readonly USEMINAEXPLORERMONITOR=0 #set to 1 to compare synced height vs. Mina Explorer reported height, 0 does not check MinaExplorer
readonly MINAEXPLORERMAXDELTA=3 #number of blocks to tolerate in synced blockheight vs. Mina Explorers reported height
readonly MINAEXPLORERTOLERANCEWINDOW=5 #how many intervals to wait to restart with coninual out of sync vs. mina explorer
readonly MINAEXPLORERURL=https://api.minaexplorer.com #url to get status from mina explorer -- devnet: https://devnet.api.minaexplorer.com

#File Descriptor Monitoring - Not currently supported with Docker - set to 0 if USEDOCKER=1
#if turned on, this dumps lsof to /tmp and does not clean up after itself - keep an eye on that!
readonly USEFILEDESCRIPTORSMONITOR=0 #set to 1 to turn on file descriptor logging, 0 to turn it on

function INITIALIZEVARS {
  readonly SECONDS_PER_MINUTE=60
  readonly SECONDS_PER_HOUR=3600
  readonly MINUTES_PER_HOUR=60
  readonly HOURS_PER_DAY=24
  MINA_STATUS=""
  STAT=""
  NEXTBLOCK=""
  UPTIMESECS=0
  STATUSFAILURES=0
  DAEMONRESTARTCOUNTER=0
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

function CHECKCONFIG {

  #Get Graphql endpoint form docker inpect
  if [[ "$USEDOCKER" -eq 1 ]]; then
    if [[ "$USEARCHIVEMONITOR" -eq 1  || "$USEFILEDESCRIPTORSMONITOR" -eq 1 ]]; then
      echo "USEDOCKER is set, but Archive and File Descriptor Monitoring also turned on."
      echo "Archive and File Descriptor monitoring are not currently supported for docker"
      exit 1
    fi
    GRAPHQL_URI="$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' mina)"
    if [[ "$GRAPHQL_URI" != "" ]]; then
      GRAPHQL_URI="http://$GRAPHQL_URI:3085/graphql"
    else
      echo "unable to get graphql URI and USEDOCKER is set"
      exit 1
    fi
  fi


}

#################### ADD DOCKER SUPPORT #######################
function RESTARTMINADAEMON {
  ((DAEMONRESTARTCOUNTER++))
  if [[ "$DAEMONRESTARTCOUNTER" -eq "$STANDOFFAFTERRESTART" ]]; then
    if [[ "$USEDOCKER" -eq 0 ]]; then
      echo "Restarting MINA using systemd"
      systemctl --user restart mina
    else
      echo "Restarting MINA using docker restart"
      docker restart mina
    fi
  else
    echo "Not restarting MINA Daemon yet because STANDOFFAFTERRESTART not met yet. counter, standoff:", $DAEMONRESTARTCOUNTER, $STANDOFFAFTERRESTART
  fi
}

function RESTARTARCHIVESERVICE {
  if [[ "$USEDOCKER" -eq 0 ]]; then
    systemctl --user restart mina-archive.service
  else
    echo "Docker monitoring not supported for archive service"
  fi
}

function RESTARTSIDECAR {
  if [[ "$USEDOCKER" -eq 0 ]]; then
    systemctl --user restart mina-sidecar.service
  else
    docker restart mina-sidecar
  fi
}

function STARTSNARKING {
  if [[ "$USEDOCKER" -eq 0 ]]; then
    mina client set-snark-worker -address $SW_ADDRESS
    mina client set-snark-work-fee $FEE
  else
    docker exec -t mina mina client set-snark-worker --address $SW_ADDRESS
    docker exec -t mina mina client set-snark-work-fee $FEE
  fi
}

function STOPSNARKING {
  if [[ "$USEDOCKER" -eq 0 ]]; then
    mina client set-snark-worker
  else
    docker exec -t mina mina client set-snark-worker
  fi
}

function GETDAEMONSTATUS {
  if [[ "$USEDOCKER" -eq 0 ]]; then
    MINA_STATUS="$(mina client status -json | grep -v --regexp="$GARBAGE" )"
    if [[ "$MINA_STATUS" == "" ]]; then
      echo "Did not get Mina Client Status."
    else
      STAT="$(echo $MINA_STATUS | jq .sync_status)"
      if [[ "$STAT" == "\"Synced\"" ]]; then
        BLOCKCHAINLENGTH="$(echo $MINA_STATUS | jq .blockchain_length)"
        HIGHESTBLOCK="$(echo $MINA_STATUS | jq .highest_block_length_received)"
        HIGHESTUNVALIDATEDBLOCK="$(echo $MINA_STATUS | jq .highest_unvalidated_block_length_received)"
        UPTIMESECS="$(echo $MINA_STATUS | jq .uptime_secs)"
      fi
    fi
  else
     MINA_STATUS=$(curl $GRAPHQL_URI -s --max-time 60 \
    -H 'content-type: application/json' \
    --data-raw '{"operationName":null,"variables":{},"query":"{\n  daemonStatus {\n    syncStatus\n    uptimeSecs\n    blockchainLength\n    highestBlockLengthReceived\n    highestUnvalidatedBlockLengthReceived\n    nextBlockProduction {\n      times {\n        startTime\n      }\n    }\n  }\n}\n"}' \
    --compressed)
    if [[ "$MINA_STATUS" == "" ]]; then
      echo "Cannot connect to the GraphQL endpoint $GRAPHQL_URI."
      #sleep 10s  #not sure why sleeping here is useful -- removing.
    else
      STAT="$(echo $MINA_STATUS | jq .data.daemonStatus.syncStatus)"
      if [[ "$STAT" == "\"Synced\"" ]]; then
        BLOCKCHAINLENGTH="$(echo $MINA_STATUS | jq .data.daemonStatus.blockchainLength)"
        HIGHESTBLOCK="$(echo $MINA_STATUS | jq .data.daemonStatus.highestBlockLengthReceived)"
        HIGHESTUNVALIDATEDBLOCK="$(echo $MINA_STATUS | jq .data.daemonStatus.highestUnvalidatedBlockLengthReceived)"
        NEXTPROP="$(echo $MINA_STATUS | jq .data.daemonStatus.nextBlockProduction.times[0].startTime)"
        UPTIMESECS="$(echo $MINA_STATUS | jq .data.daemonStatus.uptimeSecs)"
      fi
    fi
  fi
}

function GETSIDECARSTATUS {
  # to enable sidecar monitoring, the user requires journalctl rights
  # this command will provide access, but requires you to log out and log back in / restart service
  # sudo usermod -aG systemd-journal [USER]
  if [[ "$USEDOCKER" -eq 0 ]]; then
    SIDECARREPORTING="$(journalctl --user-unit mina-sidecar.service --since "10 minutes ago" | grep -c 'Got block data')"
  else
    SIDECARREPORTING="$(docker logs --since 10m mina-sidecar 2>&1 | grep -c 'Got block data')"
  fi
}

#################### END DOCKER SUPPORT #######################

function GETARCHIVESTATUS {
  #TODO this should be improved to monitor something useful....TBD what that might be
  if [[ "$USEDOCKER" -eq 0 ]]; then
    ARCHIVERUNNING="$(ps -A | grep mina-archive | wc -l)"
  else
    echo "NOT SETUP TO CHECK ARCHIVE ON DOCKER"
  fi
}

function CHECKFILEDESCRIPTORS {
  MINAUSER="minar" #set to userid the mina service runs under (will be used to monitor file descriptor of that user)
  FDLIMIT=$(ulimit -n)
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
  GETARCHIVESTATUS
  if [[ "$ARCHIVERUNNING" -gt 0 ]]; then
    ARCHIVERUNNING=0
  else
    ((ARCHIVEDOWNCOUNT++))
    echo "Restarting mina-Archive Service. Archive Down Count:", $ARCHIVEDOWNCOUNT
    RESTARTARCHIVESERVICE
  fi
}

function CHECKSIDECAR {
  GETSIDECARSTATUS
  if [[ "$SIDECARREPORTING" -lt 3 && "$SYNCCOUNT" -gt 2 ]]; then
    echo "Restarting mina-sidecar - only reported " $SIDECARREPORTING " times out in 10 mins and node in sync longer than 15 mins."
    RESTARTSIDECAR
  fi
}

function MANAGESNARKER {
  if [[ "$STAT" == "\"Synced\"" ]]; then
    # Calculate whether block producer will run within the next X mins
    # If up for a block within 5 mins, stop snarking, resume on next pass
    # First check if we are going to produce a block
    if [[ "$USEDOCKER" -eq 0  ]]; then
      PRODUCER="$(echo $MINA_STATUS | jq .next_block_production.timing[0])"
      if [[ "$PRODUCER" == "\"Produce\"" ]]; then
        NEXTPROP="$(echo $MINA_STATUS | jq .next_block_production.timing[1].time)"
        NEXTPROP="${NEXTPROP::-3}"
        NEXTPROP="${NEXTPROP:1}"
        NEXTPROP="${NEXTPROP:0:-1}"
        #NOW="$(date +%s%N | cut -b1-13)"
        #TIMEBEFORENEXT="$(($NEXTPROP-$NOW))"
        #TIMEBEFORENEXTSEC="${TIMEBEFORENEXT:0:-3}"
        #TIMEBEFORENEXTMIN="$((${TIMEBEFORENEXTSEC} / ${SECONDS_PER_MINUTE}))"
      else
        echo "Next block production time unknown"
        if [[ "$SNARKWORKERTURNEDOFF" -gt 0 ]]; then
          echo "Starting the snark worker.."
          STARTSNARKING
          SNARKWORKERTURNEDOFF=0
        fi
        return 0
      fi
    else
      if [[ $NEXTPROP != null ]]; then
        #DOCKER IMPL
        NEXTPROP=$(echo $NEXTPROP | jq tonumber)
        NEXTPROP="${NEXTPROP::-3}"
      else
        echo "Next block production time unknown"
        if [[ "$SNARKWORKERTURNEDOFF" -gt 0 ]]; then
          echo "Starting the snark worker.."
          STARTSNARKING
          SNARKWORKERTURNEDOFF=0
        fi
        return 0
      fi
    fi

    NOW="$(date +%s)"
    TIMEBEFORENEXT="$(($NEXTPROP - $NOW))"
    TIMEBEFORENEXTMIN="$(($TIMEBEFORENEXT / $SECONDS_PER_MINUTE))"
    MINS="$(($TIMEBEFORENEXTMIN % $MINUTES_PER_HOUR))"
    HOURS="$(($TIMEBEFORENEXTMIN / $MINUTES_PER_HOUR))"
    DAYS="$(($HOURS / $HOURS_PER_DAY))"
    HOURS="$(($HOURS % $HOURS_PER_DAY))"
    NEXTBLOCK="Next block production: $DAYS days $HOURS hours $MINS minutes"

    if [[ "$TIMEBEFORENEXTMIN" -lt "$STOPSNARKINGLESSTHAN" && "$SNARKWORKERTURNEDOFF" -eq 0 ]]; then
      echo "Stop snarking - producing a block soon"
      STOPSNARKING
      ((SNARKWORKERTURNEDOFF++))
    else
      if [[ "$TIMEBEFORENEXTMIN" -gt "$STOPSNARKINGLESSTHAN" && "$SNARKWORKERTURNEDOFF" -gt 0 ]]; then
          STARTSNARKING
          SNARKWORKERTURNEDOFF=0
      fi
    fi

  else # stop snarking if not in sync
    if [[ "$SNARKWORKERTURNEDOFF" -eq 0 ]]; then
      echo "Stop snarking - node is not in sync"
      STOPSNARKING
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
    RESTARTMINADAEMON
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
    RESTARTMINADAEMON
  fi

  if [[ "$HEIGHTOFFCOUNT" -gt 2 ]]; then
    echo "Restarting mina - Block Chain Length differs from Highest Observed Block by 3 or more", $DELTAHEIGHT, $BLOCKCHAINLENGTH, $HIGHESTBLOCK, $HIGHESTUNVALIDATEDBLOCK, $MINAEXPLORERBLOCKCHAINLENGTH, $DELTAME
    ((TOTALHEIGHTOFFCOUNT++))
    HEIGHTOFFCOUNT=0
    RESTARTMINADAEMON
  fi
}

INITIALIZEVARS

CHECKCONFIG

while :; do
  KNOWNSTATUS=0
  GETDAEMONSTATUS

  if [[ "$STAT" == "\"Synced\"" ]]; then
    VALIDATEHEIGHTS

    KNOWNSTATUS=1
    OFFLINECOUNT=0
    CONNECTINGCOUNT=0
    CATCHUPCOUNT=0
    ((SYNCCOUNT++))
    if [[ "$USEMINAEXPLORERMONITOR" -eq 1 ]]; then
      CHECKMINAEXPLORER
    fi
  else
    SYNCCOUNT=0
  fi

  if [[ "$STAT" == "\"Connecting\"" ]]; then
    KNOWNSTATUS=1
    ((CONNECTINGCOUNT++))
    ((TOTALCONNECTINGCOUNT++))
  fi
  if [[ "$CONNECTINGCOUNT" -gt 1 ]]; then
    echo "Restarting mina - too long in Connecting state (2 cycles)"
    RESTARTMINADAEMON
    CONNECTINGCOUNT=0
  fi

  if [[ "$STAT" == "\"Offline\"" ]]; then
    KNOWNSTATUS=1
    ((OFFLINECOUNT++))
    ((TOTALOFFLINECOUNT++))
  fi
  if [[ "$OFFLINECOUNT" -gt 2 ]]; then
    echo "Restarting mina - too long in Offline state (3 cycles)"
    RESTARTMINADAEMON
    OFFLINECOUNT=0
  fi

  if [[ "$STAT" == "\"Catchup\"" ]]; then
    KNOWNSTATUS=1
    ((CATCHUPCOUNT++))
    ((TOTALCATCHUPCOUNT++))
  fi
  if [[ "$CATCHUPCOUNT" -gt $CATCHUPWINDOW ]]; then
    echo "Restarting mina - too long in Catchup state"
    RESTARTMINADAEMON
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
    echo "Returned Status is unkown or not handled:" $STAT
    ((STATUSFAILURES++))
    if [[ STATUSFAILURES -eq "$MAXSTATUSFAILURE" ]]; then
      RESTARTMINADAEMON
    fi
  else
    STATUSFAILURES=0
    DAEMONRESTARTCOUNTER=0
    if [[ "$USESNARKSTOPPER" -eq 1 ]]; then
      MANAGESNARKER
    fi

    if [[ "$USEARCHIVEMONITOR" -eq 1 ]]; then
      CHECKARCHIVE
    fi

    if [[ "$USESIDECARMONITOR" -eq 1 ]]; then
      CHECKSIDECAR
    fi
  fi

  if [[ "$USEFILEDESCRIPTORSMONITOR" -eq 1 ]]; then
    CHECKFILEDESCRIPTORS
  fi

  echo $(date) "Status:" $STAT, "Connecting Count, Total:" $CONNECTINGCOUNT $TOTALCONNECTINGCOUNT, "Offline Count, Total:" $OFFLINECOUNT $TOTALOFFLINECOUNT, "Archive Down Count:" $ARCHIVEDOWNCOUNT, "Node Stuck Below Tip:" $TOTALSTUCKCOUNT, "Total Catchup:" $TOTALCATCHUPCOUNT, "Total Height Mismatch:" $TOTALHEIGHTOFFCOUNT, "Total Mina Explorer Mismatch:" $TOTALVSMECOUNT, "Time Until Block:" $TIMEBEFORENEXTMIN, $NEXTBLOCK, "Current Status Failures:" $STATUSFAILURES, "Uptime Hours:" $(($UPTIMESECS / $SECONDS_PER_HOUR)), "Uptime Total Min:" $(($UPTIMESECS / $SECONDS_PER_MINUTE))
  sleep $MONITORCYCLE
  #check if sleep exited with break (ctrl+c) to exit the loop
  test $? -gt 128 && break;
done
