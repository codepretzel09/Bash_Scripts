#!/bin/bash

#### codepretzel09 > 
# Fetches WAN IP address
wan_search() {
  curl -s https://api.ipify.org
}

# Fetches current LAN IP address
lan_search() {
	if [ "$(uname)" = "Darwin" ]; then
		ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1'
	
	elif [ "$(uname -s)" = "Linux" ]; then
		ip addr show | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1'
	else
		echo "OS not supported"
		exit 1
fi
}

# Fetches Router ip address
router_search() {
	if [ "$(uname)" = "Darwin" ]; then
		netstat -rn | grep default | head -1 | awk '{print$2}'
	elif [ "$(uname -s)" = "Linux" ]; then
		ip route | grep ^default'\s'via | head -1 | awk '{print$3}'
	else
		echo "OS not supported"
		exit 1
fi

# Fetches DNS nameserver
}
dns_search() {
	if [ "$(uname)" = "Darwin" ]; then
		grep -i nameserver /etc/resolv.conf |head -n1|cut -d ' ' -f2
	elif [ "$(uname -s)" = "Linux" ]; then
		cat /etc/resolv.conf | grep -i ^nameserver | cut -d ' ' -f2
	else
		echo "OS not supported"
		exit 1
fi
}

# Define outputs from functions
lanip=$(lan_search)
pubip=$(wan_search)
gate=$(router_search)
dns=$(dns_search)


echo "----------------------------------"
echo "Public IP:" $pubip
echo "----------------------------------"
echo "LAN IP(s):" $lanip
echo "----------------------------------"
echo "Gateway:" $gate
echo "----------------------------------"
echo "DNS:" $dns
echo "----------------------------------"
