#!/bin/bash -x
MINA_VERSION=mina-mainnet=1.1.3-48401e9
ARCHIVE_VERSION=mina-archive=1.1.3-48401e9
SIDECAR_VERSION=mina-bp-stats-sidecar=1.1.3-48401e9

systemctl --user stop mina-status-monitor.service
systemctl --user stop mina-staking-ledgers-archive.timer
systemctl --user stop mina.service
systemctl --user stop mina-archive.service

sudo apt-get remove -y mina-testnet-postake-medium-curves
sudo apt-get remove -y mina-mainnet
echo "deb [trusted=yes] http://packages.o1test.net release main" | sudo tee /etc/apt/sources.list.d/mina.list
sudo apt-get -y update
sudo apt-get install -y curl unzip $MINA_VERSION
sudo apt-get install -y $ARCHIVE_VERSION
sudo apt-get install -y $SIDECAR_VERSION

systemctl --user daemon-reload
systemctl --user start mina-archive.service
systemctl --user start mina.service
systemctl --user start mina-staking-ledgers-archive.timer
systemctl --user start mina-status-monitor.service
