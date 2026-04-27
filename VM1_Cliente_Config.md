# 1. Configurar o IP estático, a máscara (/24) e a Gateway
sudo nmcli connection modify enp0s3 ipv4.addresses 193.136.212.10/24 ipv4.gateway 193.136.212.1 ipv4.method manual

sudo nmcli connection up enp0s3