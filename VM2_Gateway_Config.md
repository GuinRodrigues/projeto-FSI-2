# 1. Configurar a placa virada para a "Internet"
sudo nmcli connection modify enp0s3 ipv4.addresses 193.136.212.1/24 ipv4.method manual
sudo nmcli connection up enp0s3

sudo nmcli connection add type ethernet ifname enp0s8 con-name enp0s8 ipv4.addresses 10.60.0.1/24 ipv4.method manual
sudo nmcli connection up enp0s8

# 3. Ativar o IP Forwarding 
echo "net.ipv4.ip_forward = 1" | sudo tee -a /etc/sysctl.conf

sudo sysctl -p