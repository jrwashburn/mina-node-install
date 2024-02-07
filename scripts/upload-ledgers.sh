#!/bin/bash
# login information
USERNAME=""
PASSWORD=""
# Directory containing the JSON files
DIR="$1"
ARCHIVE_DIR="$1/uploaded"

# Ensure the archive directory exists
mkdir -p "$ARCHIVE_DIR"

# Iterate over all JSON files in the directory
for FILE in "$DIR"/*.json; do
    # Extract the base name of the file (without directory path)
    BASE=$(basename $FILE)
    HASH=$(basename $FILE .json)

    echo "Uploading $FILE for hash $BASE:"

    # Upload the file and capture the HTTP status code
    STATUS_CODE=$(curl -k -u "$USERNAME:$PASSWORD" -X POST -H "Content-Type: multipart/form-data" -F jsonFile=@"$FILE" https://ncapi.minastakes.com/staking-ledgers/$HASH  -w "%{http_code}" -o /dev/null)
    echo "Status code: $STATUS_CODE"
    # Check if the upload was successful
    if (( $STATUS_CODE == 200 )) ; then
        echo "Successfully posted ledger...Archiving $FILE..."
        mv "$FILE" "$ARCHIVE_DIR/$BASE"
        echo "Archived $FILE"
    elif (( $STATUS_CODE == 409 )) ; then
        echo "Ledger already exists...Archiving $FILE..."
        mv "$FILE" "$ARCHIVE_DIR/$BASE"
        echo "Archived $FILE"
    else
        echo "UNKNOWN STATUS - Assuming failed to upload $FILE, status code: $STATUS_CODE"
    fi

    sleep 3
done

