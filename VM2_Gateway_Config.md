# 1. Configuração das interfaces Internet e Internal
sudo ifconfig enp0s8 193.136.212.1 netmask 255.255.255.0 up
sudo ifconfig enp0s9 10.60.0.1 netmask 255.255.255.0 up

# 2. Ativar o IP Forwarding 
echo "net.ipv4.ip_forward = 1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# 3. Instalar OpenVPN e Google Authenticator (2FA)
sudo yum install epel-release -y
sudo yum install openvpn google-authenticator -y

# 4. Configurar Utilizador para a VPN (2FA)
sudo useradd roadwarrior
sudo passwd roadwarrior
sudo su - roadwarrior -c "google-authenticator"

# 5. Configurar PAM para o OpenVPN (Exigir password + OTP)
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
openssl ocsp -issuer /etc/pki/CA/ca.crt -CAfile /etc/pki/CA/ca.crt -cert "$peer_cert" -url http://10.60.0.10:8080 > /tmp/ocsp_debug.log 2>&1
if grep -q "good" /tmp/ocsp_debug.log; then
    exit 0
else
    exit 1
fi
EOF'
sudo chmod +x /etc/openvpn/check-ocsp.sh

# 7. Configuração do Servidor OpenVPN (Caminho corrigido para serviços modernos)
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
plugin /usr/lib64/openvpn/plugins/openvpn-plugin-auth-pam.so openvpn

script-security 2
tls-verify /etc/openvpn/check-ocsp.sh
tls-export-cert /tmp
EOF'

# 8. Iniciar VPN
sudo systemctl start openvpn-server@server
sudo systemctl enable openvpn-server@server