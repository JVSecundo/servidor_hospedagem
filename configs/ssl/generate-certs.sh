#!/bin/bash
set -e

echo "Gerando certificados SSL..."

# Variáveis
SSL_DIR="/etc/ssl/private"
DAYS_VALID=365
KEY_SIZE=2048
COUNTRY="BR"
STATE="Sao Paulo"
LOCALITY="Sao Paulo"
ORGANIZATION="Exemplo Org"
COMMON_NAME="localhost"

# Criar diretório se não existir
mkdir -p $SSL_DIR

# Gerar chave privada
openssl genrsa -out $SSL_DIR/server.key $KEY_SIZE

# Gerar CSR (Certificate Signing Request)
openssl req -new -key $SSL_DIR/server.key -out $SSL_DIR/server.csr -subj "/C=$COUNTRY/ST=$STATE/L=$LOCALITY/O=$ORGANIZATION/CN=$COMMON_NAME"

# Gerar certificado auto-assinado
openssl x509 -req -days $DAYS_VALID \
    -in $SSL_DIR/server.csr \
    -signkey $SSL_DIR/server.key \
    -out $SSL_DIR/server.crt

# Gerar parâmetros Diffie-Hellman
openssl dhparam -out $SSL_DIR/dhparam.pem 2048

# Configurar permissões
chmod 600 $SSL_DIR/server.key
chmod 644 $SSL_DIR/server.crt
chmod 644 $SSL_DIR/dhparam.pem

echo "Certificados gerados com sucesso!"
echo "Localização dos arquivos:"
echo "Chave privada: $SSL_DIR/server.key"
echo "Certificado: $SSL_DIR/server.crt"
echo "Parâmetros DH: $SSL_DIR/dhparam.pem"