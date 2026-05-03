#!/bin/bash
# FSI Project 2 — Test Runner
# Usage: bash run-tests.sh <1|2|3|4>
#   1 = VPN Client (road warrior)
#   2 = VPN Gateway
#   3 = Apache HTTPS server
#   4 = PKI / CA / OCSP

PASS=0
FAIL=0

ok()  { echo "[PASS] $1"; ((PASS++)); }
fail(){ echo "[FAIL] $1"; ((FAIL++)); }

run() {
    local desc="$1"; shift
    if eval "$@" &>/dev/null; then ok "$desc"; else fail "$desc"; fi
}

case "$1" in
    1) is_vm1=true;  is_vm2=false; is_vm3=false; is_vm4=false ;;
    2) is_vm1=false; is_vm2=true;  is_vm3=false; is_vm4=false ;;
    3) is_vm1=false; is_vm2=false; is_vm3=true;  is_vm4=false ;;
    4) is_vm1=false; is_vm2=false; is_vm3=false; is_vm4=true  ;;
    *)
        echo "Usage: bash run-tests.sh <1|2|3|4>"
        echo "  1 = VPN Client (193.136.212.10)"
        echo "  2 = VPN Gateway (193.136.212.1 / 10.60.0.1)"
        echo "  3 = Apache HTTPS server (10.60.0.20)"
        echo "  4 = PKI / CA / OCSP (10.60.0.10)"
        exit 1
        ;;
esac

CA=/etc/pki/CA

# ════════════════════════════════════════════════
# VM4 — PKI / OCSP (10.60.0.10)
# ════════════════════════════════════════════════
if $is_vm4; then
    echo ""
    echo "=== VM4: PKI / OCSP (10.60.0.10) ==="

    run "CA certificate exists"             test -f $CA/ca.crt
    run "CA private key exists"             test -f $CA/ca.key
    run "CA cert has CA:true constraint"    openssl x509 -in $CA/ca.crt -noout -text \| grep -q "CA:TRUE"
    run "CA cert has keyCertSign usage"     openssl x509 -in $CA/ca.crt -noout -text \| grep -q "Certificate Sign"
    run "Apache cert exists"                test -f $CA/apache.crt
    run "Apache cert signed by CA"          openssl verify -CAfile $CA/ca.crt $CA/apache.crt
    run "Apache cert has serverAuth EKU"    openssl x509 -in $CA/apache.crt -noout -text \| grep -q "TLS Web Server Authentication"
    run "VPN Gateway cert exists"           test -f $CA/vpn_gateway.crt
    run "VPN Gateway cert signed by CA"     openssl verify -CAfile $CA/ca.crt $CA/vpn_gateway.crt
    run "VPN Gateway cert has serverAuth"   openssl x509 -in $CA/vpn_gateway.crt -noout -text \| grep -q "TLS Web Server Authentication"
    run "VPN Client cert exists"            test -f $CA/vpn_client.crt
    run "VPN Client cert signed by CA"      openssl verify -CAfile $CA/ca.crt $CA/vpn_client.crt
    run "PKCS12 bundle exists for browser"  test -f $CA/vpn_client.p12
    run "CA index.txt (cert database) exists" test -f $CA/index.txt
    run "CA serial file exists"             test -f $CA/serial
    run "OCSP responder listening on 8080"  ss -ulnp \| grep -q 8080
    run "OCSP responds 'good' for client cert" \
        "openssl ocsp -issuer $CA/ca.crt -CAfile $CA/ca.crt -cert $CA/vpn_client.crt \
         -url http://10.60.0.10:8080 -noverify 2>&1 | grep -q ': good'"
    run "Apache SAN includes 10.60.0.20"    openssl x509 -in $CA/apache.crt -noout -text \| grep -q "10.60.0.20"
fi

# ════════════════════════════════════════════════
# VM2 — VPN Gateway (193.136.212.1 / 10.60.0.1)
# ════════════════════════════════════════════════
if $is_vm2; then
    echo ""
    echo "=== VM2: VPN Gateway (193.136.212.1 / 10.60.0.1) ==="

    run "IP forwarding enabled"             "sysctl net.ipv4.ip_forward 2>/dev/null | grep -q '= 1'"
    run "OpenVPN service active"            systemctl is-active openvpn-server@server
    run "OpenVPN listening on UDP 1194"     ss -ulnp \| grep -q 1194
    run "Server config exists"              test -f /etc/openvpn/server/server.conf
    run "Server config has plugin auth-pam" grep -q "openvpn-plugin-auth-pam" /etc/openvpn/server/server.conf
    run "Server config has tls-verify"      grep -q "tls-verify" /etc/openvpn/server/server.conf
    run "OCSP check script exists"          test -f /etc/openvpn/check-ocsp.sh
    run "OCSP check script is executable"   test -x /etc/openvpn/check-ocsp.sh
    run "PAM openvpn config exists"         test -f /etc/pam.d/openvpn
    run "PAM uses google_authenticator"     grep -q "pam_google_authenticator" /etc/pam.d/openvpn
    run "PAM uses pam_unix (password)"      grep -q "pam_unix" /etc/pam.d/openvpn
    run "roadwarrior user exists"           id roadwarrior
    run "VPN Gateway cert exists"           test -f /etc/pki/CA/vpn_gateway.crt
    run "VPN Gateway key exists"            test -f /etc/pki/CA/vpn_gateway.key
    run "CA cert present on gateway"        test -f /etc/pki/CA/ca.crt
    run "DH params file exists"             test -f /etc/openvpn/dh2048.pem
    run "TLS-auth key exists"               test -f /etc/openvpn/ta.key
    run "iptables FORWARD rule for tun"     iptables -L FORWARD \| grep -q "ACCEPT"
    run "iptables MASQUERADE rule for VPN"  iptables -t nat -L POSTROUTING \| grep -q "MASQUERADE"
    run "OCSP check script points to VM4"   grep -q "10.60.0.10" /etc/openvpn/check-ocsp.sh
    run "OCSP reachable from gateway"       "openssl ocsp -issuer /etc/pki/CA/ca.crt -CAfile /etc/pki/CA/ca.crt \
        -cert /etc/pki/CA/vpn_client.crt -url http://10.60.0.10:8080 -noverify 2>&1 | grep -q ': good'"
fi

# ════════════════════════════════════════════════
# VM3 — Apache HTTPS (10.60.0.20)
# ════════════════════════════════════════════════
if $is_vm3; then
    echo ""
    echo "=== VM3: Apache HTTPS Server (10.60.0.20) ==="

    run "Apache (httpd) service active"     systemctl is-active httpd
    run "Apache listening on TCP 443"       ss -tlnp \| grep -q ":443"
    run "ssl.conf exists"                   test -f /etc/httpd/conf.d/ssl.conf
    run "SSLVerifyClient require in config" grep -q "SSLVerifyClient require" /etc/httpd/conf.d/ssl.conf
    run "SSLOCSPEnable in config"           grep -q "SSLOCSPEnable" /etc/httpd/conf.d/ssl.conf
    run "OCSP responder points to VM4"      grep -q "10.60.0.10" /etc/httpd/conf.d/ssl.conf
    run "Apache cert path configured"       grep -q "SSLCertificateFile" /etc/httpd/conf.d/ssl.conf
    run "Apache CA cert path configured"    grep -q "SSLCACertificateFile" /etc/httpd/conf.d/ssl.conf
    run "PAM module conf exists"            test -f /etc/httpd/conf.modules.d/55-authnz_pam.conf
    run "PAM httpd-otp config exists"       test -f /etc/pam.d/httpd-otp
    run "PAM uses google_authenticator"     grep -q "pam_google_authenticator" /etc/pam.d/httpd-otp
    run "GA secrets dir exists"             test -d /etc/httpd/ga_secrets
    run "GA secrets file exists"            test -f /etc/httpd/ga_secrets/web_user
    run "Apache cert signed by CA"          openssl verify -CAfile /etc/pki/CA/ca.crt /etc/pki/CA/apache.crt
    run "VirtualHost has AuthBasicProvider PAM" grep -q "AuthBasicProvider PAM" /etc/httpd/conf.d/ssl.conf
    run "Route to VPN subnet (10.8.0.0) exists" ip route \| grep -q "10.8.0.0"
    run "OCSP reachable from Apache server" \
        "openssl ocsp -issuer /etc/pki/CA/ca.crt -CAfile /etc/pki/CA/ca.crt \
         -cert /etc/pki/CA/vpn_client.crt -url http://10.60.0.10:8080 -noverify 2>&1 | grep -q ': good'"
    run "HTTPS rejects connection without client cert" \
        "curl -sk --cert-type PEM https://10.60.0.20 2>&1 | grep -qiE 'alert|handshake|certificate'"
fi

# ════════════════════════════════════════════════
# VM1 — VPN Client / Road Warrior (193.136.212.10)
# ════════════════════════════════════════════════
if $is_vm1; then
    echo ""
    echo "=== VM1: VPN Client / Road Warrior (193.136.212.10) ==="

    run "OpenVPN installed"                 which openvpn
    run "Client config exists"              test -f /etc/openvpn/client.conf
    run "Client config has auth-user-pass"  grep -q "auth-user-pass" /etc/openvpn/client.conf
    run "Client config has remote-cert-tls server" grep -q "remote-cert-tls server" /etc/openvpn/client.conf
    run "VPN client cert exists"            test -f /etc/openvpn/vpn_client.crt
    run "VPN client key exists"             test -f /etc/openvpn/vpn_client.key
    run "CA cert exists on client"          test -f /etc/openvpn/ca.crt
    run "TLS-auth key exists on client"     test -f /etc/openvpn/ta.key
    run "PKCS12 bundle for Firefox present" "ls ~/vpn_client.p12 2>/dev/null || test -f /etc/openvpn/vpn_client.p12"
    run "tun0 interface up (VPN connected)" ip addr show tun0
    run "Route to internal network (10.60.0.0/24) via tun0" ip route \| grep -q "10.60.0.0.*tun0"
    run "Ping VPN gateway internal IP"      ping -c1 -W2 10.60.0.1
    run "Ping Apache server via VPN"        ping -c1 -W2 10.60.0.20
    run "Gateway reachable on WAN"          ping -c1 -W2 193.136.212.1
fi

# ════════════════════════════════════════════════
echo ""
echo "Results: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ] && exit 0 || exit 1
