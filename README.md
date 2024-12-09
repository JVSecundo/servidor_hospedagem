# Servidor Web Seguro com CI/CD

## Sobre o Projeto
Este projeto implementa um servidor web seguro com pipeline de CI/CD integrado, usando Docker para containerização e práticas avançadas de hardening de segurança. O ambiente é projetado para permitir que desenvolvedores implantem suas aplicações de forma segura e automatizada.

## Requisitos

### Windows
- Windows 10/11
- VirtualBox 6.1+
- Vagrant 2.2.19+
- Git
- Docker Desktop (opcional)

### Linux
- Ubuntu 20.04 LTS ou superior
- Docker 24.0.5+
- Docker Compose
- Git

## Estrutura do Projeto
```
servidor-web-seguro/
├── DockerWeb/                      # Configurações do servidor web
│   ├── Dockerfile                  # Configuração do container
│   ├── httpd.conf                  # Configuração Apache
│   ├── security.conf               # Configurações de segurança
│   ├── modsecurity.conf           # Regras ModSecurity
│   └── app/                       # Aplicação web
├── provisioners/                   # Scripts de provisionamento
│   ├── ci-cd_provision.sh         # Configuração CI/CD
│   ├── hardening.sh               # Script de hardening
│   └── monitoring_provision.sh     # Configuração monitoramento
├── tests/                         # Testes automatizados
│   ├── security/                  # Testes de segurança
│   │   ├── pentest.sh            # Testes de penetração
│   │   └── compliance.sh         # Verificação de conformidade
│   ├── integration/              # Testes de integração
│   │   ├── http_test.sh         # Testes HTTP
│   │   └── ssl_test.sh          # Testes SSL
│   └── load/                     # Testes de carga
│       └── load_test.sh         # Teste de carga
├── pipeline/                      # Configurações do pipeline
│   └── security-checks/          # Scripts de verificação
├── scripts/                      # Scripts utilitários
├── monitoring/                   # Configs de monitoramento
├── configs/                      # Outras configurações
│   ├── nginx/                   # Configurações do Nginx
│   └── ssl/                     # Certificados SSL
├── init.sh                      # Script de inicialização
├── setup.sh                     # Script de setup
├── Vagrantfile                  # Configuração da VM
└── README.md                    # Este arquivo
```

## Instalação

### Windows (usando Vagrant)

1. **Preparação do Ambiente**
```powershell
git clone [URL_DO_REPOSITORIO]
cd servidor-web-seguro
```

2. **Iniciar Ambiente Virtualizado**
```powershell
vagrant up
vagrant ssh
```

3. **Dentro da VM**
```bash
cd /opt/docker
sudo ./init.sh
```

### Linux (instalação direta)

1. **Preparação**
```bash
git clone [URL_DO_REPOSITORIO]
cd servidor-web-seguro
chmod +x init.sh setup.sh
```

2. **Instalação**
```bash
sudo ./setup.sh
```

## Configuração dos Serviços

### Apache com ModSecurity
1. **Configurar ModSecurity**
```bash
cd DockerWeb
docker build -t web-secure .
docker-compose up -d
```

### Jenkins
1. **Acessar Jenkins**
- Windows: http://localhost:8081
- Linux: http://localhost:8080

2. **Configuração Inicial**
```bash
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

## Testes

### Testes de Segurança
```bash
cd tests/security
./pentest.sh
./compliance.sh
```

### Testes de Carga
```bash
cd tests/load
./load_test.sh
```

### Testes de Integração
```bash
cd tests/integration
./http_test.sh
./ssl_test.sh
```

## Monitoramento

### Grafana
- Acesso: http://localhost:3000
- Usuário: admin
- Senha inicial: admin

### Prometheus
- Acesso: http://localhost:9090

## Manutenção

### Backup
```bash
./scripts/backup.sh
```

### Verificação de Saúde
```bash
./scripts/health-check.sh
```

### Atualização do Sistema
```bash
./scripts/update.sh
```

## Segurança

### Features Implementadas
- WAF (ModSecurity)
- Headers de Segurança HTTP
- SSL/TLS
- Fail2ban
- Auditoria de Logs
- Monitoramento em Tempo Real

### Testes de Segurança Automatizados
- Análise de Vulnerabilidades
- Verificação de Conformidade
- Testes de Penetração
- Scan de Portas

## Solução de Problemas

### Windows
1. **Problemas com Vagrant**
```powershell
vagrant destroy
vagrant up
```

2. **Problemas de Rede**
```powershell
netsh winsock reset
```

### Linux
1. **Problemas com Docker**
```bash
sudo systemctl restart docker
docker-compose down
docker-compose up -d
```

2. **Logs**
```bash
sudo tail -f /var/log/syslog
docker logs web
```

## Contribuindo
1. Fork o projeto
2. Crie uma branch: `git checkout -b feature/nova-feature`
3. Commit suas mudanças: `git commit -m 'Adiciona nova feature'`
4. Push para a branch: `git push origin feature/nova-feature`
5. Abra um Pull Request

## Suporte
- Issues: GitHub Issues
- Email: suporte@exemplo.com
- Documentação: [LINK_DOCUMENTACAO]

## Licença
MIT License - veja o arquivo LICENSE para detalhes