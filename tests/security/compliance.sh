#!/bin/bash
set -e

echo "Iniciando verificação de conformidade de segurança..."

# Variáveis
REPORT_DIR="/var/log/compliance/$(date +%Y%m%d)"
mkdir -p $REPORT_DIR

# Função para verificar permissões de arquivos
check_file_permissions() {
    echo "Verificando permissões de arquivos críticos..."
    
    declare -A CRITICAL_FILES=(
        ["/etc/shadow"]="400"
        ["/etc/passwd"]="644"
        ["/etc/group"]="644"
        ["/etc/ssh/sshd_config"]="600"
        ["/etc/ssl/private"]="700"
    )
    
    for file in "${!CRITICAL_FILES[@]}"; do
        if [ -f "$file" ]; then
            current_perm=$(stat -c "%a" "$file")
            if [ "$current_perm" != "${CRITICAL_FILES[$file]}" ]; then
                echo "[FALHA] Permissão incorreta em $file: $current_perm (deveria ser ${CRITICAL_FILES[$file]})"
                exit 1
            fi
        fi
    done
}

# Função para verificar configurações do SSH
check_ssh_config() {
    echo "Verificando configurações do SSH..."
    
    declare -A SSH_PARAMS=(
        ["PermitRootLogin"]="no"
        ["PasswordAuthentication"]="no"
        ["X11Forwarding"]="no"
        ["MaxAuthTries"]="4"
        ["Protocol"]="2"
    )
    
    for param in "${!SSH_PARAMS[@]}"; do
        value=$(grep "^$param" /etc/ssh/sshd_config | awk '{print $2}')
        if [ "$value" != "${SSH_PARAMS[$param]}" ]; then
            echo "[FALHA] Configuração SSH incorreta: $param = $value (deveria ser ${SSH_PARAMS[$param]})"
            exit 1
        fi
    done
}

# Função para verificar configurações de auditoria
check_audit_config() {
    echo "Verificando configurações de auditoria..."
    
    # Verificar se auditd está instalado e rodando
    if ! systemctl is-active --quiet auditd; then
        echo "[FALHA] Serviço auditd não está rodando"
        exit 1
    fi
    
    # Verificar regras de auditoria essenciais
    ESSENTIAL_RULES=(
        "arch=b64.*execve.*exit,always"
        "-w /etc/passwd -p wa"
        "-w /etc/shadow -p wa"
        "-w /etc/sudoers -p wa"
    )
    
    for rule in "${ESSENTIAL_RULES[@]}"; do
        if ! auditctl -l | grep -q "$rule"; then
            echo "[FALHA] Regra de auditoria não encontrada: $rule"
            exit 1
        fi
    done
}

# Função para verificar senhas e políticas de conta
check_password_policies() {
    echo "Verificando políticas de senha..."
    
    # Verificar configurações do PAM
    if ! grep -q "pam_pwquality.so" /etc/pam.d/common-password; then
        echo "[FALHA] Módulo pam_pwquality não configurado"
        exit 1
    fi
    
    # Verificar configurações do login.defs
    declare -A LOGIN_PARAMS=(
        ["PASS_MAX_DAYS"]="90"
        ["PASS_MIN_DAYS"]="7"
        ["PASS_WARN_AGE"]="7"
    )
    
    for param in "${!LOGIN_PARAMS[@]}"; do
        value=$(grep "^$param" /etc/login.defs | awk '{print $2}')
        if [ "$value" != "${LOGIN_PARAMS[$param]}" ]; then
            echo "[FALHA] Política de senha incorreta: $param = $value (deveria ser ${LOGIN_PARAMS[$param]})"
            exit 1
        fi
    done
}

# Função para verificar serviços em execução
check_running_services() {
    echo "Verificando serviços em execução..."
    
    # Lista de serviços permitidos
    ALLOWED_SERVICES=(
        "sshd"
        "apache2"
        "docker"
        "auditd"
        "fail2ban"
    )
    
    # Verificar serviços não autorizados
    for service in $(systemctl list-units --type=service --state=running --no-legend | awk '{print $1}'); do
        service_name=$(echo "$service" | cut -d'.' -f1)
        if [[ ! " ${ALLOWED_SERVICES[@]} " =~ " ${service_name} " ]]; then
            echo "[AVISO] Serviço não autorizado em execução: $service_name"
        fi
    done
}

# Função para verificar configurações de rede
check_network_config() {
    echo "Verificando configurações de rede..."
    
    # Verificar configurações do sysctl
    declare -A SYSCTL_PARAMS=(
        ["net.ipv4.ip_forward"]="0"
        ["net.ipv4.conf.all.rp_filter"]="1"
        ["net.ipv4.icmp_echo_ignore_broadcasts"]="1"
        ["net.ipv4.conf.all.accept_redirects"]="0"
        ["net.ipv6.conf.all.disable_ipv6"]="1"
    )
    
    for param in "${!SYSCTL_PARAMS[@]}"; do
        value=$(sysctl -n "$param")
        if [ "$value" != "${SYSCTL_PARAMS[$param]}" ]; then
            echo "[FALHA] Parâmetro sysctl incorreto: $param = $value (deveria ser ${SYSCTL_PARAMS[$param]})"
            exit 1
        fi
    done
}

# Execução principal
main() {
    echo "Iniciando verificações de conformidade..."
    
    check_file_permissions
    check_ssh_config
    check_audit_config
    check_password_policies
    check_running_services
    check_network_config
    
    echo "Verificações de conformidade concluídas com sucesso!"
    echo "Relatório disponível em: $REPORT_DIR"
}

main