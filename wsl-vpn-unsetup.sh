#!/usr/bin/env bash

set -eu

if [ ${EUID:-$(id -u)} -ne 0 ]; then
    echo "You need to run this as sudo"
    exit 1
fi

function sed_file() {
    if [ -e "${2}" ]; then
        sed -i "${1}" "${2}"
    fi
}

function rm_if() {
    if [ -e "${1}" ]; then
        rm "${1}"
    fi
}

service wsl-vpnkit stop || :

rm_if /usr/bin/wsl_vpn_start.sh
rm_if /etc/init.d/wsl-vpnkit
rm_if /etc/sudoers.d/wsl-vpnkit
rm_if /sbin/vpnkit-tap-vsockd

rm_if /mnt/c/bin/npiperelay.exe
rm_if /mnt/c/bin/wsl-vpnkit.exe
rmdir /mnt/c/bin || :

sed_file '/^sudo service wsl-vpnkit start$/d' /etc/profile
sed_file '/^sudo service wsl-vpnkit start$/d' /etc/zsh/zprofile

if [ -e /etc/.wsl.conf.orig ]; then
    if ! grep -q '^generateResolvConf = false' /etc/.wsl.conf.orig; then
       sed -i '/^generateResolvConf = false.*/d' /etc/wsl.conf
    fi
    rm /etc/.wsl.conf.orig
fi


echo "Removed!"
