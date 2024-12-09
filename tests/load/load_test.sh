#!/bin/bash
set -e

# Variáveis
TARGET_URL="http://localhost"
REPORT_DIR="/var/log/load-tests/$(date +%Y%m%d)"
mkdir -p $REPORT_DIR

# Função para teste de carga básico
basic_load_test() {
    echo "Executando teste de carga básico..."
    
    # Test com 100 usuários simultâneos por 60 segundos
    ab -n 1000 -c 100 -t 60 \
       -H "Accept-Encoding: gzip, deflate" \
       -g "$REPORT_DIR/basic_load.csv" \
       "$TARGET_URL/" > "$REPORT_DIR/basic_load.txt"
    
    # Analisar resultados
    requests_per_second=$(grep "Requests per second" "$REPORT_DIR/basic_load.txt" | awk '{print $4}')
    mean_time=$(grep "Mean" "$REPORT_DIR/basic_load.txt" | awk '{print $4}')
    failed_requests=$(grep "Failed requests" "$REPORT_DIR/basic_load.txt" | awk '{print $3}')
    
    echo "Resultados do teste básico:"
    echo "- Requisições por segundo: $requests_per_second"
    echo "- Tempo médio de resposta: ${mean_time}ms"
    echo "- Requisições falhas: $failed_requests"
}

# Função para teste de estresse
stress_test() {
    echo "Executando teste de estresse..."
    
    # Teste com aumento gradual de carga
    for users in 50 100 200 300 400 500; do
        echo "Testando com $users usuários simultâneos..."
        siege -c $users -t 30S \
              -v -f urls.txt \
              --log="$REPORT_DIR/stress_${users}.log"
        
        # Esperar entre os testes
        sleep 10
    done
}

# Função para teste de durabilidade
endurance_test() {
    echo "Executando teste de durabilidade..."
    
    # Teste de 1 hora com carga moderada
    siege -c 50 -t 1H \
          -v -f urls.txt \
          --log="$REPORT_DIR/endurance.log"
}

# Função para testar limites de tamanho
size_limit_test() {
    echo "Testando limites de tamanho de requisição..."
    
    # Criar arquivos de teste de diferentes tamanhos
    dd if=/dev/zero of=/tmp/test_1mb.file bs=1M count=1
    dd if=/dev/zero of=/tmp/test_5mb.file bs=1M count=5
    dd if=/dev/zero of=/tmp/test_10mb.file bs=1M count=10
    
    # Testar upload dos arquivos
    for file in /tmp/test_*.file; do
        size=$(ls -lh $file | awk '{print $5}')
        echo "Testando upload de arquivo de $size..."
        
        curl -s -o /dev/null -w "%{http_code}\n" \
             -F "file=@$file" \
             "$TARGET_URL/upload"
    done
    
    # Limpar arquivos temporários
    rm /tmp/test_*.file
}

# Função para gerar relatório
generate_report() {
    echo "Gerando relatório de testes..."
    
    cat > "$REPORT_DIR/report.html" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Relatório de Testes de Carga</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <h1>Relatório de Testes de Carga</h1>
    <h2>Data: $(date)</h2>
    
    <h3>Resultados do Teste Básico</h3>
    <pre>$(cat "$REPORT_DIR/basic_load.txt")</pre>
    
    <h3>Resultados do Teste de Estresse</h3>
    <table>
        <tr>
            <th>Usuários</th>
            <th>Disponibilidade</th>
            <th>Tempo de Resposta</th>
        </tr>
EOF
    
    for log in "$REPORT_DIR"/stress_*.log; do
        users=$(echo $log | grep -o '[0-9]\+')
        availability=$(grep "Availability:" $log | awk '{print $2}')
        response_time=$(grep "Response time:" $log | awk '{print $3}')
        
        echo "<tr><td>$users</td><td>$availability</td><td>$response_time</td></tr>" >> "$REPORT_DIR/report.html"
    done
    
    cat >> "$REPORT_DIR/report.html" << EOF
    </table>
</body>
</html>
EOF
}

# Execução principal
main() {
    echo "Iniciando testes de carga..."
    
    # Verificar dependências
    command -v ab >/dev/null 2>&1 || { echo "apache2-utils não está instalado"; exit 1; }
    command -v siege >/dev/null 2>&1 || { echo "siege não está instalado"; exit 1; }
    
    # Criar arquivo de URLs para teste
    cat > urls.txt << EOF
http://localhost/
http://localhost/about
http://localhost/contact
EOF
    
    # Executar testes
    basic_load_test
    stress_test
    endurance_test
    size_limit_test
    
    # Gerar relatório
    generate_report
    
    echo "Testes concluídos! Relatório disponível em: $REPORT_DIR/report.html"
}

# Executar testes
main