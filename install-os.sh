#!/bin/bash -x
INSTALL_UFW=true
INSTALL_PROMETHEUS=true
INSTALL_NODEJS=true
INSTALL_GCLOUD=true
YOUR_GRAFANA_REMOTE_WRITE_ENDPOINT="https://prometheus-us-central1.grafana.net/api/prom/push"
YOUR_GRAFANA_METRICS_INSTANCE_ID=**********
YOUR_GRAFANA_API_KEY=**********
#provide a unique identifier for each prometheus instance sending data to grafana
YOUR_MINA_NODE_IDENTIFIER=mina01

cd mina-node-install
cp partial-configs/sshd_config /etc/ssh/sshd_config

adduser minar
usermod -aG sudo minar
usermod -aG systemd-journal minar
mkdir -p /home/minar/.ssh
chown minar:minar /home/minar/.ssh
sudo cp /root/.ssh/authorized_keys /home/minar/.ssh/authorized_keys
sudo chown minar:minar /home/minar/.ssh/authorized_keys
sudo chmod 600 /home/minar/.ssh/authorized_keys
sudo systemctl restart sshd

sudo apt -y update
sudo apt -y full-upgrade
sudo apt-get install -y apt-transport-https ca-certificates gnupg
sudo apt-get install -y curl

if $INSTALL_GCLOUD
then
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -
    sudo apt-get -y update && sudo apt-get install -y  google-cloud-sdk
    #you will have to login to google and get a token
    gcloud init
fi

if $INSTALL_UFW
then
    sudo apt-get -y install ufw
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw allow 1932/tcp
    sudo ufw allow 8302/tcp
    sudo ufw disable
    sudo ufw enable
    sudo ufw status
fi

if $INSTALL_PROMETHEUS
then
    CURRENT_NODE_EXPORTER=$(curl -s https://api.github.com/repos/prometheus/node_exporter/releases/latest | grep browser_download_url | grep linux-amd64 | cut -d '"' -f 4)
    wget $(echo $CURRENT_NODE_EXPORTER)
    tar xvfz $(echo $CURRENT_NODE_EXPORTER | cut -d '/' -f 9)
    rm $(echo $CURRENT_NODE_EXPORTER | cut -d '/' -f 9)

    CURRENT_PROMETHEUS=$(curl -s https://api.github.com/repos/prometheus/prometheus/releases/latest | grep browser_download_url | grep linux-amd64 | cut -d '"' -f 4)
    wget $(echo $CURRENT_PROMETHEUS)
    tar xvfz $(echo $CURRENT_PROMETHEUS | cut -d '/' -f 9)
    rm $(echo $CURRENT_PROMETHEUS | cut -d '/' -f 9)

    sed -i "s^YOUR_GRAFANA_REMOTE_WRITE_ENDPOINT^$YOUR_GRAFANA_REMOTE_WRITE_ENDPOINT^g" partial-configs/prometheus.yml
    sed -i "s^YOUR_GRAFANA_METRICS_INSTANCE_ID^$YOUR_GRAFANA_METRICS_INSTANCE_ID^g" partial-configs/prometheus.yml
    sed -i "s^YOUR_GRAFANA_API_KEY^$YOUR_GRAFANA_API_KEY^g" partial-configs/prometheus.yml
    sed -i "s^YOUR_MINA_NODE_IDENTIFIER^$YOUR_MINA_NODE_IDENTIFIER^g" partial-configs/prometheus.yml

    mkdir -p /etc/prometheus
    cp partial-configs/prometheus.yml /etc/prometheus/prometheus.yml
    cp $(echo $CURRENT_NODE_EXPORTER | cut -d '/' -f 9 | sed 's^.tar.gz^^')/node_exporter /usr/local/bin
    cp $(echo $CURRENT_PROMETHEUS | cut -d '/' -f 9 | sed 's^.tar.gz^^')/prometheus /usr/local/bin
    cp -r $(echo $CURRENT_PROMETHEUS | cut -d '/' -f 9 | sed 's^.tar.gz^^')/consoles /etc/prometheus
    cp -r $(echo $CURRENT_PROMETHEUS | cut -d '/' -f 9 | sed 's^.tar.gz^^')/console_libraries /etc/prometheus

    cp systemd-units/prometheus.service /etc/systemd/user/
    cp systemd-units/node_exporter.service /etc/systemd/user/
fi

if $INSTALL_NODEJS
then
    #install node & npm - see https://github.com/nodesource/distributions#deb
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource.gpg.key | sudo apt-key add -
    VERSION=node_15.x
    DISTRO="$(lsb_release -s -c)"
    echo "deb https://deb.nodesource.com/$VERSION $DISTRO main" | sudo tee /etc/apt/sources.list.d/nodesource.list
    echo "deb-src https://deb.nodesource.com/$VERSION $DISTRO main" | sudo tee -a /etc/apt/sources.list.d/nodesource.list
    sudo apt-get update
    sudo apt-get install -y nodejs
fi

cd ..
mv mina-node-install /home/minar/mina-node-install
chown -R minar:minar /home/minar/mina-node-install

echo "MAKE SURE YOU CAN SSH as minar on port 1932 BEFORE DISCONNECTING!"
echo "MAKE SURE YOU CAN SSH as minar on port 1932 BEFORE DISCONNECTING!"
echo "MAKE SURE YOU CAN SSH as minar on port 1932 BEFORE DISCONNECTING!"
