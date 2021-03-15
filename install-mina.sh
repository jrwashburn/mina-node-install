#!/bin/bash -x
INSTALL_MINA_POOL_PAYOUT=true

# update your values - these will update the scripts to be installed with these parameters
YOUR_SW_FEE=0.25
YOUR_SW_ADDRESS=B62qkBqSkXgkirtU3n8HJ9YgwHh3vUD6kGJ5ZRkQYGNPeL5xYL2tL1L
YOUR_LEDGER_ARCHIVE_DIRECTORY=/home/minar/ledger-archives
THE_SEEDS_URL=https://storage.googleapis.com/seed-lists/devnet_seeds.txt
YOUR_WALLET_FILE=~/keys/my-wallet
YOUR_COINBASE_RECEIVER=B62qoigHEtJCoZ5ekbGHWyr9hYfc6fkZ2A41h9vvVZuvty9amzEz3yB

YOUR_HOST_IP="$(curl https://api.ipify.org)"

#update status-watchdog with specific fee and snark worker address, place in usr/local/bin 
mkdir -p $YOUR_LEDGER_ARCHIVE_DIRECTORY
mkdir -p ~/keys

sed -i "s/YOUR_SW_FEE/$YOUR_SW_FEE/g" scripts/mina-status-monitor.sh
sed -i "s/YOUR_SW_ADDRESS/$YOUR_SW_ADDRESS/g" scripts/mina-status-monitor.sh
sed -i "s^YOUR_LEDGER_DIRECTORY^$YOUR_LEDGER_ARCHIVE_DIRECTORY^g" scripts/mina-export-ledgers.sh

sed -i "s^THE_SEEDS_URL^$THE_SEEDS_URL^g" partial-configs/mina-env
sed -i "s^YOUR_WALLET_FILE^$YOUR_WALLET_FILE^g" partial-configs/mina-env
sed -i "s/YOUR_SW_ADDRESS/$YOUR_SW_ADDRESS/g" partial-configs/mina-env
sed -i "s/YOUR_SW_FEE/$YOUR_SW_FEE/g" partial-configs/mina-env
sed -i "s/YOUR_COINBASE_RECEIVER/$YOUR_COINBASE_RECEIVER/g" partial-configs/mina-env
sed -i "s/YOUR_HOST_IP/$YOUR_HOST_IP/g" partial-configs/mina-env

sudo cp scripts/mina-status-monitor.sh /usr/local/bin/mina-status-monitor.sh
sudo cp scripts/mina-export-ledgers.sh /usr/local/bin/mina-export-ledgers.sh
sudo chmod +x /usr/local/bin/mina-status-monitor.sh
sudo chmod +x /usr/local/bin/mina-export-ledgers.sh
sudo cp systemd-units/mina* /etc/systemd/user/

cp partial-configs/mina-env ~/.mina-env
cp partial-configs/mina-archive-env ~/.mina-archive-env

sudo apt-get -y install bc
sudo apt-get -y install jq

echo "deb [trusted=yes] http://packages.o1test.net release main" | sudo tee /etc/apt/sources.list.d/mina.list
sudo apt-get -y update
sudo apt-get install -y curl unzip mina-testnet-postake-medium-curves=1.0.5-68200c7
sudo apt-get install -y mina-archive=1.0.5-68200c7

if $INSTALL_MINA_POOL_PAYOUT
then
    git clone https://github.com/jrwashburn/mina-pool-payout.git
fi

echo "start daemon interactive - control + c once running to stop"
echo "RUN: mina daemon --generate-genesis-proof true --peer-list-url https://storage.googleapis.com/seed-lists/devnet_seeds.txt"

echo "THEN: upload keys and update pass phrases in ~/.mina-env"
echo "set uid/pwd/host in ~/.mina-archive-env"
echo "DO NOT FORGET chmod 700 ~keys & chmod 600 ~/keys/*"
