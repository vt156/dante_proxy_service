#!/bin/bash

username=${1:-"turbofoo62"}
password=${2:-"foxglue55"}
port=${3:-1071}
# directory for temporary files needed for installation
tmp_dir=${4:-"/tmp"}

apt -y update
apt -y install dante-server
apt -y install expect

# create dante config file
echo "
logoutput: syslog /var/log/danted.log
internal: eth0 port = $port
external: eth0

socksmethod: username
user.privileged: root
user.unprivileged: nobody

client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: error
}

socks pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    command: connect
    log: error
    method: username
}" > /home/danted.conf

# create a script to spawn with expect
useradd -m $username
echo "passwd $username" > $tmp_dir/password.sh
chmod a+x $tmp_dir/password.sh

# set password with expect
/usr/bin/expect <<EOF
spawn "$tmp_dir/password.sh"
sleep 1
expect "Enter new UNIX password:"
send "$password"
send "\n"
sleep 1
expect "Retype new UNIX password:"
send "$password"
send "\n"
sleep 1
send "\n"
expect eof
exit
EOF

rm $tmp_dir/password.sh

# execute this later with systemctl
echo "danted -f /home/danted.conf" > /home/start_dante.sh

# create a systemctl service file
echo "
[Unit]
Description=My Dante Proxy
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/home
ExecStart=/bin/bash start_dante.sh
Restart=on-failure

[Install]
WantedBy=multi-user.target
" > /etc/systemd/system/dante_proxy.service

systemctl daemon-reload
systemctl start dante_proxy
systemctl status -n 0 dante_proxy
systemctl enable dante_proxy
