chmod 700 ~/keys
chmod 600 ~/keys/*
systemctl --user daemon-reload
systemctl --user start mina.service
systemctl --user enable mina.service
systemctl --user status
sudo loginctl enable-linger
