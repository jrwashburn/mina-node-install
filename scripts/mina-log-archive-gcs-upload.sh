# depends on gsutil - if not present, install as below
# curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -
# sudo apt-get -y update && sudo apt-get install -y  google-cloud-sdk
# gcloud init
echo "Exporting mina logs for $(hostname)"
mina client export-logs
for GZLOGFILE in ~/.mina-config/exported_logs/*.tar.gz; do
  UPLOADFILENAME=$(hostname)$(echo _)$(basename $GZLOGFILE)
  echo "Uploading $GZLOGFILE to GCS $UPLOADFILENAME"
  gsutil cp $GZLOGFILE gs://mina-node-logs/$UPLOADFILENAME
  if [ $? = 0 ]; then
    rm $GZLOGFILE 
  else
    echo "Uploading $GZLOGFILE failed - will try again next cycle"
  fi
done