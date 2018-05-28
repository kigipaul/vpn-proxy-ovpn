#!/bin/bash
NUM=!NUM_REMOTE!
IF=(!REMOTE_IFs!)
DEV=(!LOCAL_IFs!)
NET=(!NETs!)

echo "=== OpenVPN IPTABLE SETTING ==="
#Open forward function 
echo ">> Enable system forward"
echo "1" > /proc/sys/net/ipv4/ip_forward

for ((i=0;i<$NUM;i++)); do
	echo ">> Set iptables ${IF[$i]}--${DEV[$i]}, NET:${NET[$i]}"
	iptables -I INPUT -i ${DEV[$i]} -j ACCEPT
	iptables -I OUTPUT -o ${IF[$i]} -j ACCEPT

	iptables -I FORWARD -i ${IF[$i]} -o ${DEV[$i]} -j ACCEPT
	iptables -I FORWARD -i ${DEV[$i]} -o ${IF[$i]} -j ACCEPT

	iptables -t nat -I POSTROUTING -s ${NET[$i]} -o ${IF[$i]} -j MASQUERADE
done
echo ">> Set iptables INPUT OpenVPN PORT(!SERVER_PORT!) ACCEPT"
iptables -I INPUT -p tcp --dport !SERVER_PORT! -j ACCEPT
iptables -I INPUT -p udp --dport !SERVER_PORT! -j ACCEPT
echo "=== OpenVPN SETTED ==="
