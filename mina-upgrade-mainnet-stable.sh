#!/bin/bash -x
MINA_VERSION=mina-mainnet=3.2.0-97ad487
ARCHIVE_VERSION=mina-archive=3.2.0-97ad487
CODENAME=$(lsb_release -c --short)

sudo rm /etc/apt/sources.list.d/mina*.list
echo "deb [trusted=yes] http://packages.o1test.net $CODENAME stable" | sudo tee /etc/apt/sources.list.d/mina.list
sudo apt-get -y update

sudo apt-get install -y $MINA_VERSION
sudo apt-get install -y $ARCHIVE_VERSION

systemctl --user restart mina-archive.service
systemctl --user restart mina.service
