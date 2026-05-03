#!/bin/bash
# VM2 — VPN Gateway (WAN: 193.136.212.1 / LAN: 10.60.0.1)
cd "$(dirname "$0")"
git pull 2>/dev/null || true

nmcli_ensure() {
    local iface=$1
    if ! sudo nmcli connection show "$iface" &>/dev/null; then
        sudo nmcli connection add type ethernet ifname "$iface" con-name "$iface" ipv4.method auto
    fi
}

# 1. Configuração das interfaces Internet e Internal
nmcli_ensure enp0s8
sudo nmcli connection modify enp0s8 ipv4.addresses 193.136.212.1/24 ipv4.method manual
sudo nmcli connection up enp0s8
nmcli_ensure enp0s9
sudo nmcli connection modify enp0s9 ipv4.addresses 10.60.0.1/24 ipv4.method manual
sudo nmcli connection up enp0s9

# 2. Ativar o IP Forwarding
echo "net.ipv4.ip_forward = 1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# 2.5. Copiar certificados e chaves da VM PKI (10.60.0.10)
# O VM2 serve de relay: copia tudo da VM4 e o VM1 vai buscar aqui depois
sudo mkdir -p /etc/pki/CA /etc/openvpn
sudo scp vboxuser@10.60.0.10:/etc/pki/CA/ca.crt /etc/pki/CA/
sudo scp vboxuser@10.60.0.10:/etc/pki/CA/vpn_gateway.crt /etc/pki/CA/
sudo scp vboxuser@10.60.0.10:/etc/pki/CA/vpn_gateway.key /etc/pki/CA/
sudo scp vboxuser@10.60.0.10:/etc/pki/CA/vpn_client.crt /etc/pki/CA/
sudo scp vboxuser@10.60.0.10:/etc/pki/CA/vpn_client.key /etc/pki/CA/
sudo scp vboxuser@10.60.0.10:/etc/pki/CA/vpn_client.p12 /etc/pki/CA/
sudo scp vboxuser@10.60.0.10:/etc/openvpn/ta.key /etc/openvpn/
sudo scp vboxuser@10.60.0.10:/etc/openvpn/dh2048.pem /etc/openvpn/

# 3. Instalar OpenVPN e Google Authenticator (2FA)
sudo yum install epel-release -y
sudo yum install openvpn google-authenticator -y

# 4. Configurar Utilizador para a VPN (2FA)
sudo useradd roadwarrior
sudo passwd roadwarrior
sudo su - roadwarrior -c "google-authenticator"

# 5. Configurar PAM para o OpenVPN (exigir palavra-passe + OTP)
sudo bash -c 'cat > /etc/pam.d/openvpn << EOF
auth required pam_google_authenticator.so forward_pass
auth required pam_unix.so use_first_pass
account required pam_unix.so
EOF'

# 6. Criar Script de Validação OCSP do OpenVPN
sudo bash -c 'cat > /etc/openvpn/check-ocsp.sh << "EOF"
#!/bin/bash
if [ "$1" -ne 0 ]; then
    exit 0
fi
status=$(openssl ocsp -issuer /etc/pki/CA/ca.crt -CAfile /etc/pki/CA/ca.crt \
    -url http://10.60.0.10:8080 -serial "${tls_serial_0}" 2>&1)
if echo "$status" | grep -q ": good"; then
    exit 0
else
    exit 1
fi
EOF'
sudo chmod +x /etc/openvpn/check-ocsp.sh

# 7. Configuração do Servidor OpenVPN
sudo mkdir -p /etc/openvpn/server
sudo bash -c 'cat > /etc/openvpn/server/server.conf << EOF
local 193.136.212.1
port 1194
proto udp
dev tun

ca /etc/pki/CA/ca.crt
cert /etc/pki/CA/vpn_gateway.crt
key /etc/pki/CA/vpn_gateway.key
dh /etc/openvpn/dh2048.pem
tls-auth /etc/openvpn/ta.key 0

server 10.8.0.0 255.255.255.0
push "route 10.60.0.0 255.255.255.0"
plugin /usr/lib64/openvpn/plugins/openvpn-plugin-auth-pam.so openvpn

script-security 2
tls-verify /etc/openvpn/check-ocsp.sh
EOF'

# 7.5. Configurar reencaminhamento de pacotes (iptables)
sudo iptables -A FORWARD -i tun+ -j ACCEPT
sudo iptables -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o enp0s9 -j MASQUERADE

# 8. Iniciar VPN
sudo systemctl start openvpn-server@server
sudo systemctl enable openvpn-server@server
