# Installation & Configuration Guide

This is the full walkthrough condensed from the original FYP report. It assumes a lab/VM
environment (VirtualBox) but the same steps apply to bare metal or cloud VMs.

## 1. Wazuh Server

**Requirements:** 4 CPU cores · 8 GB RAM · 50 GB storage · x86_64/AMD64

1. Download the official Wazuh **OVA** (bundles Manager, Indexer, Dashboard, Filebeat) and import it into VirtualBox. Set the graphics controller to **VMSVGA** to avoid display freezes.
2. Start the VM and log in:
   ```
   User: wazuh-user
   Password: wazuh
   ```
   For root access: `sudo -i`
3. Find the server's IP:
   ```bash
   ip a
   ```
4. Open the dashboard in a browser at `https://<server-ip>` and log in (`admin` / `admin` on first boot — **rotate this immediately**).

**Key config file locations** (for reference/customization):

| Component | Path |
|---|---|
| Wazuh Manager | `/var/ossec/etc/ossec.conf` |
| Wazuh Indexer | `/etc/wazuh-indexer/opensearch.yml` |
| Filebeat | `/etc/filebeat/filebeat.yml` |
| Wazuh Dashboard | `/etc/wazuh-dashboard/opensearch_dashboards.yml` |

> If running in VirtualBox, enable **"Hardware Clock in UTC Time"** under the VM's System settings to avoid alert timestamp drift.

## 2. Enrolling Endpoints

### Windows

```powershell
# CMD or PowerShell
wazuh-agent-4.12.0-1.msi /q WAZUH_MANAGER="<manager-ip>"
NET START Wazuh
```
Agent files land in `C:\Program Files (x86)\ossec-agent`.

### Linux (Ubuntu/Debian)

```bash
curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --no-default-keyring \
  --keyring gnupg-ring:/usr/share/keyrings/wazuh.gpg --import
chmod 644 /usr/share/keyrings/wazuh.gpg

echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" \
  | tee -a /etc/apt/sources.list.d/wazuh.list
apt-get update

WAZUH_MANAGER="<manager-ip>" apt-get install wazuh-agent

systemctl daemon-reload
systemctl enable wazuh-agent
systemctl start wazuh-agent
```

Optionally pin the package to avoid version drift between agent and manager:
```bash
sed -i "s/^deb/#deb/" /etc/apt/sources.list.d/wazuh.list
apt-get update
echo "wazuh-agent hold" | dpkg --set-selections
```

Verify: `systemctl status wazuh-agent`, then confirm the agent shows **active** in the dashboard.

## 3. VirusTotal Integration (Malware Detection)

1. Enable **real-time FIM** on the directory you want scanned (see [`config/ossec-snippets/fim.xml`](../config/ossec-snippets/fim.xml)).
2. Deploy the active-response script — [`scripts/active-response/remove-threat.sh`](../scripts/active-response/remove-threat.sh) — to `/var/ossec/active-response/bin/` and set permissions:
   ```bash
   chmod 750 /var/ossec/active-response/bin/remove-threat.sh
   chown root:wazuh /var/ossec/active-response/bin/remove-threat.sh
   systemctl restart wazuh-agent
   ```
3. On the **manager**, add the integration + active-response block from [`config/ossec-snippets/virustotal-integration.xml`](../config/ossec-snippets/virustotal-integration.xml) to `ossec.conf`, with your own API key.
4. Add the detection rules from [`config/rules/local_rules.xml`](../config/rules/local_rules.xml) to `/var/ossec/etc/rules/local_rules.xml`.
5. Test with the (harmless, industry-standard) EICAR test file:
   ```bash
   curl -Lo /root/eicar.com https://secure.eicar.org/eicar.com
   ```

## 4. Network IDS Integration (Suricata)

On the Linux endpoint you want to monitor:

```bash
sudo add-apt-repository ppa:oisf/suricata-stable
sudo apt-get update
sudo apt-get install suricata -y
```

Pull the Emerging Threats open ruleset:
```bash
cd /tmp/ && curl -LO https://rules.emergingthreats.net/open/suricata-6.0.8/emerging.rules.tar.gz
sudo tar -xvzf emerging.rules.tar.gz
sudo mkdir /etc/suricata/rules && sudo mv rules/*.rules /etc/suricata/rules/
sudo chmod 640 /etc/suricata/rules/*.rules
```

Edit `/etc/suricata/suricata.yaml` — see [`config/suricata/suricata-vars.yaml`](../config/suricata/suricata-vars.yaml) for the exact keys to set (`HOME_NET`, `default-rule-path`, `af-packet.interface`, etc. — use `ifconfig`/`ip a` to find your interface name).

```bash
sudo systemctl restart suricata
```

Point the Wazuh agent at Suricata's `eve.json` log — see [`config/ossec-snippets/suricata-localfile.xml`](../config/ossec-snippets/suricata-localfile.xml) — then:
```bash
sudo systemctl restart wazuh-agent
```

Verify in the dashboard's **Threat Hunting** module with the filter `rule.groups:suricata`.

## 5. Vulnerability Assessment

Add the block from [`config/ossec-snippets/vulnerability-detector.xml`](../config/ossec-snippets/vulnerability-detector.xml) to the **manager's** `ossec.conf`, then:

```bash
/var/ossec/wodles/vulnerability-detector/update-db.py
systemctl restart wazuh-manager
```

Results appear under the **Vulnerability Detection** tab, filterable by CVE, severity, package, and OS.

## 6. Threat Hunting & MITRE ATT&CK

Add custom detection rules (tagged with ATT&CK technique/tactic IDs) to `/var/ossec/etc/rules/local_rules.xml` — see the brute-force example in [`config/rules/local_rules.xml`](../config/rules/local_rules.xml). Enable the **MITRE ATT&CK** module in the dashboard and review alerts under **Threat Hunting → Framework**.

## 7. Email Alerting via Postfix

Wazuh doesn't support authenticated SMTP natively, so Postfix is used as a local relay.

```bash
sudo apt update && sudo apt install postfix mailutils libsasl2-modules
```

Append to `/etc/postfix/main.cf`:
```
relayhost = [smtp.gmail.com]:587
smtp_sasl_auth_enable = yes
smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd
smtp_sasl_security_options = noanonymous
smtp_tls_CAfile = /etc/ssl/certs/ca-certificates.crt
smtp_use_tls = yes
```

Create `/etc/postfix/sasl_passwd`:
```
[smtp.gmail.com]:587 <your-address>@gmail.com:<app-specific-password>
```

Lock it down and load it:
```bash
sudo postmap /etc/postfix/sasl_passwd
sudo chown root:root /etc/postfix/sasl_passwd /etc/postfix/sasl_passwd.db
sudo chmod 0600 /etc/postfix/sasl_passwd /etc/postfix/sasl_passwd.db
sudo systemctl restart postfix
```

Test it:
```bash
echo "Test mail from Postfix" | mail -s "Test Postfix" -r "<your-address>@gmail.com" <recipient>
```

Then point Wazuh's global email config at the local relay — see [`config/ossec-snippets/email-alerts.xml`](../config/ossec-snippets/email-alerts.xml) — and restart:
```bash
sudo systemctl restart wazuh-manager
```

> ⚠️ Use a Gmail **app-specific password**, never your real account password, and never commit `sasl_passwd` to version control (it's already covered by `.gitignore`).

## Maintenance

- Review alerts regularly in the dashboard.
- Tune FIM to exclude noisy paths as they surface.
- Adjust vulnerability-scan intervals for critical systems.
- Revisit `local_rules.xml` as new attack techniques are added.
