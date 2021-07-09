#!/usr/bin/env bash

WIN_BIN="/mnt/c/bin"

SOCKET_PATH=/var/run/wsl-vpnkit.sock
PIPE_PATH="//./pipe/wsl-vpnkit"
VPNKIT_BACKLOG="32"
VPNKIT_PATH="${VPNKIT_PATH:-"${WIN_BIN}/wsl-vpnkit.exe"}"
VPNKIT_NPIPERELAY_PATH="${VPNKIT_NPIPERELAY_PATH:-"${WIN_BIN}/npiperelay.exe"}"
VPNKIT_GATEWAY_IP="192.168.67.1"
VPNKIT_HOST_IP="192.168.67.2"
VPNKIT_LOWEST_IP="192.168.67.3"
VPNKIT_HIGHEST_IP="192.168.67.14"
VPNKIT_DEBUG="${VPNKIT_DEBUG}"

WIN_PIPE_PATH="${PIPE_PATH//\//\\}"

TAP_NAME=eth1

IP_ROUTE=

relay()
{
  socat "UNIX-LISTEN:${SOCKET_PATH},fork,umask=007" "EXEC:${VPNKIT_NPIPERELAY_PATH} -ep -s ${PIPE_PATH},nofork"
}

vpnkit()
{
  "${WIN_BIN}/wsl-vpnkit.exe" \
      --ethernet "${WIN_PIPE_PATH}" \
      --listen-backlog "${VPNKIT_BACKLOG}" \
      --gateway-ip "${VPNKIT_GATEWAY_IP}" \
      --host-ip "${VPNKIT_HOST_IP}" \
      --lowest-ip "${VPNKIT_LOWEST_IP}" \
      --highest-ip "${VPNKIT_HIGHEST_IP}"
}

tap()
{
  vpnkit-tap-vsockd --tap "${TAP_NAME}" --path "${SOCKET_PATH}"
}

ipconfig()
{
  # Remove the default interface first
  IP_ROUTE="$(ip route | grep default)"
  ip route del ${IP_ROUTE} # No quotes, it needs to use the spaces
  ETHERNET_DEVICE="${IP_ROUTE##* }"
  local OLD_IFS="${IFS}"
  local IFS=$'\n'
  OTHER_ROUTES=($(ip route | grep "${ETHERNET_DEVICE}"))
  IFS="${OLD_IFS}"
  for route in ${OTHER_ROUTES[@]+"${OTHER_ROUTES[@]}"}; do
    ip route del ${route} # No quotes
  done
 
  # plumb what will probably be eth1
  ip a add "${VPNKIT_LOWEST_IP}/255.255.255.0" dev "${TAP_NAME}"
  ip link set dev "${TAP_NAME}" up

  # Set the new default route
  ip route add default via "${VPNKIT_GATEWAY_IP}" dev "${TAP_NAME}"
}

close()
{
  ip link set dev "${TAP_NAME}" down
  
  # for some reason, you get this problem https://serverfault.com/a/978311/321910
  # Adding onlink works, and will be remove when WSL restarts, so it seems harmless
  if [[ ${IP_ROUTE} =~ onlink ]]; then
    ip route add ${IP_ROUTE} # No quotes
  else 
    ip route add ${IP_ROUTE} onlink  # No quotes
  fi
  for route in ${OTHER_ROUTES[@]+"${OTHER_ROUTES[@]}"}; do
    ip route add ${route} # No quotes
  done
  kill 0
}

if [ "${EUID:-"$(id -u)"}" -ne 0 ]; then
  echo "Please run this script as root"
  exit 1
fi

# Connect the windows named pipe to  socket
relay &

# Wait for socket to be created
while [ ! -S "${SOCKET_PATH}" ]; do
  sleep 0.001
done

# Connect to the windows side of the socket
vpnkit &
# Connect to the linux side of the socket, and tap it as an ethernet device
tap &

# Wait for the ethernet device to be tapped
# if command -f lshw &> /dev/null; then
#   timeout 3 while : ; do
#     if lshw -C network | grep "${TAP_NAME}"; then
#       break
#     fi
#   done
#   echo "Device "${TAP_NAME}" is taking too long to tap" >&2
# else
#   sleep 3
# fi
while [ ! -e "/sys/class/net/${TAP_NAME}" ]; do
  sleep 0.0001
done

# create eth1 and patch routing table
ipconfig

# Make sure routing table is restored when finished, or else wsl.exe --terminate
# will be needed to restore the routing table
trap close exit
trap exit int term

# Just wait for the service to be killed
wait
