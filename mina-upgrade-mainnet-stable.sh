#!/bin/bash -x
MINA_VERSION=mina-mainnet=1.3.1.2-25388a0
ARCHIVE_VERSION=mina-archive=1.3.1.2-25388a0
SIDECAR_VERSION=mina-bp-stats-sidecar=1.3.1.2-25388a0
CODENAME=$(lsb_release -c --short)

systemctl --user stop mina-status-monitor.service
systemctl --user stop mina-staking-ledgers-archive.timer
systemctl --user stop mina.service
systemctl --user stop mina-archive.service
systemctl --user stop mina-sidecar.service

sudo rm /etc/apt/sources.list.d/mina*.list
echo "deb [trusted=yes] http://packages.o1test.net $CODENAME stable" | sudo tee /etc/apt/sources.list.d/mina.list
sudo apt-get -y update

sudo apt-get install -y $MINA_VERSION
sudo apt-get install -y $ARCHIVE_VERSION
sudo apt-get install -y $SIDECAR_VERSION
sudo cp partial-configs/mina-sidecar.json /etc/

systemctl --user daemon-reload
#systemctl --user start mina-archive.service
systemctl --user start mina.service
echo "going to sleep for 1 minute to let daemon startup"
sleep 1m
systemctl --user start mina-staking-ledgers-archive.timer
systemctl --user start mina-sidecar.service
#systemctl --user start mina-status-monitor.service
