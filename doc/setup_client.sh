#!/bin/sh

if [ $(id -u) != 0 ]; then
	echo 'script must be run as root'
	exit 1
fi

INTER="$1"
BINARY="$(realpath $2)"

ip link set "$INTER" up
ip addr add 192.168.1.100/24 dev "$INTER"
BOOTDIR=$(mktemp -d)
cp "$BINARY" "$BOOTDIR"/boot.bin
cd "$BOOTDIR"

dnsmasq -d --port=0 --enable-tftp --tftp-root="$BOOTDIR" --user=root --group=root --interface="$INTER"
