#!/usr/bin/env bash

clear
echo
echo "#############################################################"
echo "# One click Install Shadowsocks-libev server and client     #"
echo "# Author: You-know-who                                      #"
echo "# Date: 1999.01.01                                          #"
echo "#                        WARNING                            #"
echo "# Usage: sudo ./shadowsocks-libev-obfs.sh [server|client]   #"
echo "#############################################################"
echo

# Color
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

# Current folder
cur_dir=`pwd`

# Stream Ciphers
ciphers=(
aes-256-gcm
aes-192-gcm
aes-128-gcm
aes-256-ctr
aes-192-ctr
aes-128-ctr
aes-256-cfb
aes-192-cfb
aes-128-cfb
camellia-128-cfb
camellia-192-cfb
camellia-256-cfb
chacha20-ietf-poly1305
chacha20-ietf
chacha20
rc4-md5
)

pre_install(){
	echo
	echo "Press any key to start...or Press Ctrl+C to cancel"
	char=`get_char`

	# Install necessary dependencies
	sudo apt update
	sudo apt install --no-install-recommends build-essential autoconf libtool libssl-dev libpcre3-dev libev-dev asciidoc xmlto automake

	git clone https://github.com/shadowsocks/simple-obfs.git
	cd simple-obfs
	git submodule update --init --recursive
	./autogen.sh
	./configure && make -j8
	sudo make install
	cd ..
	sudo rm -r simple-obfs

	sudo apt install shadowsocks-libev
}

# Get public IP address
get_ip(){
	local IP=$( ip addr | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | egrep -v "^192\.168|^172\.1[6-9]\.|^172\.2[0-9]\.|^172\.3[0-2]\.|^10\.|^127\.|^255\.|^0\." | head -n 1 )
	[ -z ${IP} ] && IP=$( wget -qO- -t1 -T2 ipv4.icanhazip.com )
	[ -z ${IP} ] && IP=$( wget -qO- -t1 -T2 ipinfo.io/ip )
	[ ! -z ${IP} ] && echo ${IP} || echo
}

get_char(){
	SAVEDSTTY=`stty -g`
	stty -echo
	stty cbreak
	dd if=/dev/tty bs=1 count=1 2> /dev/null
	stty -raw
	stty echo
	stty $SAVEDSTTY
}

client_finish(){
	nohup ss-local -c /etc/shadowsocks-libev/config.json start &

	sudo cp /etc/rc.local /etc/rc.local.backup

	sed -i '$d' /etc/rc.local
	sudo cat >> /etc/rc.local<<-EOF
	nohup ss-local -c /etc/shadowsocks-libev/config.json start
	exit 0
EOF

	clear
	echo
	echo "Welcome to cross the Great Wall"
	echo "Enjoy it!"
	echo
}

client_config_shadowsocks(){
	sudo cat > /etc/shadowsocks-libev/config.json<<-EOF
{
    "server":"${shadowsocksip}",
    "server_port":${shadowsocksport},
    "local_port":1080,
    "password":"${shadowsockspwd}",
    "timeout":60,
    "fast_open": true,
    "method":"${shadowsockscipher}",
    "plugin": "/usr/local/bin/obfs-local",
    "plugin_opts": "obfs=http;obfs-host=www.bing.com"
}
EOF
}

# Install Shadowsocks and obfs on client
client_ssobfs(){
	# Set shadowsocks Ip address
	echo "Please enter Ip address for shadowsocks-libev"
	read -p "Ip address:" shadowsocksip
	echo
	echo "---------------------------"
	echo "Ip address = ${shadowsocksip}"
	echo "---------------------------"
	echo

	# Set shadowsocks config port
	while true
	do
	dport=$(shuf -i 9000-19999 -n 1)
	echo "Please enter a port for shadowsocks-libev [1-65535]"
	read -p "(Default port: ${dport}):" shadowsocksport
	[ -z "$shadowsocksport" ] && shadowsocksport=${dport}
	expr ${shadowsocksport} + 1 &>/dev/null
	if [ $? -eq 0 ]; then
		if [ ${shadowsocksport} -ge 1 ] && [ ${shadowsocksport} -le 65535 ] && [ ${shadowsocksport:0:1} != 0 ]; then
			echo
			echo "---------------------------"
			echo "port = ${shadowsocksport}"
			echo "---------------------------"
			echo
			break
		fi
	fi
	echo -e "[${red}Error${plain}] Please enter a correct number [1-65535]"
	done

	# Set shadowsocks config password
	echo "Please enter password for shadowsocks-libev"
	read -p "(Default password: Meow2Meow):" shadowsockspwd
	[ -z "${shadowsockspwd}" ] && shadowsockspwd="Meow2Meow"
	echo
	echo "---------------------------"
	echo "password = ${shadowsockspwd}"
	echo "---------------------------"
	echo

	# Set shadowsocks config stream ciphers
	while true
	do
	echo -e "Please select stream cipher for shadowsocks-libev:"
	for ((i=1;i<=${#ciphers[@]};i++ )); do
		hint="${ciphers[$i-1]}"
		echo -e "${green}${i}${plain}) ${hint}"
	done
	read -p "Which cipher you'd select(Default: ${ciphers[0]}):" pick
	[ -z "$pick" ] && pick=1
	expr ${pick} + 1 &>/dev/null
	if [ $? -ne 0 ]; then
		echo -e "[${red}Error${plain}] Please enter a number"
		continue
	fi
	if [[ "$pick" -lt 1 || "$pick" -gt ${#ciphers[@]} ]]; then
		echo -e "[${red}Error${plain}] Please enter a number between 1 and ${#ciphers[@]}"
		continue
	fi
	shadowsockscipher=${ciphers[$pick-1]}
	echo
	echo "---------------------------"
	echo "cipher = ${shadowsockscipher}"
	echo "---------------------------"
	echo
	break
	done
	pre_install
	client_config_shadowsocks
	client_finish
}

server_finish(){
	nohup ss-server -c /etc/shadowsocks-libev/config.json > /dev/null 2>&1 &

	clear
	echo
	echo -e "Congratulations, Shadowsocks-libev server install completed!"
	echo -e "Your Server IP        : \033[41;37m $(get_ip) \033[0m"
	echo -e "Your Server Port      : \033[41;37m ${shadowsocksport} \033[0m"
	echo -e "Your Password         : \033[41;37m ${shadowsockspwd} \033[0m"
	echo -e "Your Encryption Method: \033[41;37m ${shadowsockscipher} \033[0m"
	echo
	echo "Welcome to cross the Great Wall"
	echo "Enjoy it!"
	echo
}

server_config_shadowsocks(){
	cat > /etc/shadowsocks-libev/config.json<<-EOF
{
    "server":"0.0.0.0",
    "local_port":1080,
    "server_port":${shadowsocksport},
    "password":"${shadowsockspwd}",
    "timeout":60,
    "method":"${shadowsockscipher}",
    "fast_open": true,
    "plugin": "obfs-server",
    "plugin_opts": "obfs=http"
}
EOF
}

# Install Shadowsocks and obfs on server
server_ssobfs(){

	echo "check bbr..."
	echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
	echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf

	echo "check fast_open..."
	echo 3 > /proc/sys/net/ipv4/tcp_fastopen
	echo "net.ipv4.tcp_fastopen = 3" >> /etc/sysctl.conf
	sysctl -p

	# Set shadowsocks config password
	echo "Please enter password for shadowsocks-libev"
	read -p "(Default password: Meow2Meow):" shadowsockspwd
	[ -z "${shadowsockspwd}" ] && shadowsockspwd="Meow2Meow"
	echo
	echo "---------------------------"
	echo "password = ${shadowsockspwd}"
	echo "---------------------------"
	echo

	# Set shadowsocks config port
	while true
	do
	dport=$(shuf -i 9000-19999 -n 1)
	echo "Please enter a port for shadowsocks-libev [1-65535]"
	read -p "(Default port: ${dport}):" shadowsocksport
	[ -z "$shadowsocksport" ] && shadowsocksport=${dport}
	expr ${shadowsocksport} + 1 &>/dev/null
	if [ $? -eq 0 ]; then
		if [ ${shadowsocksport} -ge 1 ] && [ ${shadowsocksport} -le 65535 ] && [ ${shadowsocksport:0:1} != 0 ]; then
			echo
			echo "---------------------------"
			echo "port = ${shadowsocksport}"
			echo "---------------------------"
			echo
			break
		fi
	fi
	echo -e "[${red}Error${plain}] Please enter a correct number [1-65535]"
	done

	# Set shadowsocks config stream ciphers
	while true
	do
	echo -e "Please select stream cipher for shadowsocks-libev:"
	for ((i=1;i<=${#ciphers[@]};i++ )); do
		hint="${ciphers[$i-1]}"
		echo -e "${green}${i}${plain}) ${hint}"
	done
	read -p "Which cipher you'd select(Default: ${ciphers[0]}):" pick
	[ -z "$pick" ] && pick=1
	expr ${pick} + 1 &>/dev/null
	if [ $? -ne 0 ]; then
		echo -e "[${red}Error${plain}] Please enter a number"
		continue
	fi
	if [[ "$pick" -lt 1 || "$pick" -gt ${#ciphers[@]} ]]; then
		echo -e "[${red}Error${plain}] Please enter a number between 1 and ${#ciphers[@]}"
		continue
	fi
	shadowsockscipher=${ciphers[$pick-1]}
	echo
	echo "---------------------------"
	echo "cipher = ${shadowsockscipher}"
	echo "---------------------------"
	echo
	break
	done

	pre_install
	server_config_shadowsocks
	server_finish
}

# Initialization step
action=$1
# [ -z $1 ] && action=server
case "$action" in
	server|client)
		${action}_ssobfs
		;;
	*)
		echo "Arguments error!"
		echo "Usage: sudo ./`basename $0` [server|client]"
	;;
esac
