#!/bin/sh
#
# Brings up Access Point "TheRoom"
# Compatible with Raspberry Pi 4b
#

set -xe

apt update -y
apt install -y hostapd dnsmasq

systemctl unmask dnsmasq
systemctl stop dnsmasq

systemctl unmask hostapd
systemctl stop hostapd

# avoid interference for systemd service
update-rc.d hostapd remove

cat << EOF > /etc/udev/rules.d/90-ap-net.rules
SUBSYSTEM=="ieee80211", ACTION=="add|change", KERNEL=="phy0", \
RUN+="/sbin/iw phy phy0 interface add ap0 type __ap", \
RUN+="/bin/ip link set ap0 address $(echo $(cat /sys/class/net/wlan0/address) | rev)"
EOF

cat << EOF > /etc/network/interfaces
# interfaces(5) file used by ifup(8) and ifdown(8)
# Include files from /etc/network/interfaces.d:
source /etc/network/interfaces.d/*
EOF

mkdir -p /etc/network/interfaces.d/
cat << EOF > /etc/network/interfaces.d/ap0
auto ap0
iface ap0 inet static
    address 10.0.0.1
    netmask 255.0.0.0
EOF

cat << EOF > /etc/hostapd/hostapd.conf
interface=ap0
driver=nl80211
ssid=TheRoom
hw_mode=g
channel=11
wmm_enabled=0
auth_algs=1
macaddr_acl=0
ignore_broadcast_ssid=0
country_code=US
ieee80211n=1
ieee80211d=1
EOF

cat << EOF > /etc/dnsmasq.conf
interface=ap0
no-dhcp-interface=wlan0
bind-interfaces
server=8.8.8.8
domain-needed
bogus-priv
dhcp-range=10.0.0.2,10.255.255.255,24h
EOF

udevadm control --reload
udevadm trigger --subsystem-match=ieee80211 --action=change

echo 'nohook wpa_supplicant' >> /etc/dhcpcd.conf

ln -fsr /etc/wpa_supplicant/wpa_supplicant.conf /etc/wpa_supplicant/wpa_supplicant-nl80211-wlan0.conf
systemctl start wpa_supplicant-nl80211@wlan0
systemctl enable wpa_supplicant-nl80211@wlan0

systemctl stop wpa_supplicant
systemctl disable wpa_supplicant

systemctl restart networking

systemctl enable hostapd
systemctl start hostapd

systemctl enable dnsmasq
systemctl start dnsmasq
