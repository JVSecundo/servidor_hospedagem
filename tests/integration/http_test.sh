#!/bin/bash
set -e

echo "Iniciando testes de integração HTTP..."

# Variáveis
TARGET_HOST="localhost"
TARGET_PORT="80"
TEST_ENDPOINTS=(
    "/"
    "/health"
    "/metrics"
)
REPORT_DIR="/var/log/integration-tests/http/$(date +%Y%m%d)"
mkdir -p $REPORT_DIR

# Função para testar disponibilidade básica
test_basic_availability() {
    echo "Verificando disponibilidade básica do servidor..."
    
    response=$(curl -s -o /dev/null -w "%{http_code}" "http://${TARGET_HOST}:${TARGET_PORT}/")
    
    if [ "$response" == "200" ]; then
        echo "[OK] Servidor está respondendo corretamente"
    else
        echo "[FALHA] Servidor não está respondendo corretamente (Status: $response)"
        exit 1
    fi
}

# Função para testar endpoints específicos
test_endpoints() {
    echo "Testando endpoints específicos..."
    
    for endpoint in "${TEST_ENDPOINTS[@]}"; do
        response=$(curl -s -o /dev/null -w "%{http_code}" "http://${TARGET_HOST}:${TARGET_PORT}${endpoint}")
        
        echo "Testando $endpoint..."
        case $response in
            200)
                echo "[OK] Endpoint $endpoint está funcionando corretamente"
                ;;
            301|302)
                echo "[OK] Endpoint $endpoint redirecionou corretamente"
                ;;
            404)
                echo "[FALHA] Endpoint $endpoint não encontrado"
                exit 1
                ;;
            *)
                echo "[FALHA] Endpoint $endpoint retornou status inesperado: $response"
                exit 1
                ;;
        esac
    done
}

# Função para testar headers de resposta
test_response_headers() {
    echo "Verificando headers de resposta..."
    
    headers=$(curl -s -I "http://${TARGET_HOST}:${TARGET_PORT}/")
    
    # Verificar headers obrigatórios
    required_headers=(
        "Server:"
        "Content-Type:"
        "X-Content-Type-Options:"
        "X-Frame-Options:"
    )
    
    for header in "${required_headers[@]}"; do
        if echo "$headers" | grep -q "$header"; then
            echo "[OK] Header $header presente"
        else
            echo "[FALHA] Header $header não encontrado"
            exit 1
        fi
    done
}

# Função para testar performance
test_performance() {
    echo "Executando testes de performance..."
    
    # Teste com Apache Benchmark
    ab -n 1000 -c 10 "http://${TARGET_HOST}:${TARGET_PORT}/" > "$REPORT_DIR/performance.txt"
    
    # Verificar tempos de resposta
    avg_time=$(grep "Time per request" "$REPORT_DIR/performance.txt" | head -1 | awk '{print $4}')
    if (( $(echo "$avg_time > 500" | bc -l) )); then
        echo "[FALHA] Tempo médio de resposta muito alto: ${avg_time}ms"
        exit 1
    else
        echo "[OK] Tempo médio de resposta aceitável: ${avg_time}ms"
    fi
}

# Função para testar limites de tamanho
test_size_limits() {
    echo "Testando limites de tamanho de requisição..."
    
    # Criar payload grande
    dd if=/dev/zero of=/tmp/large_file bs=1M count=10
    
    # Tentar enviar arquivo grande
    response=$(curl -s -o /dev/null -w "%{http_code}" -F "file=@/tmp/large_file" "http://${TARGET_HOST}:${TARGET_PORT}/upload")
    
    if [ "$response" == "413" ]; then
        echo "[OK] Limite de tamanho de upload funcionando corretamente"
    else
        echo "[FALHA] Limite de tamanho de upload não está funcionando (Status: $response)"
        exit 1
    fi
    
    rm /tmp/large_file
}

# Função para testar rate limiting
test_rate_limiting() {
    echo "Testando rate limiting..."
    
    count=0
    for i in {1..50}; do
        response=$(curl -s -o /dev/null -w "%{http_code}" "http://${TARGET_HOST}:${TARGET_PORT}/")
        if [ "$response" == "429" ]; then
            echo "[OK] Rate limiting ativo após $i requisições"
            break
        fi
        ((count++))
    done
    
    if [ $count -eq 50 ]; then
        echo "[FALHA] Rate limiting não detectado após 50 requisições"
        exit 1
    fi
}

# Execução principal
main() {
    echo "Iniciando bateria de testes HTTP..."
    
    test_basic_availability
    test_endpoints
    test_response_headers
    test_performance
    test_size_limits
    test_rate_limiting
    
    echo "Testes HTTP concluídos com sucesso!"
    echo "Relatórios disponíveis em: $REPORT_DIR"
}

# Executa os testes
main