# Adaptador 1 (Rede Externa)
nmcli con mod enp0s3 ipv4.addresses 193.136.212.1/24
nmcli con mod enp0s3 ipv4.method manual
nmcli con up enp0s3

# Adaptador 2 (Rede Interna)
nmcli con mod enp0s8 ipv4.addresses 10.60.0.1/24
nmcli con mod enp0s8 ipv4.method manual
nmcli con up enp0s8

# Ativar o IP Forwarding (essencial para a gateway reencaminhar tráfego)
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
sysctl -p