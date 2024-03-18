#!/bin/bash -x
MINA_VERSION=mina-mainnet=1.4.1-e76fc1c
ARCHIVE_VERSION=mina-archive=1.4.1-e76fc1c
CODENAME=$(lsb_release -c --short)

#systemctl --user stop mina-status-monitor.service
#systemctl --user stop mina-staking-ledgers-archive.timer
#systemctl --user stop mina.service
#systemctl --user stop mina-archive.service

sudo rm /etc/apt/sources.list.d/mina*.list
echo "deb [trusted=yes] http://packages.o1test.net $CODENAME stable" | sudo tee /etc/apt/sources.list.d/mina.list
sudo apt-get -y update

sudo apt-get install -y $MINA_VERSION
sudo apt-get install -y $ARCHIVE_VERSION

systemctl --user daemon-reload
systemctl --user restart mina-archive.service
systemctl --user restart mina.service
systemctl --user restart mina-staking-ledgers-archive.timer
