#!/bin/bash
set -e

echo "Iniciando testes de SSL/TLS..."

# Variáveis
TARGET_HOST="localhost"
TARGET_PORT="443"
REPORT_DIR="/var/log/integration-tests/ssl/$(date +%Y%m%d)"
mkdir -p $REPORT_DIR

# Função para verificar certificado SSL
check_certificate() {
    echo "Verificando certificado SSL..."
    
    # Obter informações do certificado
    openssl s_client -connect ${TARGET_HOST}:${TARGET_PORT} \
        -servername ${TARGET_HOST} </dev/null 2>/dev/null \
        | openssl x509 -text > "$REPORT_DIR/certificate.txt"
    
    # Verificar data de expiração
    expiry_date=$(openssl x509 -enddate -noout -in "$REPORT_DIR/certificate.txt" \
        | cut -d= -f2-)
    expiry_epoch=$(date -d "$expiry_date" +%s)
    current_epoch=$(date +%s)
    days_until_expiry=$(( ($expiry_epoch - $current_epoch) / 86400 ))
    
    if [ $days_until_expiry -lt 30 ]; then
        echo "[FALHA] Certificado expira em menos de 30 dias"
        exit 1
    else
        echo "[OK] Certificado válido por mais $days_until_expiry dias"
    fi
}

# Função para testar protocolos suportados
test_ssl_protocols() {
    echo "Testando protocolos SSL/TLS suportados..."
    
    # Lista de protocolos a serem testados
    declare -A PROTOCOLS=(
        ["ssl2"]="não deve ser suportado"
        ["ssl3"]="não deve ser suportado"
        ["tls1"]="não deve ser suportado"
        ["tls1_1"]="não deve ser suportado"
        ["tls1_2"]="deve ser suportado"
        ["tls1_3"]="deve ser suportado"
    )
    
    for protocol in "${!PROTOCOLS[@]}"; do
        echo "Testando $protocol..."
        result=$(openssl s_client -connect ${TARGET_HOST}:${TARGET_PORT} \
            -servername ${TARGET_HOST} \
            -"$protocol" </dev/null 2>&1)
        
        if [[ "${PROTOCOLS[$protocol]}" == "deve ser suportado" ]]; then
            if echo "$result" | grep -q "Connection established"; then
                echo "[OK] $protocol suportado corretamente"
            else
                echo "[FALHA] $protocol deveria ser suportado"
                exit 1
            fi
        else
            if echo "$result" | grep -q "Connection established"; then
                echo "[FALHA] $protocol não deveria ser suportado"
                exit 1
            else
                echo "[OK] $protocol corretamente não suportado"
            fi
        fi
    done
}

# Função para testar cipher suites
test_cipher_suites() {
    echo "Testando cipher suites..."
    
    # Obter lista de ciphers suportados
    ciphers=$(openssl ciphers 'ALL:eNULL' | tr ':' '\n')
    
    echo "Testando ciphers individuais..."
    while IFS= read -r cipher; do
        result=$(openssl s_client -cipher "$cipher" \
            -connect ${TARGET_HOST}:${TARGET_PORT} </dev/null 2>&1)
        
        if echo "$result" | grep -q "Cipher is ${cipher}"; then
            # Verificar se é um cipher seguro
            if echo "$cipher" | grep -qE "NULL|EXPORT|RC4|MD5|DES"; then
                echo "[FALHA] Cipher inseguro detectado: $cipher"
                exit 1
            else
                echo "[OK] Cipher seguro: $cipher"
            fi
        fi
    done <<< "$ciphers"
}

# Função para testar OCSP Stapling
test_ocsp_stapling() {
    echo "Testando OCSP Stapling..."
    
    result=$(openssl s_client -connect ${TARGET_HOST}:${TARGET_PORT} \
        -servername ${TARGET_HOST} \
        -status </dev/null 2>&1)
    
    if echo "$result" | grep -q "OCSP response"; then
        echo "[OK] OCSP Stapling está habilitado"
    else
        echo "[AVISO] OCSP Stapling não detectado"
    fi
}

# Função para testar Perfect Forward Secrecy
test_forward_secrecy() {
    echo "Testando Perfect Forward Secrecy..."
    
    result=$(openssl s_client -connect ${TARGET_HOST}:${TARGET_PORT} \
        -servername ${TARGET_HOST} </dev/null 2>&1)
    
    if echo "$result" | grep -q "Server Temp Key"; then
        echo "[OK] Perfect Forward Secrecy está habilitado"
    else
        echo "[FALHA] Perfect Forward Secrecy não detectado"
        exit 1
    fi
}

# Função para testar HTTP Strict Transport Security
test_hsts() {
    echo "Testando HSTS..."
    
    headers=$(curl -sI "https://${TARGET_HOST}")
    
    if echo "$headers" | grep -qi "Strict-Transport-Security"; then
        echo "[OK] HSTS está configurado"
    else
        echo "[FALHA] HSTS não está configurado"
        exit 1
    fi
}

# Função para testar configuração SSL geral usando testssl.sh
test_ssl_configuration() {
    echo "Executando análise completa com testssl.sh..."
    
    if ! command -v testssl.sh &> /dev/null; then
        echo "Instalando testssl.sh..."
        git clone --depth 1 https://github.com/drwetter/testssl.sh.git /tmp/testssl.sh
        chmod +x /tmp/testssl.sh/testssl.sh
        ln -s /tmp/testssl.sh/testssl.sh /usr/local/bin/testssl.sh
    fi
    
    testssl.sh --parallel --quiet --severity HIGH --warnings off \
        --logfile "$REPORT_DIR/testssl.log" \
        ${TARGET_HOST}:${TARGET_PORT}
}

# Execução principal
main() {
    echo "Iniciando testes SSL/TLS..."
    
    check_certificate
    test_ssl_protocols
    test_cipher_suites
    test_ocsp_stapling
    test_forward_secrecy
    test_hsts
    test_ssl_configuration
    
    echo "Testes SSL/TLS concluídos com sucesso!"
    echo "Relatórios disponíveis em: $REPORT_DIR"
}

# Executa os testes
main