chmod 700 ~/keys 
chmod 600 ~/keys/*
systemctl --user daemon-reload
systemctl --user start mina-archive.service
systemctl --user start mina.service
systemctl --user start mina-staking-ledgers-archive.service
systemctl --user start mina-staking-ledgers-archive.timer
systemctl --user start mina-status-monitor.service  
systemctl --user enable mina-archive.service
systemctl --user enable mina.service
systemctl --user enable mina-staking-ledgers-archive.timer
systemctl --user enable mina-status-monitor.service
systemctl --user start node_exporter.service
systemctl --user start prometheus.service
systemctl --user enable node_exporter.service
systemctl --user enable prometheus.service

systemctl --user status
