#!/bin/bash
#
# Configures Postfix as a local SMTP relay through Gmail, so Wazuh
# (which has no native SMTP auth support) can send email alerts.
#
# Run this, then manually create /etc/postfix/sasl_passwd with your
# own credentials (see docs/installation-guide.md, section 7) —
# credentials are intentionally NOT handled by this script.
#
set -euo pipefail

echo "[*] Installing Postfix..."
sudo apt update
sudo apt install -y postfix mailutils libsasl2-modules

echo "[*] Appending relay configuration to /etc/postfix/main.cf..."
cat <<'EOF' | sudo tee -a /etc/postfix/main.cf

# --- Added for Wazuh email alerting relay ---
relayhost = [smtp.gmail.com]:587
smtp_sasl_auth_enable = yes
smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd
smtp_sasl_security_options = noanonymous
smtp_tls_CAfile = /etc/ssl/certs/ca-certificates.crt
smtp_use_tls = yes
EOF

echo "[+] Postfix relay config appended."
echo "    Next steps:"
echo "      1. Create /etc/postfix/sasl_passwd with:"
echo '         [smtp.gmail.com]:587 <you>@gmail.com:<app-specific-password>'
echo "      2. sudo postmap /etc/postfix/sasl_passwd"
echo "      3. sudo chown root:root /etc/postfix/sasl_passwd /etc/postfix/sasl_passwd.db"
echo "      4. sudo chmod 0600 /etc/postfix/sasl_passwd /etc/postfix/sasl_passwd.db"
echo "      5. sudo systemctl restart postfix"
echo ""
echo "    Use a Gmail APP-SPECIFIC PASSWORD, never your real account password."
