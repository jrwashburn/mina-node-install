#!/bin/bash -x
MINA_VERSION=mina-mainnet=4.0.4-c9e2eac
ARCHIVE_VERSION=mina-archive-mainnet=4.0.4-c9e2eac
CODENAME=$(lsb_release -c --short)

sudo rm /etc/apt/sources.list.d/mina*.list
echo "deb [trusted=yes] http://packages.o1test.net $CODENAME stable" | sudo tee /etc/apt/sources.list.d/mina.list
sudo apt-get -y update

sudo apt-get install -y --allow-downgrades $MINA_VERSION
sudo apt-get install -y --allow-downgrades $ARCHIVE_VERSION

systemctl --user restart mina-archive.service
systemctl --user restart mina.service
