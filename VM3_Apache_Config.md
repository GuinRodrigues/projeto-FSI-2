# Configurar IP estático e Gateway apontando para a VPN
nmcli con mod enp0s3 ipv4.addresses 10.60.0.10/24
nmcli con mod enp0s3 ipv4.gateway 10.60.0.1
nmcli con mod enp0s3 ipv4.method manual
nmcli con up enp0s3