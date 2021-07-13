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
    --on-vpn)
      on_vpn=1
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

if ! command -v socat &> /dev/null; then
  if [ "${on_vpn}" = "0" ]; then
    if command -v apt &> /dev/null; then
      apt update
      apt install -y socat
    elif command -v zypper &> /dev/null; then
      zypper install -y socat
    elif command -v dnf &> /dev/null; then
      dnf install -y socat
    elif command -v yum &> /dev/null; then
      yum install -y socat
    elif command -v apk &> /dev/null; then
      apk add --no-cache socat
    else
      echo "There is no automates solution to install \"socat\" on OS" >&2
      read -pr "Please enter a command to install \"socat\": " cmd
      eval "${cmd}"
      if ! command -v socat; then
        echo "socat does not appear to be installed. Please get socat installed and try again"
        exit 3
      fi
    fi
  else
    # This appears to work in alpine (musl) and ubuntu/fedora alike (glibc)
    download_ps https://github.com/andrew-d/static-binaries/raw/8ae38c79510d072cdba0bf719ef4f16c052e2abc/binaries/linux/x86_64/socat /usr/local/bin/socat
    chmod 755 /usr/local/bin/socat
  fi
fi

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
