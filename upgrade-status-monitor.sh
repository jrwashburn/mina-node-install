#!/bin/bash -x

YOUR_SW_FEE=0.000999999
YOUR_SW_ADDRESS=B62qkBqSkXgkirtU3n8HJ9YgwHh3vUD6kGJ5ZRkQYGNPeL5xYL2tL1L

sed -i "s/YOUR_SW_FEE/$YOUR_SW_FEE/g" scripts/mina-status-monitor.sh
sed -i "s/YOUR_SW_ADDRESS/$YOUR_SW_ADDRESS/g" scripts/mina-status-monitor.sh

sudo cp scripts/mina-status-monitor.sh /usr/local/bin/mina-status-monitor.sh
systemctl --user stop mina-status-monitor.service
sleep 5s
systemctl --user start mina-status-monitor.service