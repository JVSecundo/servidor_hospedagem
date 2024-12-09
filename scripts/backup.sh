#!/bin/bash
set -e

# Configurações
BACKUP_DIR="/opt/backups/$(date +%Y%m%d)"
DOCKER_VOLUMES="/var/lib/docker/volumes"
CONFIG_DIR="/opt/docker"
LOG_DIR="/var/log"
RETENTION_DAYS=7

# Criar diretório de backup
mkdir -p $BACKUP_DIR

# Função para backup dos volumes Docker
backup_docker_volumes() {
    echo "Iniciando backup dos volumes Docker..."
    
    # Listar todos os volumes
    volumes=$(docker volume ls -q)
    
    for volume in $volumes; do
        echo "Fazendo backup do volume: $volume"
        docker run --rm \
            -v $volume:/source:ro \
            -v $BACKUP_DIR:/backup \
            alpine tar czf /backup/$volume.tar.gz -C /source .
    done
}

# Função para backup das configurações
backup_configs() {
    echo "Iniciando backup das configurações..."
    tar czf $BACKUP_DIR/configs.tar.gz $CONFIG_DIR
}

# Função para backup dos logs
backup_logs() {
    echo "Iniciando backup dos logs..."
    tar czf $BACKUP_DIR/logs.tar.gz $LOG_DIR
}

# Função para backup do Jenkins
backup_jenkins() {
    echo "Iniciando backup do Jenkins..."
    JENKINS_HOME="/var/lib/jenkins"
    if [ -d "$JENKINS_HOME" ]; then
        tar czf $BACKUP_DIR/jenkins.tar.gz $JENKINS_HOME
    fi
}

# Função para backup do banco de dados (se existir)
backup_database() {
    echo "Iniciando backup do banco de dados..."
    if docker ps | grep -q "postgres"; then
        docker exec postgres pg_dump -U postgres > $BACKUP_DIR/database.sql
    fi
}

# Função para limpar backups antigos
cleanup_old_backups() {
    echo "Limpando backups antigos..."
    find /opt/backups -type d -mtime +$RETENTION_DAYS -exec rm -rf {} \;
}

# Função para verificar espaço em disco
check_disk_space() {
    echo "Verificando espaço em disco..."
    available_space=$(df -h /opt/backups | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ $(echo "$available_space < 10" | bc) -eq 1 ]; then
        echo "ERRO: Espaço insuficiente em disco"
        exit 1
    fi
}

# Execução principal
main() {
    echo "Iniciando processo de backup..."
    
    check_disk_space
    backup_docker_volumes
    backup_configs
    backup_logs
    backup_jenkins
    backup_database
    cleanup_old_backups
    
    echo "Backup concluído com sucesso!"
    echo "Arquivos de backup disponíveis em: $BACKUP_DIR"
}

main