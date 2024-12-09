#!/bin/bash
set -e

echo "Iniciando verificação de conformidade..."

# Variáveis
REPORT_DIR="/var/log/compliance/$(date +%Y%m%d)"
mkdir -p $REPORT_DIR

# Função para verificar conformidade com CIS Benchmark
check_cis_compliance() {
    echo "Verificando conformidade com CIS Benchmark..."
    
    # Lista de verificações baseadas no CIS
    declare -A cis_checks=(
        ["1.1.1.1"]="Ensure mounting of cramfs filesystems is disabled"
        ["1.1.1.2"]="Ensure mounting of freevxfs filesystems is disabled"
        ["1.1.1.3"]="Ensure mounting of jffs2 filesystems is disabled"
        ["2.1.1"]="Ensure chargen services are not enabled"
        ["2.1.2"]="Ensure daytime services are not enabled"
        ["3.1.1"]="Ensure IP forwarding is disabled"
        ["3.1.2"]="Ensure packet redirect sending is disabled"
    )
    
    for check_id in "${!cis_checks[@]}"; do
        echo "Verificando $check_id: ${cis_checks[$check_id]}"
        case $check_id in
            "1.1.1.1")
                if lsmod | grep -q "cramfs"; then
                    echo "FALHA: cramfs está carregado"
                    exit 1
                fi
                ;;
            "3.1.1")
                if [ "$(cat /proc/sys/net/ipv4/ip_forward)" != "0" ]; then
                    echo "FALHA: IP forwarding está habilitado"
                    exit 1
                fi
                ;;
            # Adicionar mais verificações conforme necessário
        esac
    done
}

# Função para verificar conformidade GDPR
check_gdpr_compliance() {
    echo "Verificando conformidade com GDPR..."
    
    # Verificar política de privacidade
    if [ ! -f "/var/www/html/privacy-policy.html" ]; then
        echo "FALHA: Política de privacidade não encontrada"
        exit 1
    fi
    
    # Verificar configurações de cookies
    if ! grep -q "cookie-consent" /var/www/html/index.html; then
        echo "FALHA: Aviso de cookies não implementado"
        exit 1
    fi
    
    # Verificar logs de acesso a dados pessoais
    if [ ! -f "/var/log/data-access.log" ]; then
        echo "FALHA: Log de acesso a dados pessoais não encontrado"
        exit 1
    fi
}

# Função para verificar conformidade PCI DSS
check_pci_compliance() {
    echo "Verificando conformidade com PCI DSS..."
    
    # Verificar criptografia de dados
    if ! openssl version | grep -q "OpenSSL"; then
        echo "FALHA: OpenSSL não instalado"
        exit 1
    fi
    
    # Verificar firewall
    if ! systemctl is-active --quiet ufw; then
        echo "FALHA: Firewall não está ativo"
        exit 1
    fi
    
    # Verificar logs de auditoria
    if ! systemctl is-active --quiet auditd; then
        echo "FALHA: Sistema de auditoria não está ativo"
        exit 1
    fi
}

# Função para verificar políticas de senha
check_password_policies() {
    echo "Verificando políticas de senha..."
    
    # Verificar configurações do PAM
    if ! grep -q "pam_pwquality.so" /etc/pam.d/common-password; then
        echo "FALHA: Módulo pam_pwquality não configurado"
        exit 1
    fi
    
    # Verificar histórico de senhas
    if ! grep -q "remember=5" /etc/pam.d/common-password; then
        echo "FALHA: Histórico de senhas não configurado"
        exit 1
    fi
}

# Função para verificar atualizações de segurança
check_security_updates() {
    echo "Verificando atualizações de segurança..."
    
    # Verificar se existem atualizações pendentes
    if apt list --upgradable 2>/dev/null | grep -q "security"; then
        echo "FALHA: Existem atualizações de segurança pendentes"
        exit 1
    fi
}

# Função para gerar relatório
generate_report() {
    echo "Gerando relatório de conformidade..."
    
    cat > "$REPORT_DIR/compliance-report.html" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Relatório de Conformidade</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .check { margin: 10px 0; padding: 10px; border: 1px solid #ddd; }
        .pass { color: green; }
        .fail { color: red; }
    </style>
</head>
<body>
    <h1>Relatório de Conformidade</h1>
    <h2>Data: $(date)</h2>
    
    <div class="section">
        <h3>CIS Benchmark</h3>
        <pre>$(check_cis_compliance 2>&1)</pre>
    </div>
    
    <div class="section">
        <h3>GDPR</h3>
        <pre>$(check_gdpr_compliance 2>&1)</pre>
    </div>
    
    <div class="section">
        <h3>PCI DSS</h3>
        <pre>$(check_pci_compliance 2>&1)</pre>
    </div>
    
    <div class="section">
        <h3>Políticas de Senha</h3>
        <pre>$(check_password_policies 2>&1)</pre>
    </div>
    
    <div class="section">
        <h3>Atualizações de Segurança</h3>
        <pre>$(check_security_updates 2>&1)</pre>
    </div>
</body>
</html>
EOF
}

# Execução principal
main() {
    echo "Iniciando verificações de conformidade..."
    
    check_cis_compliance
    check_gdpr_compliance
    check_pci_compliance
    check_password_policies
    check_security_updates
    generate_report
    
    echo "Verificações de conformidade concluídas!"
    echo "Relatório disponível em: $REPORT_DIR/compliance-report.html"
}

# Executar verificações
main