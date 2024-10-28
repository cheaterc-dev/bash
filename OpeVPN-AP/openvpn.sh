#!/bin/bash
LOGIN_VPN=""
PASSWORD_VPN=""
WIFI_AP=$(iw dev | awk '/Interface/{print $2}')
VPN_CFG="al-tia.prod.surfshark.comsurfshark_openvpn_udp.ovpn"         
WIFI_PASSWD="Password1234"
WIFI_SSID="Mywifi"
IP_ADD_AP="192.168.1.3"
DHCP_RANGE="192.168.1.2,192.168.1.100,255.255.255.0,24h"
DNS_1="8.8.8.8"
DNS_2="8.8.4.4"
YAML_FILE="/etc/netplan/50-cloud-init.yaml"



apt-get install git linux-headers-generic build-essential dkms
apt install hostapd
apt install dnsmasq
apt install iw
apt install openvpn unzip 
apt-get install iptables-persistent
#############################Install OpenVPN##############################################
if [ -f $VPN_CFG ]; then
    cp $VPN_CFG /etc/openvpn/
else
    echo "VPN configuration file not found: $VPN_CFG"
    exit 1
fi

touch /etc/openvpn/auth.txt
echo -e "$LOGIN_VPN\n$PASSWORD_VPN" | sudo tee /etc/openvpn/auth.txt

sed -i.bak 's/^auth-user-pass/auth-user-pass \/etc\/openvpn\/auth.txt/' /etc/openvpn/$VPN_CFG

chmod 600 /etc/openvpn/auth.txt



cat <<EOL > /etc/systemd/system/openvpn-surfshark.service
[Unit]
Description=OpenVPN connection to Surfshark
After=network.target

[Service]
ExecStart=/usr/sbin/openvpn --config /etc/openvpn/$VPN_CFG
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOL

systemctl daemon-reload
systemctl enable openvpn-surfshark.service
systemctl start openvpn-surfshark.service

echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
sysctl -p



#############################Install Driver##############################################
git clone https://github.com/Mange/rtl8192eu-linux-driver
cd rtl8192eu-linux-driver
dkms add .
dkms install rtl8192eu/1.0
echo "blacklist rtl8xxxu" | sudo tee /etc/modprobe.d/rtl8xxxu.conf
echo -e "8192eu\n\nloop" | sudo tee /etc/modules
echo "options 8192eu rtw_power_mgnt=0 rtw_enusbss=0" | sudo tee /etc/modprobe.d/8192eu.conf
update-grub; sudo update-initramfs -u

#############################Install Hostpad##############################################
systemctl unmask hostapd.service
cat <<EOL > /etc/hostapd/hostapd.conf
interface=$WIFI_AP
driver=nl80211
ssid=$WIFI_SSID
hw_mode=g
channel=6
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=$WIFI_PASSWD
rsn_pairwise=CCMP
ht_capab=[HT40+][RX-STBC1][SHORT-GI-40][SHORT-GI-20][DSSS_CCK-40][MAX-AMSDU-7935]
EOL

systemctl restart hostapd.service
systemctl enable hostapd.service
#############################Install dnsmasq##############################################
cat <<EOL > /etc/dnsmasq.conf
interface=$WIFI_AP
dhcp-range=$DHCP_RANGE
server=$DNS_1
server=$DNS_2
domain-needed
bogus-priv
EOL

systemctl stop systemd-resolved
systemctl disable systemd-resolved

systemctl restart dnsmasq
systemctl enable dnsmasq


ip addr add $IP_ADD_AP/24 dev $WIFI_AP

iptables -t nat -A POSTROUTING -o tun0 -j MASQUERADE

netfilter-persistent save







