#!/usr/bin/env bash

set -eu

if [ ${EUID:-$(id -u)} -ne 0 ] || [ -z "${SUDO_USER-}" ]; then
    echo "You need to run this as sudo"
    exit 1
fi

# This function check if the file exist then only append the line once
function write_to_file() {
    if [ -e "$2" ]; then
        grep -qFs "$1" "$2" || echo "$1" | tee -a "$2"
    fi
}

# Get the parent pid, in a way that should work on any WSL distro
function ppid() {
    sed -n "s|PPid:\s*||p" /proc/$1/status
}

DOCKER_WSL="/mnt/c/Program Files/Docker/Docker/resources"

for cmd in socat unzip isoinfo wget p7zip; do
    if ! command -v "${cmd}" &> /dev/null; then
        # Warning: Specific to debian/ubuntu
        apt update
        apt install -y socat unzip p7zip genisoimage wget
        break
    fi
done

cp ./wsl_vpn_start.sh /usr/bin/
chmod +x /usr/bin/wsl_vpn_start.sh
chown root:root /usr/bin/wsl_vpn_start.sh

# Need WSL_DISTRO_NAME, because _this_ wsl might not be the default
eval "$(cat /proc/$(ppid $(ppid $$))/environ | tr "\0" "\n" | grep ^WSL_DISTRO_NAME=)"
# WSL_DISTRO_NAME is not set when "service wsl-vpnkit start" is run, so put the value in the script
sed 's|%%WSL_DISTRO_NAME%%|'"${WSL_DISTRO_NAME}"'|' ./wsl-vpnkit.service > /etc/init.d/wsl-vpnkit
chmod +x /etc/init.d/wsl-vpnkit
chown root:root /etc/init.d/wsl-vpnkit

# Dangerous stuff
touch /etc/sudoers.d/wsl-vpnkit
write_to_file "${SUDO_USER} ALL=(ALL) NOPASSWD: /usr/sbin/service wsl-vpnkit *" /etc/sudoers.d/wsl-vpnkit
chown root:root /etc/sudoers.d/wsl-vpnkit

cd ~
mkdir -p /mnt/c/bin
cp "${DOCKER_WSL}/vpnkit.exe" /mnt/c/bin/wsl-vpnkit.exe

isoinfo -i "${DOCKER_WSL}/wsl/docker-for-wsl.iso" -R -x /containers/services/vpnkit-tap-vsockd/lower/sbin/vpnkit-tap-vsockd > ./vpnkit-tap-vsockd
mv vpnkit-tap-vsockd /sbin/vpnkit-tap-vsockd
chmod +x /sbin/vpnkit-tap-vsockd
chown root:root /sbin/vpnkit-tap-vsockd

wget https://github.com/jstarks/npiperelay/releases/download/v0.1.0/npiperelay_windows_amd64.zip
unzip npiperelay_windows_amd64.zip npiperelay.exe
rm npiperelay_windows_amd64.zip
mv npiperelay.exe /mnt/c/bin/

write_to_file "sudo service wsl-vpnkit start"  /etc/profile
write_to_file "sudo service wsl-vpnkit start"  /etc/zsh/zprofile

if [ -e "/etc/wsl.conf" ]; then
    cp /etc/wsl.conf /etc/.wsl.conf.orig
else
    touch /etc/.wsl.conf.orig
fi

if ! grep "^generateResolvConf = false" /etc/wsl.conf &> /dev/null; then
    if ! grep "^\[network\]" /etc/wsl.conf &> /dev/null; then
      # append to end of the file, always makes it its own line
      sed -i '$a[network]' /etc/wsl.conf
    fi
    sed -i 's|^\[network\].*|&\ngenerateResolvConf = false|' /etc/wsl.conf
fi

echo "Setup"
