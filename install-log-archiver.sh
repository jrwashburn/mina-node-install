#!/bin/bash -x
sudo cp scripts/mina-log-archive-gcs-upload.sh /usr/local/bin/mina-log-archive-gcs-upload.sh
sudo chmod +x /usr/local/bin/mina-log-archive-gcs-upload.sh
sudo cp systemd-units/mina-logs* /etc/systemd/user/

systemctl --user start mina-logs-archive.service
systemctl --user start mina-logs-archive.timer