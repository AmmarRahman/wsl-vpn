#!/usr/bin/env bash

set -eu

source common.env

# Arg Parse
while (( $# )); do
  case "${1}" in
    --no-docker)
      no_docker=1
      ;;
    --no-start)
      no_start=1
      ;;
    *)
      echo "Usage: $0 [--no-docker|--no-start]" >&2
      exit 2
      ;;
  esac
  shift 1
done

if [ ${EUID:-$(id -u)} -ne 0 ]; then
  echo "You need to run this as root"
  exit 1
fi

# Need WSL_DISTRO_NAME, because sudo usually removes this variable
if [ -z "${WSL_DISTRO_NAME:+set}" ]; then
  # eval "$(cat /proc/$(ppid $(ppid $$))/environ | tr "\0" "\n" | grep ^WSL_DISTRO_NAME=)"
  # Better way: https://github.com/microsoft/WSL/issues/4479#issuecomment-876698799
  WSL_DISTRO_NAME="$(IFS='\'; x=($(wslpath -w /)); echo "${x[${#x[@]}-1]}")"
fi

# Determine dependencies
dependencies=(socat)
deb_install=(socat)

for cmd in "${dependencies[@]}"; do
  if ! command -v "${cmd}" &> /dev/null; then
    if command -v apt &> /dev/null; then
      apt update
      apt install -y "${deb_install[@]}"
      break
    # elif command -v yast2 &> /dev/null; then
    #   ...
    else
      echo "Todo: program other package managers" &> /dev/null
      exit 3
    fi
  fi
done

# Install /usr/local/bin/wsl-vpnkit-start.sh
cp ./wsl-vpnkit-start.sh /usr/local/bin/
chmod +x /usr/local/bin/wsl-vpnkit-start.sh
chown root:root /usr/local/bin/wsl-vpnkit-start.sh

# Install /etc/init.d/wsl-vpnkit
# WSL_DISTRO_NAME is not set when "service wsl-vpnkit start" is run, so put the value in the script
sed "s|%%WSL_DISTRO_NAME%%|${WSL_DISTRO_NAME}|; s|%%SYSTEM_ROOT%%|${SYSTEM_ROOT}|" ./wsl-vpnkit.service > /etc/init.d/wsl-vpnkit
chmod +x /etc/init.d/wsl-vpnkit
chown root:root /etc/init.d/wsl-vpnkit

# Install /etc/sudoers.d/wsl-vpnkit
if [ -n "${SUDO_USER:+set}" ]; then
  touch /etc/sudoers.d/wsl-vpnkit
  write_to_file "${SUDO_USER} ALL=(ALL) NOPASSWD: /usr/sbin/service wsl-vpnkit *" /etc/sudoers.d/wsl-vpnkit
  chown root:root /etc/sudoers.d/wsl-vpnkit
fi

mkdir -p "${WIN_BIN}"
if [ "${no_docker}" = "0" ]; then
  # Install c:\bin\wsl-vpnkit.exe
  cp "${DOCKER_WSL}/vpnkit.exe" "${WIN_BIN}/wsl-vpnkit.exe"

  # Install /usr/local/sbin/vpnkit-tap-vsockd
  extract_from_iso_ps "${DOCKER_WSL}/wsl/docker-for-wsl.iso" containers/services/vpnkit-tap-vsockd/lower/sbin/vpnkit-tap-vsockd vpnkit-tap-vsockd
  mv vpnkit-tap-vsockd /usr/local/sbin/vpnkit-tap-vsockd
  chmod +x /usr/local/sbin/vpnkit-tap-vsockd
  chown root:root /usr/local/sbin/vpnkit-tap-vsockd

  # Install c:\bin\npiperelay.exe
  download_ps "${NPIPRELAY_URL}" npiperelay_windows_amd64.zip
  unzip_ps npiperelay_windows_amd64.zip npiperelay.exe
  rm npiperelay_windows_amd64.zip
  mv npiperelay.exe "${WIN_BIN}"
else
  download_ps "${WSLBIN_URL}" wslbin.tar.gz
  tar -xf wslbin.tar.gz .
  mv wsl-vpnkit.exe "${WIN_BIN}"
  mv npiperelay.exe "${WIN_BIN}"
  mv vpnkit-tap-vsockd /usr/local/sbin/
  chmod 755 /usr/local/sbin/vpnkit-tap-vsockd
  chown root:root /usr/local/sbin/vpnkit-tap-vsockd
  rm wslbin.tar.gz
fi

# /etc/profile.d/wsl-vpnkit.sh
echo "service wsl-vpnkit status > /dev/null || service wsl-vpnkit start" > /etc/profile.d/wsl-vpnkit.sh
chmod 644 /etc/profile.d/wsl-vpnkit.sh
chown root:root /etc/profile.d/wsl-vpnkit.sh
# Edit /etc/zsh/zprofile
write_to_file "service wsl-vpnkit status > /dev/null || service wsl-vpnkit start"  /etc/zsh/zprofile

echo "Setup complete!"

if [ "${no_start}" = "0" ]; then
  service wsl-vpnkit status > /dev/null || service wsl-vpnkit start
  echo "WSL VPNKit Service started. You may proceed to use the internet like normal"
fi
