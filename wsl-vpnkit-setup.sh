#!/usr/bin/env bash

set -eu

source common.env

# Arg Parse
no_docker=0
additional_wsl=0
while (( $# )); do
  case "${1}" in
    --no-docker)
      no_docker=1
      ;;
    --additional-wsl)
      additional_wsl=1
      ;;
    *)
      echo "Usage: $0 [--no-docker|--additional-wsl]" >&2
      exit 2
      ;;
  esac
  shift 1
done

if [ ${EUID:-$(id -u)} -ne 0 ]; then
  echo "You need to run this as root"
  exit 1
fi

# Need WSL_DISTRO_NAME, because _this_ wsl might not be the default
if [ -z "${WSL_DISTRO_NAME:+set}" ]; then
  eval "$(cat /proc/$(ppid $(ppid $$))/environ | tr "\0" "\n" | grep ^WSL_DISTRO_NAME=)"
fi

if [ "${additional_wsl}" = "0" ]; then
  # Determine dependencies
  dependencies=(socat)
  deb_install=(socat)
  if [ "${no_docker}" = "0" ]; then
    dependencies+=(unzip isoinfo)
    deb_install=(unzip genisoimage)
  fi

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
    isoinfo -i "${DOCKER_WSL}/wsl/docker-for-wsl.iso" -R -x /containers/services/vpnkit-tap-vsockd/lower/sbin/vpnkit-tap-vsockd > ./vpnkit-tap-vsockd
    mv vpnkit-tap-vsockd /usr/local/sbin/vpnkit-tap-vsockd
    chmod +x /usr/local/sbin/vpnkit-tap-vsockd
    chown root:root /usr/local/sbin/vpnkit-tap-vsockd

    # Install c:\bin\npiperelay.exe
    # This doesn't require WSL internet to be working. Apparently calling powershell
    # this way writes directly to this same directory
    # /mnt/c/WINDOWS/system32/WindowsPowerShell/v1.0/powershell.exe -NoProfile -Command "Invoke-WebRequest -Uri https://github.com/jstarks/npiperelay/releases/download/v0.1.0/npiperelay_windows_amd64.zip -OutFile npiperelay_windows_amd64.zip"
    download "${NPIPRELAY_URL}" npiperelay_windows_amd64.zip
    unzip npiperelay_windows_amd64.zip npiperelay.exe
    rm npiperelay_windows_amd64.zip
    mv npiperelay.exe "${WIN_BIN}"
  else
    download "${WSLBIN_URL}" wslbin.tar.gz
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
fi

# /etc/wsl.conf
if [ -e "/etc/wsl.conf" ]; then
  cp /etc/wsl.conf /etc/.wsl.conf.orig
else
  touch /etc/.wsl.conf.orig
fi


# echo "Starting service..."
# service wsl-vpnkit status > /dev/null || service wsl-vpnkit start
echo "Setup complete!"

echo "WSL ${WSL_DISTRO_NAME} must be restarted inorder for some of the changes to take affect"
read -sn1 -p "Press any key to terminal ${WSL_DISTRO_NAME}"

"${SYSTEM_ROOT}/system32/wsl.exe" -t "${WSL_DISTRO_NAME}"
