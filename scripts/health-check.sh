#!/bin/bash
set -e

# Variáveis
LOG_FILE="/var/log/health-check.log"
ALERT_EMAIL="admin@exemplo.com"
SLACK_WEBHOOK="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"

# Função para logging
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE
}

# Função para enviar alertas
send_alert() {
    local message="$1"
    local severity="$2"
    
    # Enviar email
    echo "$message" | mail -s "[$severity] Alerta de Saúde do Sistema" $ALERT_EMAIL
    
    # Enviar para Slack
    curl -X POST -H 'Content-type: application/json' \
        --data "{\"text\":\"[$severity] $message\"}" \
        $SLACK_WEBHOOK
}

# Verificar serviços essenciais
check_services() {
    local services=("apache2" "docker" "jenkins" "prometheus" "fail2ban")
    
    for service in "${services[@]}"; do
        if ! systemctl is-active --quiet $service; then
            log_message "ERRO: Serviço $service não está rodando"
            send_alert "Serviço $service parou" "CRÍTICO"
            return 1
        fi
    done
    
    log_message "Todos os serviços estão rodando"
}

# Verificar uso de recursos
check_resources() {
    # CPU
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}')
    if (( $(echo "$cpu_usage > 80" | bc -l) )); then
        log_message "ALERTA: Uso de CPU alto ($cpu_usage%)"
        send_alert "Uso de CPU alto: $cpu_usage%" "AVISO"
    fi
    
    # Memória
    memory_free=$(free | grep Mem | awk '{print $4/$2 * 100.0}')
    if (( $(echo "$memory_free < 20" | bc -l) )); then
        log_message "ALERTA: Pouca memória livre ($memory_free%)"
        send_alert "Memória baixa: $memory_free% livre" "AVISO"
    fi
    
    # Disco
    disk_usage=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ $disk_usage -gt 80 ]; then
        log_message "ALERTA: Uso de disco alto ($disk_usage%)"
        send_alert "Disco quase cheio: $disk_usage% usado" "AVISO"
    fi
}

# Verificar conectividade
check_connectivity() {
    # Teste de DNS
    if ! dig +short google.com > /dev/null; then
        log_message "ERRO: Resolução DNS falhou"
        send_alert "Falha na resolução DNS" "CRÍTICO"
    fi
    
    # Teste de conexão HTTP
    response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost)
    if [ $response -ne 200 ]; then
        log_message "ERRO: Servidor web retornou status $response"
        send_alert "Servidor web não está respondendo corretamente" "CRÍTICO"
    fi
}

# Verificar logs de segurança
check_security_logs() {
    # Verificar tentativas de login SSH suspeitas
    ssh_attempts=$(grep "Failed password" /var/log/auth.log | wc -l)
    if [ $ssh_attempts -gt 10 ]; then
        log_message "ALERTA: Múltiplas tentativas de login SSH falhas"
        send_alert "Possível ataque de força bruta SSH detectado" "AVISO"
    fi
    
    # Verificar logs do ModSecurity
    if [ -f /var/log/modsecurity/audit.log ]; then
        attacks=$(grep "Access denied" /var/log/modsecurity/audit.log | wc -l)
        if [ $attacks -gt 5 ]; then
            log_message "ALERTA: Múltiplos ataques bloqueados pelo ModSecurity"
            send_alert "Possíveis ataques web detectados" "AVISO"
        fi
    fi
    
    # Verificar logs do fail2ban
    banned_ips=$(fail2ban-client status | grep "Currently banned:" | awk '{print $4}')
    if [ $banned_ips -gt 0 ]; then
        log_message "ALERTA: $banned_ips IPs banidos pelo fail2ban"
        send_alert "$banned_ips IPs foram banidos por atividade suspeita" "AVISO"
    fi
}

# Verificar certificados SSL
check_ssl_certificates() {
    local domains=("localhost")
    for domain in "${domains[@]}"; do
        expiry_date=$(openssl s_client -connect $domain:443 -servername $domain </dev/null 2>/dev/null | openssl x509 -noout -enddate | cut -d= -f2)
        expiry_epoch=$(date -d "$expiry_date" +%s)
        current_epoch=$(date +%s)
        days_until_expiry=$(( ($expiry_epoch - $current_epoch) / 86400 ))
        
        if [ $days_until_expiry -lt 30 ]; then
            log_message "ALERTA: Certificado SSL para $domain expira em $days_until_expiry dias"
            send_alert "Certificado SSL próximo do vencimento para $domain" "AVISO"
        fi
    done
}

# Verificar backup
check_backup() {
    # Verificar último backup
    latest_backup=$(find /opt/backups -type f -name "*.tar.gz" -mtime -1 | wc -l)
    if [ $latest_backup -eq 0 ]; then
        log_message "ERRO: Nenhum backup encontrado nas últimas 24 horas"
        send_alert "Backup diário não foi realizado" "CRÍTICO"
    fi
    
    # Verificar espaço disponível para backups
    backup_space=$(df -h /opt/backups | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ $(echo "$backup_space < 10" | bc) -eq 1 ]; then
        log_message "ALERTA: Pouco espaço disponível para backups"
        send_alert "Espaço para backup está baixo" "AVISO"
    fi
}

# Verificar containers Docker
check_containers() {
    # Verificar containers parados
    stopped_containers=$(docker ps -q --filter "status=exited" | wc -l)
    if [ $stopped_containers -gt 0 ]; then
        log_message "ALERTA: $stopped_containers containers parados"
        send_alert "$stopped_containers containers Docker estão parados" "AVISO"
    fi
    
    # Verificar containers com reinícios frequentes
    problematic_containers=$(docker ps -a --format "{{.Names}} {{.Status}}" | grep "Restarting" | wc -l)
    if [ $problematic_containers -gt 0 ]; then
        log_message "ERRO: $problematic_containers containers com problemas de reinício"
        send_alert "Containers Docker estão reiniciando constantemente" "CRÍTICO"
    fi
}

# Função principal
main() {
    log_message "Iniciando verificação de saúde do sistema..."
    
    check_services
    check_resources
    check_connectivity
    check_security_logs
    check_ssl_certificates
    check_backup
    check_containers
    
    log_message "Verificação de saúde concluída"
}

# Executar verificações
main