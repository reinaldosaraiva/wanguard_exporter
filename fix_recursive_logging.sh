#!/bin/bash

echo "🔧 Corrigindo chamadas recursivas de logging.Error..."

FILES=(
    "collectors/actions_collector.go"
    "collectors/sensors_collector.go"
    "collectors/announcements_collector.go"
    "collectors/traffic_collector.go"
    "collectors/components_collector.go"
    "collectors/firewall_rules_collector.go"
)

for file in "${FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "  Processando: $file"
        
        # Substituir logging.Error(logging.Error()) por logging.Error("error message: %v", err)
        # Isso requer análise de cada caso, então vamos fazer uma correção genérica
        sed -i '' 's/logging\.Error(logging\.Error())/logging.Error("Error: %v", err)/g' "$file"
        
        echo "  ✅ Concluído: $file"
    fi
done

echo ""
echo "✅ Chamadas recursivas corrigidas!"
