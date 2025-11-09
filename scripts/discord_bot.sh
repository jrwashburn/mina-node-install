# from https://github.com/t4top/mina-node-discord-bot/blob/main/discord_bot.sh
#!/bin/bash

# Discord Webhook URL. It'll be set by the install.sh script
WEBHOOK_URL="<YOUR_DISCORD_WEBHOOK_URL>"

CURL=/usr/bin/curl
MINA=/usr/local/bin/mina

# get useful status info from mina client
status=$($MINA client status | grep -E "Block height:|Local uptime:|Peers:|Sync status:|Block producers running:|Next block will be produced in:|Consensus time now:")

# get disk usage
disk=$(df -H | awk '{ if ($6=="/") printf "Filesystem: %s\\nMounted on: /\\nTotal: %s\\nAvail: %s\\nUsed: %s\\nUse%%: %s\\n", $1, $2, $4, $3, $5}')

# get memory usage
mem=$(free -h --si | awk -v ORS='\\n' 'NR>1{print $1" "$4" / "$2" Free, "$3" / "$2" Used"}')

# prepare Discord notification payload
payload=$(cat <<-END
{
  "embeds": [
    {
      "color": "14177041",
      "fields": [
        {
          "name": "Hostname",
          "value": "$(hostname)"
        },
        {
          "name": "Mina Client Status",
          "value": "$(echo ${status//$'\n'/'\n'})"
        },
        {
          "name": "Disk Usage",
          "value": "$disk"
        },
        {
          "name": "Memory Usage",
          "value": "$mem"
        }
      ]
    }
  ]
}
END
)

# send the notification to Discord channel
$CURL -sL -X POST $WEBHOOK_URL -H 'Content-Type: application/json' -d "$payload"