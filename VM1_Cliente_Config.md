# Configurar o IP estático e Gateway
nmcli con mod enp0s3 ipv4.addresses 193.136.212.10/24
nmcli con mod enp0s3 ipv4.gateway 193.136.212.1
nmcli con mod enp0s3 ipv4.method manual
nmcli con up enp0s3