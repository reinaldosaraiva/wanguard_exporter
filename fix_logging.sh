#!/bin/bash

echo "🔧 Corrigindo imports de logging..."

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

for file in "${FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "  Processando: $file"
        
        # Remover import de log/slog
        sed -i '' '/"log\/slog"/d' "$file"
        
        # Adicionar import de logging (wrapper compatível)
        if ! grep -q '"github.com/tomvil/wanguard_exporter/logging"' "$file"; then
            # Adicionar após o último import padrão
            sed -i '' '/import (/a\
	"github.com/tomvil/wanguard_exporter/logging"
' "$file"
        fi
        
        # Substituir logger por logging
        sed -i '' 's/logger\./logging\./g' "$file"
        sed -i '' 's/logging\.Infof(/logging.Info(/g' "$file"
        sed -i '' 's/logging\.Errorf(/logging.Error(/g' "$file"
        sed -i '' 's/logging\.Warnf(/logging.Warn(/g' "$file"
        sed -i '' 's/logging\.Debugf(/logging.Debug(/g' "$file"
        sed -i '' 's/logging\.Fatalf(/logging.Fatal(/g' "$file"
        
        # Substituir log por logging (se ainda existir)
        sed -i '' 's/\.Error(/logging.Error(/g' "$file"
        
        echo "  ✅ Concluído: $file"
    fi
done

echo ""
echo "✅ Imports corrigidos!"
echo "📝 Próximo passo: Inicializar logger no main()"
