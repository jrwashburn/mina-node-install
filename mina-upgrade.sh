#!/bin/bash -x

systemctl --user stop mina-status-monitor.service
systemctl --user stop mina-staking-ledgers-archive.timer
systemctl --user stop mina.service
systemctl --user stop mina-archive.service

sudo apt-get remove -y mina-testnet-postake-medium-curves
echo "deb [trusted=yes] http://packages.o1test.net release main" | sudo tee /etc/apt/sources.list.d/mina.list
sudo apt-get -y update
sudo apt-get install -y curl unzip mina-testnet-postake-medium-curves=1.0.5-68200c7
sudo apt-get install -y mina-archive=1.0.5-68200c7

systemctl --user daemon-reload
systemctl --user start mina-archive.service
systemctl --user start mina.service
systemctl --user start mina-staking-ledgers-archive.timer
systemctl --user start mina-status-monitor.service
