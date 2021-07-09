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

rm_if "${WIN_BIN}/npiperelay.exe" "${SYSTEM_ROOT}/system32/taskkill.exe" /im npiperelay.exe
rm_if "${WIN_BIN}/wsl-vpnkit.exe" "${SYSTEM_ROOT}/system32/taskkill.exe" /im wsl-vpnkit.exe
# Doesn't remove it if it's not empty
rmdir_if "${WIN_BIN}" || :

rm_if /etc/profile.d/wsl-vpnkit.sh
sed_file '/service wsl-vpnkit start/d' /etc/zsh/zprofile

# Left here for backwards compatibility reasons, we no longer edit /etc/wsl.conf
# nor generate a /etc/.wsl.conf.orig
if [ -e /etc/.wsl.conf.orig ]; then
  if ! grep -q '^generateResolvConf = false' /etc/.wsl.conf.orig; then
    sed_file '/^generateResolvConf = false.*/d' /etc/wsl.conf
    # On the next restart of wsl, the symlink will be recreated
    rm /etc/resolv.conf
  fi
  rm /etc/.wsl.conf.orig

  echo "You'll need to restart this wsl image for changes to take affect"
  echo "Run: /c/Windows/System32/wsl.exe -t {WSL_NAME}"
fi

echo "VPNKit for WSL has been Removed!"
