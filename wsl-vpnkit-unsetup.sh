#!/usr/bin/env bash

set -eu

source common.env

if [ ${EUID:-$(id -u)} -ne 0 ]; then
  echo "You need to run this as root"
  exit 1
fi

service wsl-vpnkit stop || :

rm_if /usr/local/bin/wsl-vpnkit-start.sh
rm_if /etc/init.d/wsl-vpnkit
rm_if /etc/sudoers.d/wsl-vpnkit
rm_if /usr/local/sbin/vpnkit-tap-vsockd

rm_if /mnt/c/bin/npiperelay.exe "${SYSTEM_ROOT}/system32/taskkill.exe" /im npiperelay.exe
rm_if /mnt/c/bin/wsl-vpnkit.exe "${SYSTEM_ROOT}/system32/taskkill.exe" /im wsl-vpnkit.exe
rmdir /mnt/c/bin || :

rm_if /etc/profile.d/wsl-vpnkit.sh
sed_file '/service wsl-vpnkit start/d' /etc/zsh/zprofile

echo "Removed!"
