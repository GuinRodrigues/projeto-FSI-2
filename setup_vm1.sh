#!/bin/bash
# VM1 — Road Warrior / Cliente VPN (193.136.212.10)
cd "$(dirname "$0")"
git pull 2>/dev/null || true

nmcli_ensure() {
    local iface=$1
    if ! sudo nmcli connection show "$iface" &>/dev/null; then
        sudo nmcli connection add type ethernet ifname "$iface" con-name "$iface" ipv4.method auto
    fi
}

# 1. Configurar o IP estático, a máscara (/24) e a Gateway
nmcli_ensure enp0s8
sudo nmcli connection modify enp0s8 ipv4.addresses 193.136.212.10/24 ipv4.gateway 193.136.212.1 ipv4.method manual
sudo nmcli connection up enp0s8

# 2. Instalar o OpenVPN
sudo yum install epel-release -y
sudo yum install openvpn -y

# 3. Importar certificados a partir do Gateway (193.136.212.1)
# O VM1 não tem acesso direto à rede interna — vai buscar ao VM2 que fez relay da VM4
# Corre estes comandos UM a UM. Vão pedir-te a senha do root do 193.136.212.1
sudo mkdir -p /etc/openvpn
sudo scp root@193.136.212.1:/etc/pki/CA/vpn_client.crt /etc/openvpn/
sudo scp root@193.136.212.1:/etc/pki/CA/vpn_client.key /etc/openvpn/
sudo scp root@193.136.212.1:/etc/pki/CA/ca.crt /etc/openvpn/
sudo scp root@193.136.212.1:/etc/openvpn/ta.key /etc/openvpn/
sudo scp root@193.136.212.1:/etc/pki/CA/vpn_client.p12 ~/

# 4. Criar ficheiro de configuração do Cliente (/etc/openvpn/client.conf)
sudo bash -c 'cat > /etc/openvpn/client.conf << EOF
client
dev tun
proto udp
remote 193.136.212.1 1194

ca /etc/openvpn/ca.crt
cert /etc/openvpn/vpn_client.crt
key /etc/openvpn/vpn_client.key
tls-auth /etc/openvpn/ta.key 1

auth-user-pass
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
verb 3
EOF'

# 5. Ligar à VPN
sudo openvpn --config /etc/openvpn/client.conf
