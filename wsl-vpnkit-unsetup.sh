#!/usr/bin/env bash

set -eu

source common.env

if [ ${EUID:-$(id -u)} -ne 0 ]; then
  echo "You need to run this as sudo"
  exit 1
fi

service wsl-vpnkit stop || :

rm_if /usr/local/bin/wsl-vpnkit-start.sh
rm_if /etc/init.d/wsl-vpnkit
rm_if /etc/sudoers.d/wsl-vpnkit
rm_if /usr/local/sbin/vpnkit-tap-vsockd

rm_if /mnt/c/bin/npiperelay.exe
rm_if /mnt/c/bin/wsl-vpnkit.exe
rmdir /mnt/c/bin || :

# sed_file '/service wsl-vpnkit start/d' /etc/profile
rm_if /etc/profile.d/wsl-vpnkit.sh
sed_file '/service wsl-vpnkit start/d' /etc/zsh/zprofile

if [ -e /etc/.wsl.conf.orig ]; then
  if ! grep -q '^generateResolvConf = false' /etc/.wsl.conf.orig; then
    sed -i '/^generateResolvConf = false.*/d' /etc/wsl.conf
    # On the next restart of wsl, the symlink will be recreated
    rm /etc/resolv.conf
  fi
  rm /etc/.wsl.conf.orig
fi

echo "Removed!"
