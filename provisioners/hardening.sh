#!/bin/bash
set -e

echo "Iniciando hardening do sistema..."

# Configurar firewall
apt-get install -y ufw
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 8080/tcp  # Jenkins
ufw allow 9000/tcp  # SonarQube
echo "y" | ufw enable

# Instalar e configurar Fail2ban
apt-get install -y fail2ban
cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3

[apache]
enabled = true
port = http,https
filter = apache-auth
logpath = /var/log/apache2/error.log
maxretry = 3
EOF

# Configurar limites do sistema
cat >> /etc/security/limits.conf << EOF
* soft nofile 65535
* hard nofile 65535
* soft nproc 65535
* hard nproc 65535
EOF

# Configurar parâmetros do kernel
cat > /etc/sysctl.d/99-security.conf << EOF
# Proteção contra ataques de rede
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 5
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Desabilitar IPv6
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1

# Proteção contra ataques ICMP
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1

# Desabilitar roteamento de pacotes
net.ipv4.ip_forward = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# Aumentar range de portas efêmeras
net.ipv4.ip_local_port_range = 32768 60999

# Proteção contra buffer overflow
kernel.randomize_va_space = 2
EOF

# Aplicar configurações do sysctl
sysctl -p /etc/sysctl.d/99-security.conf

# Configurar SSH
sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
systemctl restart sshd

# Instalar e configurar auditd
apt-get install -y auditd
cat > /etc/audit/rules.d/audit.rules << EOF
# Monitorar modificações em arquivos críticos
-w /etc/passwd -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/sudoers -p wa -k identity

# Monitorar comandos sudo
-w /usr/bin/sudo -p x -k sudo_log

# Monitorar modificações em diretórios do sistema
-w /etc/systemd/ -p wa -k systemd
-w /etc/cron.d/ -p wa -k cron
-w /var/spool/cron/ -p wa -k cron

# Monitorar montagem de sistema de arquivos
-a exit,always -F arch=b64 -S mount -S umount2 -k mount

# Monitorar chamadas de sistema críticas
-a exit,always -F arch=b64 -S execve -k exec
EOF

# Reiniciar auditd
service auditd restart

# Instalar rootkit hunter
apt-get install -y rkhunter
rkhunter --update
rkhunter --propupd
rkhunter --check --skip-keypress

# Configurar logrotate
cat > /etc/logrotate.d/custom << EOF
/var/log/auth.log
/var/log/kern.log
/var/log/syslog
{
    rotate 7
    daily
    missingok
    notifempty
    compress
    delaycompress
    sharedscripts
    postrotate
        /usr/lib/rsyslog/rsyslog-rotate
    endscript
}
EOF

echo "Hardening do sistema concluído!"