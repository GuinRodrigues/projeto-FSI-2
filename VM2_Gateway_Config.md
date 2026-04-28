# 1. Configuração das interfaces Internet e Internal
## Rede internet
sudo ifconfig enp0s8 193.136.212.1 netmask 255.255.255.0 up
## Rede internal
sudo ifconfig enp0s9 10.60.0.1 netmask 255.255.255.0 up

# 3. Ativar o IP Forwarding 
echo "net.ipv4.ip_forward = 1" | sudo tee -a /etc/sysctl.conf

sudo sysctl -p
