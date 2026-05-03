#!/bin/bash
# VM4 — PKI / CA / OCSP (10.60.0.10)
cd "$(dirname "$0")"
git pull 2>/dev/null || true

nmcli_ensure() {
    local iface=$1
    if ! sudo nmcli connection show "$iface" &>/dev/null; then
        sudo nmcli connection add type ethernet ifname "$iface" con-name "$iface" ipv4.method auto
    fi
}

# 1. Configurar o IP estático e a Gateway
nmcli_ensure enp0s9
sudo nmcli connection modify enp0s9 ipv4.addresses 10.60.0.10/24 ipv4.gateway 10.60.0.1 ipv4.method manual
sudo nmcli connection up enp0s9

# 2. Instalar o OpenVPN (necessário para gerar ta.key)
sudo yum install epel-release -y
sudo yum install openvpn -y

# 3. Criar diretório da CA e base de dados
sudo mkdir -p /etc/pki/CA/newcerts
sudo touch /etc/pki/CA/index.txt
echo "unique_subject = no" | sudo tee /etc/pki/CA/index.txt.attr
echo "01" | sudo tee /etc/pki/CA/serial

# 4. Gerar chaves auxiliares para o OpenVPN (DH e TLS Auth)
sudo mkdir -p /etc/openvpn
sudo openssl dhparam -out /etc/openvpn/dh2048.pem 2048
sudo openvpn --genkey secret /etc/openvpn/ta.key

# 5. Gerar a chave e Certificado da CA (com extensões v3)
sudo openssl genrsa -out /etc/pki/CA/ca.key 2048
sudo openssl req -new -key /etc/pki/CA/ca.key -out /etc/pki/CA/ca.csr
echo -e "keyUsage = cRLSign, digitalSignature, keyCertSign\nbasicConstraints=critical, CA:true, pathlen:0" | sudo tee /etc/pki/CA/v3_ca.ext
sudo openssl x509 -req -days 3650 -in /etc/pki/CA/ca.csr -out /etc/pki/CA/ca.crt -signkey /etc/pki/CA/ca.key -extfile /etc/pki/CA/v3_ca.ext

# 6. Certificado do Apache
sudo openssl genrsa -out /etc/pki/CA/apache.key 2048
sudo openssl req -new -key /etc/pki/CA/apache.key -out /etc/pki/CA/apache.csr
sudo bash -c 'printf "subjectAltName = IP:10.60.0.20\nextendedKeyUsage = serverAuth\n" > /etc/pki/CA/v3_apache.ext'
sudo bash -c 'cd /etc/pki/CA && openssl ca -in apache.csr -cert ca.crt -keyfile ca.key -out apache.crt -extfile v3_apache.ext -policy policy_anything -batch'

# 7. Certificado do VPN Gateway
sudo openssl genrsa -out /etc/pki/CA/vpn_gateway.key 2048
sudo openssl req -new -key /etc/pki/CA/vpn_gateway.key -out /etc/pki/CA/vpn_gateway.csr
sudo bash -c 'printf "extendedKeyUsage = serverAuth\n" > /etc/pki/CA/v3_server.ext'
sudo bash -c 'cd /etc/pki/CA && openssl ca -in vpn_gateway.csr -cert ca.crt -keyfile ca.key -out vpn_gateway.crt -extfile v3_server.ext -policy policy_anything -batch'

# 8. Certificado do Cliente VPN e Empacotamento P12 para o Browser
sudo openssl genrsa -out /etc/pki/CA/vpn_client.key 2048
sudo openssl req -new -key /etc/pki/CA/vpn_client.key -out /etc/pki/CA/vpn_client.csr
sudo bash -c 'cd /etc/pki/CA && openssl ca -in vpn_client.csr -cert ca.crt -keyfile ca.key -out vpn_client.crt -policy policy_anything -batch'
sudo bash -c 'cd /etc/pki/CA && openssl pkcs12 -export -clcerts -in vpn_client.crt -inkey vpn_client.key -out vpn_client.p12 -certfile ca.crt'
sudo chmod +r /etc/pki/CA/vpn_client.p12

# 9. Tornar ficheiros legíveis para scp por vboxuser
sudo chmod +r /etc/openvpn/ta.key \
              /etc/openvpn/dh2048.pem \
              /etc/pki/CA/ca.crt \
              /etc/pki/CA/vpn_gateway.key \
              /etc/pki/CA/vpn_gateway.crt \
              /etc/pki/CA/vpn_client.key \
              /etc/pki/CA/vpn_client.crt \
              /etc/pki/CA/apache.key \
              /etc/pki/CA/apache.crt

# 10. Iniciar OCSP Responder (ocupa o terminal — Ctrl+C para terminar)
echo ""
echo "==> A iniciar o servidor OCSP na porta 8080. Ctrl+C para terminar."
sudo bash -c 'cd /etc/pki/CA && openssl ocsp -index index.txt -port 8080 -rsigner ca.crt -rkey ca.key -CA ca.crt -text'

# 11. Limpar tudo o que foi criado
cleanup() {
    echo "==> A remover chaves, certificados e ficheiros da CA..."
    sudo rm -rf /etc/pki/CA/newcerts \
                /etc/pki/CA/index.txt \
                /etc/pki/CA/index.txt.attr \
                /etc/pki/CA/index.txt.old \
                /etc/pki/CA/serial \
                /etc/pki/CA/serial.old \
                /etc/pki/CA/ca.key \
                /etc/pki/CA/ca.csr \
                /etc/pki/CA/ca.crt \
                /etc/pki/CA/v3_ca.ext \
                /etc/pki/CA/apache.key \
                /etc/pki/CA/apache.csr \
                /etc/pki/CA/apache.crt \
                /etc/pki/CA/v3_apache.ext \
                /etc/pki/CA/vpn_gateway.key \
                /etc/pki/CA/vpn_gateway.csr \
                /etc/pki/CA/vpn_gateway.crt \
                /etc/pki/CA/v3_server.ext \
                /etc/pki/CA/vpn_client.key \
                /etc/pki/CA/vpn_client.csr \
                /etc/pki/CA/vpn_client.crt \
                /etc/pki/CA/vpn_client.p12 \
                /etc/openvpn/dh2048.pem \
                /etc/openvpn/ta.key
    echo "==> Limpeza concluída."
}

if [[ "${1}" == "--cleanup" ]]; then
    cleanup
fi
