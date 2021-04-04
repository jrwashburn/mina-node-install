#!/bin/bash -x
MINA_VERSION=mina-mainnet=1.1.5beta1+-master-qa-a42bdee
ARCHIVE_VERSION=mina-archive=1.1.5beta1+-master-qa-a42bdee
SIDECAR_VERSION=mina-bp-stats-sidecar=1.1.5beta1+-master-qa-a42bdee

systemctl --user stop mina-status-monitor.service
systemctl --user stop mina-staking-ledgers-archive.timer
systemctl --user stop mina.service
systemctl --user stop mina-archive.service
systemctl --user stop mina-sidecar.service

echo "deb [trusted=yes] http://packages.o1test.net pre-release main" | sudo tee /etc/apt/sources.list.d/mina.list
sudo apt-get -y update
sudo apt-get install -y mina-mainnet=1.1.5beta1+-master-qa-a42bdee
sudo apt-get install -y curl unzip $MINA_VERSION
sudo apt-get install -y $ARCHIVE_VERSION
sudo apt-get install -y $SIDECAR_VERSION

systemctl --user daemon-reload
systemctl --user start mina-archive.service
systemctl --user start mina.service
systemctl --user start mina-staking-ledgers-archive.timer
systemctl --user start mina-sidecar.service
systemctl --user start mina-status-monitor.service
