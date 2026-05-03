# 1. Configurar o IP estático, a máscara (/24) e a Gateway
sudo nmcli connection add type ethernet ifname enp0s8 con-name "enp0s8" ipv4.addresses 193.136.212.10/24 ipv4.gateway 193.136.212.1 ipv4.method manual 
OR if connection already exists:
sudo nmcli connection modify enp0s8 ipv4.addresses 193.136.212.10/24 ipv4.gateway 193.136.212.1 ipv4.method manual
sudo nmcli connection up enp0s8

# 2. Instalar o OpenVPN
sudo yum install epel-release -y
sudo yum install openvpn -y

# 3. Importar certificados do Servidor PKI 
# Corre estes comandos UM a UM. Vão pedir-te a senha do sudo e depois a senha do root do 10.60.0.10
sudo mkdir -p /etc/openvpn
sudo scp root@10.60.0.10:/etc/pki/CA/vpn_client.crt /etc/openvpn/
sudo scp root@10.60.0.10:/etc/pki/CA/vpn_client.key /etc/openvpn/
sudo scp root@10.60.0.10:/etc/pki/CA/ca.crt /etc/openvpn/
sudo scp root@10.60.0.10:/etc/pki/CA/ta.key /etc/openvpn/
sudo scp root@10.60.0.10:/etc/pki/CA/vpn_client.p12 ~/  

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

# Exige Autenticação 2FA (Username/Password + OTP)
auth-user-pass
EOF'

# 5. Ligar à VPN
sudo openvpn --config /etc/openvpn/client.conf
