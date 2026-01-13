#!/bin/bash

# Script para migrar de prometheus/common/log para slog

echo "🔄 Migrando de prometheus/common/log para slog..."

# Lista de arquivos a processar
FILES=(
    "wanguard_exporter.go"
    "collectors/anomalies_collector.go"
    "collectors/actions_collector.go"
    "collectors/sensors_collector.go"
    "collectors/announcements_collector.go"
    "collectors/collector_test.go"
    "collectors/traffic_collector.go"
    "collectors/components_collector.go"
    "collectors/helpers.go"
    "collectors/firewall_rules_collector.go"
    "collectors/license_collector.go"
)

# Processar cada arquivo
for file in "${FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "  Processando: $file"
        
        # Remover import de prometheus/common/log
        sed -i '' '/"github.com\/prometheus\/common\/log"/d' "$file"
        
        # Adicionar import de log/slog se ainda não existe
        if ! grep -q '"log/slog"' "$file"; then
            # Encontrar onde adicionar o import (após o primeiro import)
            sed -i '' '/import (/a\
    "log/slog"
' "$file"
        fi
        
        # Substituir chamadas de função
        # log.Infof -> logger.Info
        sed -i '' 's/log\.Infof(/logger.Info(/g' "$file"
        sed -i '' 's/log\.Errorf(/logger.Error(/g' "$file"
        sed -i '' 's/log\.Warnf(/logger.Warn(/g' "$file"
        sed -i '' 's/log\.Debugf(/logger.Debug(/g' "$file"
        sed -i '' 's/log\.Debug(/logger.Debug(/g' "$file"
        sed -i '' 's/log\.Fatalf(/logger.Error(/g' "$file"
        sed -i '' 's/log\.Fatal(/logger.Error(/g' "$file"
        
        echo "  ✅ Concluído: $file"
    else
        echo "  ⚠️  Arquivo não encontrado: $file"
    fi
done

echo ""
echo "✅ Migração concluída!"
echo "📝 Próximos passos:"
echo "  1. Adicionar variável global 'logger' em cada arquivo"
echo "  2. Ajustar chamadas de função (formato de args)"
echo "  3. Compilar para verificar erros"
echo "  4. Executar testes"
