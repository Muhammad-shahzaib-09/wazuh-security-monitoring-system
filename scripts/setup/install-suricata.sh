#!/bin/bash
#
# Installs Suricata + the Emerging Threats open ruleset on an Ubuntu endpoint.
# After running, edit /etc/suricata/suricata.yaml — see
# config/suricata/suricata-vars.yaml for the keys you need to set
# (HOME_NET and af-packet.interface, at minimum) — then restart Suricata.
#
set -euo pipefail

echo "[*] Adding Suricata stable PPA..."
sudo add-apt-repository -y ppa:oisf/suricata-stable
sudo apt-get update

echo "[*] Installing Suricata..."
sudo apt-get install -y suricata

echo "[*] Downloading the Emerging Threats open ruleset..."
cd /tmp/
curl -LO https://rules.emergingthreats.net/open/suricata-6.0.8/emerging.rules.tar.gz
sudo mkdir -p /etc/suricata/rules
sudo tar -xvzf emerging.rules.tar.gz
sudo mv rules/*.rules /etc/suricata/rules/
sudo chmod 640 /etc/suricata/rules/*.rules

echo "[+] Suricata installed. Now edit /etc/suricata/suricata.yaml"
echo "    (see config/suricata/suricata-vars.yaml), then run:"
echo "      sudo systemctl restart suricata"
