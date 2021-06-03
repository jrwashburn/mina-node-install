#!/bin/bash -x
MINA_VERSION=mina-devnet=1.1.6alpha4-74793a2
ARCHIVE_VERSION=mina-archive-devnet=1.1.6alpha4-74793a2
SIDECAR_VERSION=mina-bp-stats-sidecar=1.1.6alpha4-74793a2
THE_SEEDS_URL=https://storage.googleapis.com/seed-lists/devnet_seeds.txt

systemctl --user stop mina-status-monitor.service
systemctl --user stop mina-staking-ledgers-archive.timer
systemctl --user stop mina.service
systemctl --user stop mina-archive.service
systemctl --user stop mina-sidecar.service

echo "deb [trusted=yes] http://packages.o1test.net stretch alpha" | sudo tee /etc/apt/sources.list.d/mina-alpha.list
echo -e "Package: mina-mainnet\nPin: release c=alpha\nPin-priority: 1" | sudo tee /etc/apt/preferences.d/99-mina-alpha
sudo apt-get -y update

sudo apt-get install -y $MINA_VERSION
sudo apt-get install -y $ARCHIVE_VERSION
sudo apt-get install -y $SIDECAR_VERSION

sed -i "s^https://storage.googleapis.com/mina-seed-lists/mainnet_seeds.txt^$THE_SEEDS_URL^g" ~/.mina-env

systemctl --user daemon-reload
systemctl --user start mina-archive.service
systemctl --user start mina.service
systemctl --user start mina-staking-ledgers-archive.timer
systemctl --user start mina-sidecar.service
systemctl --user start mina-status-monitor.service
