#!/bin/bash -x
MINA_VERSION=mina-mainnet=3.3.0-beta1-5b0a889
ARCHIVE_VERSION=mina-archive-mainnet=3.3.0-beta1-5b0a889
CODENAME=$(lsb_release -c --short)

sudo rm /etc/apt/sources.list.d/mina*.list
echo "deb [trusted=yes] http://packages.o1test.net $CODENAME beta" | sudo tee /etc/apt/sources.list.d/mina-beta.list
sudo apt-get -y update

sudo apt-get install -y $MINA_VERSION
sudo apt-get install -y $ARCHIVE_VERSION

systemctl --user start mina-archive.service
systemctl --user start mina.service
