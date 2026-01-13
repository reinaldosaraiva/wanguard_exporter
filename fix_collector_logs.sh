#!/bin/bash

echo "🔧 Corrigindo chamadas de log nos collectors..."

FILES=(
    "collectors/anomalies_collector.go"
    "collectors/actions_collector.go"
    "collectors/sensors_collector.go"
    "collectors/announcements_collector.go"
    "collectors/traffic_collector.go"
    "collectors/components_collector.go"
    "collectors/helpers.go"
    "collectors/firewall_rules_collector.go"
    "collectors/license_collector.go"
)

for file in "${FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "  Processando: $file"
        
        # Adicionar import de logging se não existe
        if ! grep -q '"github.com/tomvil/wanguard_exporter/logging"' "$file"; then
            # Encontrar a linha do primeiro import e adicionar após ela
            sed -i '' '/^import (/a\
	"github.com/tomvil/wanguard_exporter/logging"
' "$file"
        fi
        
        # Substituir log.Errorln por logging.Error
        sed -i '' 's/log\.Errorln(/logging.Error(/g' "$file"
        sed -i '' 's/logging\.Errorln(/logging.Error(/g' "$file"
        
        # Substituir errlogging.Error por err (provável erro de digitação)
        sed -i '' 's/errlogging\.Error(/logging.Error(/g' "$file"
        
        echo "  ✅ Concluído: $file"
    fi
done

echo ""
echo "✅ Chamadas de log corrigidas!"
