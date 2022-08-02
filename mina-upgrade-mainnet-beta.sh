#!/bin/bash -x
MINA_VERSION=mina-mainnet=1.3.2beta2-6e4c7fc
ARCHIVE_VERSION=mina-archive-mainnet=1.3.2beta2-6e4c7fc
CODENAME=$(lsb_release -c --short)

systemctl --user stop mina-status-monitor.service
systemctl --user stop mina-staking-ledgers-archive.timer
systemctl --user stop mina.service
systemctl --user stop mina-archive.service

echo "deb [trusted=yes] http://packages.o1test.net $CODENAME beta" | sudo tee /etc/apt/sources.list.d/mina-beta.list
sudo apt-get -y update

sudo apt-get install -y $MINA_VERSION
sudo apt-get install -y $ARCHIVE_VERSION

systemctl --user daemon-reload
#systemctl --user start mina-archive.service
systemctl --user start mina.service
echo "going to sleeep for 5 minutes to let daemon bootstrap"
sleep 5m
systemctl --user start mina-staking-ledgers-archive.timer
systemctl --user start mina-sidecar.service
#systemctl --user start mina-status-monitor.service
