# Configurar o IP estático e a Gateway
sudo nmcli connection modify enp0s9 ipv4.addresses 10.60.0.10/24 ipv4.gateway 10.60.0.1 ipv4.method manual

sudo nmcli connection up enp0s9

##
# Navegar para a diretoria da CA
cd /etc/pki/CA

# Criar a base de dados de certificados emitidos 
touch index.txt

# Criar o ficheiro que controla o número de série dos certificados
echo 01 > serial

##
# 1. Gerar a chave privada da CA (protegida com password: fsi2026)
openssl genrsa -des3 -out ca.key 2048

# 2. Gerar o Pedido de Assinatura de Certificado (CSR) para a CA
# Country Name: PT
# State or Province Name: Coimbra
# Locality Name: Coimbra
# Organization Name: FSI
# Organizational Unit Name: FSI
# Common Name: CA_PRIVADA_FSI
openssl req -new -key ca.key -out ca.csr

# 3. Auto-assinar o certificado da CA 
openssl x509 -req -days 3650 -in ca.csr -out ca.crt -signkey ca.key

## APACHE
openssl genrsa -out apache.key 2048

# Country Name: PT
# State or Province Name: Coimbra
# Locality Name: Coimbra
# Organization Name: FSI
# Organizational Unit Name: Web Servers
# Common Name: 10.60.0.20  
openssl req -new -key apache.key -out apache.csr
openssl ca -in apache.csr -cert ca.crt -keyfile ca.key -out apache.crt

## VPN Gateway
openssl genrsa -out vpn_gateway.key 2048

# Country Name: PT
# State or Province Name: Coimbra
# Locality Name: Coimbra
# Organization Name: FSI
# Organizational Unit Name: Gateway
# Common Name: VPN_GATEWAY_FSI

openssl req -new -key vpn_gateway.key -out vpn_gateway.csr
openssl ca -in vpn_gateway.csr -cert ca.crt -keyfile ca.key -out vpn_gateway.crt

## Cliente VPN
openssl genrsa -out vpn_client.key 2048

# Country Name: PT
# State or Province Name: Coimbra
# Locality Name: Coimbra
# Organization Name: FSI
# Organizational Unit Name: Remote Users
# Common Name: user_RoadWarrior

openssl req -new -key vpn_client.key -out vpn_client.csr
openssl ca -in vpn_client.csr -cert ca.crt -keyfile ca.key -out vpn_client.crt

## OCSP
cd /etc/pki/CA
openssl ocsp -index index.txt -port 8080 -rsigner ca.crt -rkey ca.key -CA ca.crt -text
