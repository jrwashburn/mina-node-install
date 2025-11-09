#!/bin/bash
# login information
USERNAME=""
PASSWORD=""
# Directory containing the JSON files
YOUR_LEDGER_DIRECTORY="/home/minar/ledger-archives"
GARBAGE="Using password from environment variable CODA_PRIVKEY_PASS"
/usr/local/bin/mina ledger export staking-epoch-ledger | grep -v --regexp="$GARBAGE" > "$YOUR_LEDGER_DIRECTORY/staking-epoch-ledger.json"
/usr/local/bin/mina ledger export next-epoch-ledger | grep -v --regexp="$GARBAGE" > "$YOUR_LEDGER_DIRECTORY/next-epoch-ledger.json"

for LEDGER in staking-epoch-ledger next-epoch-ledger; do
    NEW_FILE=$(/usr/local/bin/mina ledger hash --ledger-file "$YOUR_LEDGER_DIRECTORY/$LEDGER.json" | xargs -I % echo "$YOUR_LEDGER_DIRECTORY/%.json")
    echo will create $NEW_FILE
    #mv "$YOUR_LEDGER_DIRECTORY/$LEDGER.json" "$NEW_FILE"
    cp "$YOUR_LEDGER_DIRECTORY/$LEDGER.json" "$NEW_FILE"
    HASH=$(basename "$NEW_FILE" .json)

    echo "Uploading $NEW_FILE for hash $HASH:"
    # Upload the file and capture the HTTP status code
    STATUS_CODE=$(curl -k -u "$USERNAME:$PASSWORD" -X POST -H "Content-Type: multipart/form-data" -F jsonFile=@"$NEW_FILE" https://ncapi.minastakes.com/staking-ledgers/$HASH  -w "%{http_code}" -o /dev/null)
    echo "Status code: $STATUS_CODE"
    # Check if the upload was successful
    if (( $STATUS_CODE == 200 )) ; then
        echo "Successfully posted ledger...Archiving $NEW_FILE..."
        mv "$NEW_FILE" "$YOUR_LEDGER_DIRECTORY/uploaded/$HASH.json"
        echo "Archived $NEW_FILE"
    elif (( $STATUS_CODE == 409 )) ; then
        echo "Ledger already exists...Archiving $NEW_FILE..."
        mv "$NEW_FILE" "$YOUR_LEDGER_DIRECTORY/uploaded/$HASH.json"
        echo "Archived $NEW_FILE"
    else
        echo "UNKNOWN STATUS - Assuming failed to upload $NEW_FILE, status code: $STATUS_CODE"
        echo leaving file $NEW_FILE in place
    fi
done