#!/bin/bash

# Загружаем переменные из файла .env
if [ -f .env ]; then
    source .env
else
    echo "Файл .env не найден. Пожалуйста, создайте его с необходимыми переменными."
    exit 1
fi

# Проверка обязательных переменных
REQUIRED_VARS=(LOGIN_VPN PASSWORD_VPN WIFI_PASSWD WIFI_SSID IP_ADD_AP DHCP_RANGE DNS_1 DNS_2 VPN_CFG)
for VAR in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!VAR}" ]; then
        echo "Переменная $VAR не установлена. Проверьте файл .env."
        exit 1
    fi
done

# Установка необходимых пакетов
apt-get update
PACKAGES=(git linux-headers-generic build-essential dkms hostapd dnsmasq iw openvpn unzip iptables-persistent)
for PACKAGE in "${PACKAGES[@]}"; do
    apt-get install -y "$PACKAGE" || { echo "Не удалось установить $PACKAGE"; exit 1; }
done

# Настройка OpenVPN
if [ -f "$VPN_CFG" ]; then
    cp "$VPN_CFG" /etc/openvpn/
else
    echo "VPN-конфигурационный файл не найден: $VPN_CFG"
    exit 1
fi

echo -e "$LOGIN_VPN\n$PASSWORD_VPN" > /etc/openvpn/auth.txt
chmod 600 /etc/openvpn/auth.txt

sed -i.bak 's/^auth-user-pass/auth-user-pass \/etc\/openvpn\/auth.txt/' "/etc/openvpn/$VPN_CFG"

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

echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p

# Настройка драйвера Wi-Fi
if ! git clone https://github.com/Mange/rtl8192eu-linux-driver; then
    echo "Не удалось клонировать репозиторий драйвера"
    exit 1
fi
cd rtl8192eu-linux-driver
if ! dkms add . || ! dkms install rtl8192eu/1.0; then
    echo "Не удалось установить драйвер Wi-Fi"
    exit 1
fi
cd .. && rm -rf rtl8192eu-linux-driver

echo "blacklist rtl8xxxu" > /etc/modprobe.d/rtl8xxxu.conf

echo -e "8192eu\n\nloop" >> /etc/modules
echo "options 8192eu rtw_power_mgnt=0 rtw_enusbss=0" > /etc/modprobe.d/8192eu.conf
update-grub && update-initramfs -u

# Настройка Hostapd
cat <<EOL > /etc/hostapd/hostapd.conf
interface=$(iw dev | awk '/Interface/{print $2}')
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

systemctl unmask hostapd.service
systemctl restart hostapd.service
systemctl enable hostapd.service

# Настройка dnsmasq
cat <<EOL > /etc/dnsmasq.conf
interface=$(iw dev | awk '/Interface/{print $2}')
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

# Настройка NAT
ip addr add $IP_ADD_AP/24 dev $(iw dev | awk '/Interface/{print $2}')
iptables -t nat -A POSTROUTING -o tun0 -j MASQUERADE
netfilter-persistent save

# Завершение
echo "Скрипт выполнен успешно. AP настроен с использованием VPN."
