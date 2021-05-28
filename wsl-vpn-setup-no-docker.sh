#!/bin/bash

if [ ${EUID:-$(id -u)} -ne 0 ]; then
    echo "You need to run this as sudo"
    exit 1
fi

# This function check if the file exist then only append the line once

function write_to_file() {
    if [ -e "$2" ]; then
        grep -qFs "$1" "$2" || echo "$1" | tee -a "$2"
    fi 
}

#putting this in a public repository to avoid using Oauth keys. We need a more elegant solution.
WSL_BIN=https://github.com/AmmarRahman/wsl-vpn/releases/latest/download/wslbin.tar.gz
WIN_BIN=/mnt/c/bin

apt install -y socat

wget $WSL_BIN -t -O wslbin.tar.gz
tar -xf wslbin.tar.gz .
mkdir -p $WIN_BIN
mv wsl-vpnkit.exe $WIN_BIN
mv npiperelay.exe $WIN_BIN
mv vpnkit-tap-vsockd /sbin
chown root:root /sbin/vpnkit-tap-vsockd
rm wslbin.tar.gz 
cp ./wsl/wsl_vpn_start.sh /usr/bin
chmod +x /usr/bin/wsl_vpn_start.sh
cp ./wsl/wsl-vpnkit.service /etc/init.d/wsl-vpnkit
chmod +x /etc/init.d/wsl-vpnkit

# Dangerous stuff
touch /etc/sudoers.d/wsl-vpnkit
write_to_file "${SUDO_USER} ALL=(ALL) NOPASSWD: /usr/sbin/service wsl-vpnkit *" /etc/sudoers.d/wsl-vpnkit



write_to_file "service wsl-vpnkit start"  /etc/profile
write_to_file "service wsl-vpnkit start"  /etc/zsh/zprofile


