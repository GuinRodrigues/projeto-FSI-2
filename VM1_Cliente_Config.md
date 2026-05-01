# 1. Configuração das interfaces Internet e Internal
## Rede internet
ifconfig enp0s8 193.136.212.10 netmask 255.255.255.0 up
ip route add default via 193.136.212.1

# 3. Ativar o IP Forwarding 
echo "net.ipv4.ip_forward = 1" | sudo tee -a /etc/sysctl.conf

sudo sysctl -p
