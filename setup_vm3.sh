#!/bin/bash
# VM3 — Apache / HTTPS (10.60.0.20)
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
sudo nmcli connection modify enp0s9 ipv4.addresses 10.60.0.20/24 ipv4.gateway 10.60.0.1 ipv4.method manual
sudo nmcli connection up enp0s9

# 2. Instalar o Apache, módulo SSL e PAM
sudo yum install epel-release -y
sudo yum install httpd mod_ssl mod_authnz_pam google-authenticator -y

# 3. Obter Certificados da CA (Terás de inserir a palavra-passe de root do 10.60.0.10)
sudo mkdir -p /etc/pki/CA
sudo scp vboxuser@10.60.0.10:/etc/pki/CA/apache.crt /etc/pki/CA/
sudo scp vboxuser@10.60.0.10:/etc/pki/CA/apache.key /etc/pki/CA/
sudo scp vboxuser@10.60.0.10:/etc/pki/CA/ca.crt /etc/pki/CA/

# 4. Configurar Google Authenticator (OTP) para o Apache
sudo mkdir -p /etc/httpd/ga_secrets
sudo chown apache:apache /etc/httpd/ga_secrets
sudo chmod 700 /etc/httpd/ga_secrets
sudo google-authenticator -s /etc/httpd/ga_secrets/web_user
sudo chown apache:apache /etc/httpd/ga_secrets/web_user
sudo chmod 400 /etc/httpd/ga_secrets/web_user
sudo sed -i '/DISALLOW_REUSE/d' /etc/httpd/ga_secrets/web_user

# 5. Criar ficheiro PAM para o Apache
sudo bash -c 'cat > /etc/pam.d/httpd-otp << "EOF"
auth       required     pam_google_authenticator.so secret=/etc/httpd/ga_secrets/web_user user=apache
account    required     pam_permit.so
EOF'
echo "LoadModule authnz_pam_module modules/mod_authnz_pam.so" | sudo tee /etc/httpd/conf.modules.d/55-authnz_pam.conf

# 6. Configurar o Apache para HTTPS com autenticação de cliente e OTP
sudo bash -c 'cat > /etc/httpd/conf.d/ssl.conf << "EOF"
Listen 443 https

SSLPassPhraseDialog exec:/usr/libexec/httpd-ssl-pass-dialog
SSLSessionCache         shmcb:/run/httpd/sslcache(512000)
SSLSessionCacheTimeout  300

<VirtualHost _default_:443>

ErrorLog logs/ssl_error_log
TransferLog logs/ssl_access_log
LogLevel warn

SSLEngine on

SSLCertificateFile      /etc/pki/CA/apache.crt
SSLCertificateKeyFile   /etc/pki/CA/apache.key
SSLCACertificateFile    /etc/pki/CA/ca.crt

SSLVerifyClient require
SSLVerifyDepth  10

SSLOCSPEnable on
SSLOCSPDefaultResponder http://10.60.0.10:8080
SSLOCSPOverrideResponder on

<Directory "/var/www/html">
    AuthType Basic
    AuthName "Autenticacao OTP (Google Authenticator)"
    AuthBasicProvider PAM
    AuthPAMService httpd-otp
    Require valid-user
</Directory>

</VirtualHost>
EOF'

# 7. Adicionar rota para a rede VPN
sudo ip route add 10.8.0.0/24 via 10.60.0.1

# 8. Abrir Firewall e Iniciar o Apache
sudo setenforce 0
sudo firewall-cmd --add-service=https --permanent
sudo firewall-cmd --reload
sudo systemctl start httpd
sudo systemctl enable httpd
