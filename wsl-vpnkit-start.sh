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
RESOLV_CONF=

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
  ip a add "${VPNKIT_LOWEST_IP}/255.255.255.0" dev "${TAP_NAME}"
  ip link set dev "${TAP_NAME}" up
  IP_ROUTE=$(ip route | grep default)
  ip route del "${IP_ROUTE}"
  ip route add default via "${VPNKIT_GATEWAY_IP}" dev "${TAP_NAME}"
  RESOLV_CONF=$(cat /etc/resolv.conf)
  echo "nameserver ${VPNKIT_GATEWAY_IP}" > /etc/resolv.conf
}

close()
{
  ip link set dev "${TAP_NAME}" down
  ip route add "${IP_ROUTE}"
  echo "${RESOLV_CONF}" > /etc/resolv.conf
  kill 0
}

if [ "${EUID:-"$(id -u)"}" -ne 0 ]; then
  echo "Please run this script as root"
  exit 1
fi

relay &
sleep 3
vpnkit &
sleep 3
tap &
sleep 3
ipconfig
trap close exit
trap exit int term
wait