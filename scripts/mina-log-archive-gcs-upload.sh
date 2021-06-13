# depends on gsutil - if not present, install as below
# curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -
# sudo apt-get -y update && sudo apt-get install -y  google-cloud-sdk
# gcloud init

echo "Exporting mina logs"
mina client export-logs
for gzlogfile in ~/.mina-config/exported_logs/*.tar.gz; do
  echo "Uploading $gzlogfile to GCS"
  gsutil cp $gzlogfile gs://mina-node-logs
  if [ $? = 0 ]; then
    mv $gzlogfile $gzlogfile.del
  else
    echo "Uploading $gzlogfile failed - will try again next cycle"
  fi
done