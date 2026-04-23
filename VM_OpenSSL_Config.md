# Configurar IP estático e Gateway apontando para a VPN
nmcli con mod enp0s3 ipv4.addresses 10.60.0.20/24
nmcli con mod enp0s3 ipv4.gateway 10.60.0.1
nmcli con mod enp0s3 ipv4.method manual
nmcli con up enp0s3

## Criar a Certification Authority (CA)
# Common Name (CN): FSI Root CA Guilherme

# 1. Gerar chave privada da CA

openssl genrsa -out ca.key -des3 2048

# 2. Criar o Certificate Signing Request (CSR)

openssl req -new -key ca.key -out ca.csr

# 3. Criar o ficheiro de extensões
cat <<EOF > v3_ca.ext
keyUsage = cRLSign, digitalSignature, keyCertSign
basicConstraints=critical, CA:true,pathlen:0
EOF

# 4. Assinar e gerar o certificado público da CA 
openssl x509 -req -days 3650 -in ca.csr -out ca.crt -signkey ca.key -extfile v3_ca.ext

## Criar certificado para a VPN Gateway
# Common Name (CN): 193.136.212.1

# 1. Chave privada e CSR (Common Name: IP da VPN Externa -> 193.136.212.1)
openssl genrsa -out gw-vpn.key -des3 2048
openssl req -new -key gw-vpn.key -out gw-vpn.csr

# 2. Assinar o certificado usando a tua CA 
openssl x509 -req -days 365 -in gw-vpn.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out gw-vpn.crt

## Criar certificado para o Apache
# Common Name (CN): 10.60.0.10

# 1. Chave privada e CSR (Common Name: 10.60.0.10)
openssl genrsa -out apache.key -des3 2048
openssl req -new -key apache.key -out apache.csr

# 2. Ficheiro de extensões para o Apache 
cat <<EOF > v3.ext
subjectAltName = @alt_names
[alt_names]
IP.1 = 10.60.0.10
EOF

# 3. Assinar o certificado do Apache
openssl x509 -req -days 365 -in apache.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out apache.crt -extfile v3.ext

## Criar certificado para o Cliente
# Common Name (CN): Guilherme

# 1. Chave privada e CSR
openssl genrsa -out cliente.key -des3 2048
openssl req -new -key cliente.key -out cliente.csr

# 2. Assinar o certificado do cliente
openssl x509 -req -days 365 -in cliente.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out cliente.crt

# 3. Converter para PKCS#12 (.p12) para os browsers/OpenVPN lerem facilmente
openssl pkcs12 -export -clcerts -in cliente.crt -inkey cliente.key -out cliente.p12

## Teste 
openssl verify -CAfile ca.crt gw-vpn.crt apache.crt cliente.crt