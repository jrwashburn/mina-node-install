# mina-node-install
PLEASE BE CAREFUL. These scripts make some assumptions about access to the system - i.e. we don't use root, and assume this is a new install. These scripts will remove root's ability to login or ssh. If your environment is different, you will likely need to make modifications.  

This repo is a collection of scripts and configurations for a base debian 9 install. It automates most setup tasks; it leaves several manual steps to ensure passwords and keys are exclusively managed by the admin.

There are two main install scripts 
- install-os, which prepares the base system, and 
- install-mina, which sets up mina for the first time.

## install-os script
This script prepares the basics on a new node:  
- creates user [minar]
- grants sudo  
- changes ssh port and restricts to new users
- disables root login  
- installs ufw and blocks all inbound except ssh (**moved to 1932**), 8302 for p2p  
- installs prometheus and node_exporter, sets up systemd unit for each  

These parameters are at the top of the install os script and should be set for your env:  
```console
INSTALL_UFW=true  
INSTALL_PROMETHEUS=true  
YOUR_GRAFANA_REMOTE_WRITE_ENDPOINT="https://prometheus-us-central1.grafana.net/api/prom/push"  
YOUR_GRAFANA_METRICS_INSTANCE_ID=**********
YOUR_GRAFANA_API_KEY=**********
YOUR_MINA_NODE_IDENTIFIER=mina01
```

## install-mina script
This script will install mina and setup systemd units for mina, mina-archive, mina-status-monitor, and mina-staking-ledgers-archive. It also sets up environment files for mina and mina-archive. It does not set the key password or database logins -- that is intentionally left to be handled manually.
- mina.service unit to override standard install parameters. Mina installs a systemd config at /usr/lib/systemd/user/mina.service which is updated with each install. To supply your own overrides, this places a mina.service in /etc/systemd/user with parameters from this script.
- mina-archive.service unit to run the mina-archive service on the same node. This requires a postgres database that has been setup as per https://minaprotocol.com/docs/advanced/archive-node and is accessible from the node.
- mina-status-monitor.service unit checks mina client status ever 5 minutes for health check. This unit runs the mina-status-monitor.sh script which incorporates a snark starter / stopper (**this should be modified if you are running as a coordinator**). This script will also **restart your mina daemon** if it detects that the node is "stuck" more than 10 blocks behind the highest tip it has seen, if it gets stays in status connecting for more than 10 minutes, or is offline for more than 15 minutes (should never occur.) In the future, this c/should be updated to generate alerts.
- mina-staking-ledgers-archive.service unit dumps current and next staking ledger daily for mina-pool-payout. This runs a mina-export-ledgers.sh script, which dumps the current and next staking ledger, calculates their hash, and renames them by their hash. https://github.com/jrwashburn/mina-pool-payout will be able to use those files for the payout calculation. 

These parameters are at the top of the install mina script and should be overwritten as well:
```console
YOUR_SW_FEE=0.25  
YOUR_SW_ADDRESS=B62qkBqSkXgkirtU3n8HJ9YgwHh3vUD6kGJ5ZRkQYGNPeL5xYL2tL1L  
YOUR_LEDGER_ARCHIVE_DIRECTORY=/home/minar/ledger-archives  
THE_SEEDS_URL=https://storage.googleapis.com/seed-lists/devnet_seeds.txt  
YOUR_WALLET_FILE=~/keys/my-wallet  
YOUR_COINBASE_RECEIVER=B62qoigHEtJCoZ5ekbGHWyr9hYfc6fkZ2A41h9vvVZuvty9amzEz3yB  
```

# Setting up a brand new node
on a shiny new debian node, ssh'd in as root:  

```console
apt-get update  
apt-get install -y git
git clone https://github.com/jrwashburn/mina-node-install
#update your params at the top of the install scripts
nano mina-node-install/install-os.sh 
nano mina-node-install/install-mina.sh 
```

Running the install-os script will create a new user named minar (you'll be prompted for password, name, etc.) which will be the use you'll use on the node. (If you don't like minar, you can replace minar with whatever you like in the scripts.) It will also turn on ufw firewall and lock down inbound, change the sshd port, and disable root ssh and login -- so be careful that you know it worked, and know you can reconnect as minar, before you end this first session as root!

```console
mina-node-install/install-os.sh
```
*check that you can ssh in with minar user on new node before disconnecting!*  
*install-os will disable ssh and login for root*  

ssh in as minar

```console
cd mina-node-install
./install-mina.sh
mina daemon --generate-genesis-proof true --peer-list-url https://storage.googleapis.com/seed-lists/devnet_seeds.txt 
```

CTRL+C to stop it once confirmed running okay  

sftp or scp upload your keys and chmod  
```console
#e.g. from your local terminal 
scp -P 1932 -i ~/.ssh/MYSSHKEY ~/MYKEYLOCATION/my-wallet* minar@MYCLOUDSERVER:/home/minar/keys/ 
```

```console
#update your private key password, confirm params  
nano ~/.mina-env  
#update your postgres connection string  
nano ~/.mina-archive-env  
#then start all the systemd units with start-node.sh
./start-node.sh
```

Confirm everything okay, then cleanup  

```console
cd ~
rm -rf mina-node-install
```

## packages installed
- mina
- mina-archive
- prometheus  
- node_exporter  
- ufw  
- apt-transport-https
- curl
- jq  
- bc  

# repo structure
## partial-configs
location for config files to be udpated with parameters and moved to proper config file locations  

## scripts 
location for scripts to be updated with node-specific parameters then moved to usr/local/bin  

## systemd-units
systemd unit files and timers
