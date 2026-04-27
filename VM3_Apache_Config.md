# 1. Configurar o IP estático e a Gateway
sudo nmcli connection modify enp0s3 ipv4.addresses 10.60.0.20/24 ipv4.gateway 10.60.0.1 ipv4.method manual

sudo nmcli connection up enp0s3