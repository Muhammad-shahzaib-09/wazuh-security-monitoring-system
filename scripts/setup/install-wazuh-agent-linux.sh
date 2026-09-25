#!/bin/bash
#
# Installs and enrolls a Wazuh agent on a Debian/Ubuntu endpoint.
#
# Usage:
#   ./install-wazuh-agent-linux.sh <wazuh-manager-ip>
#
set -euo pipefail

MANAGER_IP="${1:?Usage: $0 <wazuh-manager-ip>}"

echo "[*] Importing Wazuh GPG key..."
curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --no-default-keyring \
  --keyring gnupg-ring:/usr/share/keyrings/wazuh.gpg --import
chmod 644 /usr/share/keyrings/wazuh.gpg

echo "[*] Adding Wazuh apt repository..."
echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" \
  | tee -a /etc/apt/sources.list.d/wazuh.list
apt-get update

echo "[*] Installing wazuh-agent (manager: ${MANAGER_IP})..."
WAZUH_MANAGER="${MANAGER_IP}" apt-get install -y wazuh-agent

echo "[*] Enabling and starting the agent..."
systemctl daemon-reload
systemctl enable wazuh-agent
systemctl start wazuh-agent

echo "[*] Pinning package to avoid manager/agent version drift..."
sed -i "s/^deb/#deb/" /etc/apt/sources.list.d/wazuh.list
apt-get update
echo "wazuh-agent hold" | dpkg --set-selections

echo "[+] Done. Check status with: systemctl status wazuh-agent"
