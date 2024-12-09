FROM httpd:2.4-alpine

# Adicionar usuário não-root
RUN adduser -D -H -u 1000 webuser

# Instalar dependências essenciais
RUN apk add --no-cache \
    mod_security \
    curl \
    openssl \
    ca-certificates \
    tzdata

# Copiar arquivos de configuração
COPY httpd.conf /usr/local/apache2/conf/httpd.conf
COPY security.conf /usr/local/apache2/conf/extra/security.conf
COPY modsecurity.conf /usr/local/apache2/conf/extra/modsecurity.conf

# Copiar conteúdo da aplicação
COPY ./app/ /usr/local/apache2/htdocs/

# Configurar permissões
RUN chown -R webuser:webuser /usr/local/apache2/htdocs/ && \
    chmod -R 755 /usr/local/apache2/htdocs/

# Expor porta
EXPOSE 80

# Mudar para usuário não-root
USER webuser

# Healthcheck
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost/ || exit 1

CMD ["httpd-foreground"]