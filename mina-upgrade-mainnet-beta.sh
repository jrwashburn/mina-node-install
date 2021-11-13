#!/bin/bash -x
MINA_VERSION=mina-mainnet=1.2.1beta1-45440dc
ARCHIVE_VERSION=mina-archive-mainnet=1.2.1beta1-45440dc

systemctl --user stop mina-status-monitor.service
systemctl --user stop mina-staking-ledgers-archive.timer
systemctl --user stop mina.service
systemctl --user stop mina-archive.service

echo "deb [trusted=yes] http://packages.o1test.net stretch beta" | sudo tee /etc/apt/sources.list.d/mina-beta.list
sudo apt-get -y update

sudo apt-get install -y $MINA_VERSION
sudo apt-get install -y $ARCHIVE_VERSION
sudo cp partial-configs/mina-sidecar.json /etc/

systemctl --user daemon-reload
systemctl --user start mina-archive.service
systemctl --user start mina.service
echo "going to sleeep for 5 minutes to let daemon bootstrap"
sleep 5m
systemctl --user start mina-staking-ledgers-archive.timer
systemctl --user start mina-status-monitor.service
