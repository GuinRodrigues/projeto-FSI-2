# 1. Configurar o IP estático e a Gateway
sudo nmcli connection modify enp0s9 ipv4.addresses 10.60.0.10/24 ipv4.gateway 10.60.0.1 ipv4.method manual
sudo nmcli connection up enp0s9

# 2. Criar diretoria da CA e base de dados (com caminhos absolutos)
sudo mkdir -p /etc/pki/CA/newcerts
sudo touch /etc/pki/CA/index.txt
echo "01" | sudo tee /etc/pki/CA/serial

# 3. Gerar chaves auxiliares para o OpenVPN (DH e TLS Auth)
sudo mkdir -p /etc/openvpn
sudo openssl dhparam -out /etc/openvpn/dh2048.pem 2048
sudo openvpn --genkey secret /etc/openvpn/ta.key

# 4. Gerar a chave e Certificado da CA (com extensões v3)
sudo openssl genrsa -des3 -out /etc/pki/CA/ca.key 2048
sudo openssl req -new -key /etc/pki/CA/ca.key -out /etc/pki/CA/ca.csr
echo -e "keyUsage = cRLSign, digitalSignature, keyCertSign\nbasicConstraints=critical, CA:true, pathlen:0" | sudo tee /etc/pki/CA/v3_ca.ext
sudo openssl x509 -req -days 3650 -in /etc/pki/CA/ca.csr -out /etc/pki/CA/ca.crt -signkey /etc/pki/CA/ca.key -extfile /etc/pki/CA/v3_ca.ext

# 5. APACHE
sudo openssl genrsa -out /etc/pki/CA/apache.key 2048
sudo openssl req -new -key /etc/pki/CA/apache.key -out /etc/pki/CA/apache.csr
sudo bash -c 'printf "subjectAltName = IP:10.60.0.20\nextendedKeyUsage = serverAuth\n" > /etc/pki/CA/v3_apache.ext'
sudo bash -c 'cd /etc/pki/CA && openssl ca -in apache.csr -cert ca.crt -keyfile ca.key -out apache.crt -extfile v3_apache.ext -policy policy_anything -batch'

# 6. VPN Gateway
sudo openssl genrsa -out /etc/pki/CA/vpn_gateway.key 2048
sudo openssl req -new -key /etc/pki/CA/vpn_gateway.key -out /etc/pki/CA/vpn_gateway.csr
sudo bash -c 'printf "extendedKeyUsage = serverAuth\n" > /etc/pki/CA/v3_server.ext'
sudo bash -c 'cd /etc/pki/CA && openssl ca -in vpn_gateway.csr -cert ca.crt -keyfile ca.key -out vpn_gateway.crt -extfile v3_server.ext -policy policy_anything -batch'

# 7. Cliente VPN e Empacotamento P12 para o Browser
sudo openssl genrsa -out /etc/pki/CA/vpn_client.key 2048
sudo openssl req -new -key /etc/pki/CA/vpn_client.key -out /etc/pki/CA/vpn_client.csr
sudo bash -c 'cd /etc/pki/CA && openssl ca -in vpn_client.csr -cert ca.crt -keyfile ca.key -out vpn_client.crt -policy policy_anything -batch'

# Converter para importação no Firefox do Cliente
sudo bash -c 'cd /etc/pki/CA && openssl pkcs12 -export -clcerts -in vpn_client.crt -inkey vpn_client.key -out vpn_client.p12 -certfile ca.crt'
sudo chmod +r /etc/pki/CA/vpn_client.p12

# 8. Iniciar OCSP Responder
sudo bash -c 'cd /etc/pki/CA && openssl ocsp -index index.txt -port 8080 -rsigner ca.crt -rkey ca.key -CA ca.crt -text'