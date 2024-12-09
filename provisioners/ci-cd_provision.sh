#!/bin/bash
set -e

echo "Iniciando configuração do ambiente CI/CD..."

# Variáveis
JENKINS_HOME="/opt/jenkins"
SONAR_HOME="/opt/sonarqube"
DOCKER_COMPOSE_VERSION="2.20.2"

# Atualizar sistema
apt-get update
apt-get upgrade -y

# Instalar dependências
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    git \
    openjdk-11-jdk \
    maven \
    nodejs \
    npm

# Instalar Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# Instalar Docker Compose
curl -L "https://github.com/docker/compose/releases/download/v${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Configurar Jenkins
mkdir -p $JENKINS_HOME
wget -q -O - https://pkg.jenkins.io/debian-stable/jenkins.io.key | apt-key add -
sh -c 'echo deb https://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list'
apt-get update
apt-get install -y jenkins

# Configurar SonarQube
mkdir -p $SONAR_HOME
wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-9.9.0.65466.zip
unzip sonarqube-9.9.0.65466.zip -d /opt
mv /opt/sonarqube-9.9.0.65466/* $SONAR_HOME

# Configurar permissões
chown -R jenkins:jenkins $JENKINS_HOME
chown -R sonar:sonar $SONAR_HOME

# Instalar plugins Jenkins
JENKINS_CLI="/usr/share/jenkins/jenkins-cli.jar"
wget http://localhost:8080/jnlpJars/jenkins-cli.jar -O $JENKINS_CLI

# Lista de plugins essenciais
JENKINS_PLUGINS=(
    "git"
    "workflow-aggregator"
    "docker-workflow"
    "blueocean"
    "sonar"
    "jacoco"
    "junit"
    "credentials"
    "ssh"
)

# Instalar plugins
for plugin in "${JENKINS_PLUGINS[@]}"; do
    java -jar $JENKINS_CLI -s http://localhost:8080/ install-plugin $plugin
done

# Configurar integração com Git
git config --global user.name "Jenkins CI"
git config --global user.email "jenkins@localhost"

# Configurar servidor de builds
cat > /etc/security/limits.d/30-jenkins.conf << EOF
jenkins soft nofile 65536
jenkins hard nofile 65536
jenkins soft nproc 32768
jenkins hard nproc 32768
EOF

# Configurar logs
mkdir -p /var/log/jenkins
chown jenkins:jenkins /var/log/jenkins

# Configurar rotação de logs
cat > /etc/logrotate.d/jenkins << EOF
/var/log/jenkins/*.log {
    rotate 7
    daily
    compress
    missingok
    notifempty
}
EOF

# Iniciar serviços
systemctl enable jenkins
systemctl start jenkins
systemctl enable docker
systemctl start docker

# Verificar instalações
echo "Verificando instalações..."
java -version
docker --version
docker-compose --version
systemctl status jenkins --no-pager

echo "Configuração do ambiente CI/CD concluída!"

# Exibir informações importantes
echo "Jenkins URL: http://localhost:8080"
echo "SonarQube URL: http://localhost:9000"
echo "Senha inicial Jenkins:"
cat /var/lib/jenkins/secrets/initialAdminPassword