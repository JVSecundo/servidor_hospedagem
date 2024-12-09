#!/bin/bash
set -e

echo "Iniciando setup do ambiente..."

# Verificar se todos os arquivos necessários existem
files_to_check=(
    "DockerWeb/Dockerfile"
    "DockerWeb/httpd.conf"
    "DockerWeb/security.conf"
    "DockerWeb/modsecurity.conf"
    "DockerWeb/app/index.html"
    "provisioners/ci-cd_provision.sh"
    "provisioners/hardening.sh"
    "provisioners/monitoring_provision.sh"
    "Vagrantfile"
    "init.sh"
)

for file in "${files_to_check[@]}"; do
    if [ ! -f "$file" ]; then
        echo "ERRO: Arquivo $file não encontrado!"
        exit 1
    fi
done

# Configurar permissões
echo "Configurando permissões..."
chmod +x init.sh
chmod +x provisioners/*.sh
find tests/ -type f -name "*.sh" -exec chmod +x {} \;

# Executar inicialização
echo "Executando script de inicialização..."
sudo ./init.sh

# Iniciar Vagrant
echo "Iniciando ambiente Vagrant..."
vagrant up

# Verificar status
echo "Verificando status dos serviços..."
vagrant status

echo "Setup concluído! Execute 'vagrant ssh' para acessar o ambiente."