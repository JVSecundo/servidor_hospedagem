#!/bin/bash
set -e

echo "Iniciando configuração do ambiente..."

# Cores para output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Função para exibir mensagens de progresso
log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

# Função para exibir erros
error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Verifica se está rodando como root
if [ "$EUID" -ne 0 ]; then 
    error "Este script precisa ser executado como root (sudo)"
fi

# Verificar sistema operacional
if ! grep -q "Ubuntu" /etc/os-release; then
    error "Este script foi projetado para Ubuntu. Sistema atual não suportado."
fi

# Criar estrutura de diretórios
log "Criando estrutura de diretórios..."
directories=(
    "/var/log/apache2"
    "/var/log/jenkins"
    "/var/log/security"
    "/var/log/monitoring"
    "/opt/backups"
    "/var/log/security-tests"
    "/opt/applications"
    "/etc/ssl/private"
    "/var/log/modsecurity"
    "/opt/monitoring/prometheus/data"
    "/opt/monitoring/grafana/data"
    "/opt/ci-cd/jenkins"
    "/opt/ci-cd/sonarqube"
)

for dir in "${directories[@]}"; do
    mkdir -p $dir
    chmod 755 $dir
    log "Diretório criado: $dir"
done

# Instalar dependências
log "Instalando dependências necessárias..."
apt-get update || error "Falha ao atualizar repositórios"
apt-get install -y \
    apache2-utils \
    siege \
    curl \
    jq \
    xmlstarlet \
    git \
    unzip \
    net-tools \
    ufw \
    fail2ban \
    auditd \
    openssl \
    prometheus \
    grafana || error "Falha ao instalar dependências"

# Configurar permissões dos scripts
log "Configurando permissões dos scripts..."
find . -type f -name "*.sh" -exec chmod +x {} \;

# Configurar variáveis de ambiente
log "Configurando variáveis de ambiente..."
cat > /etc/environment << EOF
DOCKER_REGISTRY=localhost:5000
SONAR_HOST=http://localhost:9000
JENKINS_URL=http://localhost:8080
EOF

# Configurar firewall
log "Configurando firewall..."
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 8080/tcp
ufw allow 9000/tcp
ufw allow 3000/tcp
echo "y" | ufw enable

# Gerar certificados SSL auto-assinados
log "Gerando certificados SSL..."
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/ssl/private/server.key \
    -out /etc/ssl/certs/server.crt \
    -subj "/C=BR/ST=State/L=City/O=Organization/CN=localhost"

# Configurar auditd
log "Configurando auditd..."
systemctl enable auditd
systemctl start auditd

# Configurar fail2ban
log "Configurando fail2ban..."
cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
systemctl enable fail2ban
systemctl start fail2ban

# Verificar instalação do Docker
log "Verificando Docker..."
if ! command -v docker &> /dev/null; then
    log "Instalando Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    usermod -aG docker $SUDO_USER
fi

# Verificar Docker Compose
log "Verificando Docker Compose..."
if ! command -v docker-compose &> /dev/null; then
    log "Instalando Docker Compose..."
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
fi

# Pull das imagens necessárias
log "Baixando imagens Docker..."
docker pull httpd:latest
docker pull jenkins/jenkins:lts
docker pull sonarqube:latest
docker pull prom/prometheus:latest
docker pull grafana/grafana:latest

# Criar rede Docker
log "Criando rede Docker..."
docker network create web-secure-network || true

# Iniciar containers básicos
log "Iniciando containers..."
docker-compose up -d

# Verificar instalação
log "Verificando instalação..."
services=("docker" "fail2ban" "auditd" "ufw")
for service in "${services[@]}"; do
    if ! systemctl is-active --quiet $service; then
        error "Serviço $service não está rodando"
    fi
done

# Criar arquivo de status
log "Criando arquivo de status..."
cat > ./installation_status.txt << EOF
Instalação concluída em: $(date)
Hostname: $(hostname)
IP: $(hostname -I | awk '{print $1}')
Services:
$(systemctl status docker fail2ban auditd ufw | grep Active)
EOF

log "Configuração concluída com sucesso!"
log "Verifique o arquivo installation_status.txt para mais detalhes"
log "Execute 'docker-compose ps' para verificar o status dos containers"

# Instruções finais
echo -e "\n${GREEN}Próximos passos:${NC}"
echo "1. Configure as credenciais do Jenkins em http://localhost:8080"
echo "2. Configure o SonarQube em http://localhost:9000"
echo "3. Acesse o Grafana em http://localhost:3000"
echo "4. Verifique os logs em /var/log/"
echo "5. Execute os testes de segurança em tests/security/"