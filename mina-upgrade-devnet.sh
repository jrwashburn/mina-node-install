#!/bin/bash -x
MINA_VERSION=mina-devnet=3.3.0-alpha1-6929a7e
ARCHIVE_VERSION=mina-archive-devnet=3.3.0-alpha1-6929a7e
CODENAME=$(lsb_release -c --short)

sudo rm /etc/apt/sources.list.d/mina*.list
#echo "deb [trusted=yes] http://packages.o1test.net $CODENAME beta" | sudo tee /etc/apt/sources.list.d/mina-beta.list
echo "deb [trusted=yes] http://packages.o1test.net $CODENAME alpha" | sudo tee /etc/apt/sources.list.d/mina-alpha.list
sudo apt-get -y update

sudo apt-get install -y $MINA_VERSION
sudo apt-get install -y $ARCHIVE_VERSION

systemctl --user start mina-archive.service
systemctl --user start mina.service
