# 1. Configurar o IP estático e a Gateway
sudo nmcli connection modify enp0s9 ipv4.addresses 10.60.0.20/24 ipv4.gateway 10.60.0.1 ipv4.method manual

sudo nmcli connection up enp0s9

## Parte 2 - Configuração Básica do Apache

# Instalar o Apache (httpd) e o módulo SSL
yum install httpd mod_ssl -y

# Cria pasta
mkdir -p /etc/pki/CA

# Vai buscar ficheiros ao OpenSSL
scp root@10.60.0.10:/etc/pki/CA/apache.crt /etc/pki/CA/
scp root@10.60.0.10:/etc/pki/CA/apache.key /etc/pki/CA/
scp root@10.60.0.10:/etc/pki/CA/ca.crt /etc/pki/CA/

 # Editar Apache
nano /etc/httpd/conf.d/ssl.conf

SSLCertificateFile /etc/pki/CA/apache.crt
SSLCertificateKeyFile /etc/pki/CA/apache.key
SSLCACertificateFile /etc/pki/CA/ca.crt

SSLVerifyClient require
SSLVerifyDepth  10

SSLOCSPEnable on
SSLOCSPDefaultResponder "http://10.60.0.10:8080"
SSLOCSPOverrideResponder on

# Abrir Firewall e Iniciar o Apache
firewall-cmd --add-service=https --permanent
firewall-cmd --reload

systemctl start httpd
systemctl enable httpd

# Valida que está a funcionar 
systemctl status httpd
