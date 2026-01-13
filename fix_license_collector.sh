#!/bin/bash

echo "🔧 Corrigindo license_collector.go..."

# Corrigir chamada de logging.Error recursiva (com quebra de linha)
sed -i '' '78,86s/logging\.Error(/logging.Error("Error: %v", err)/' collectors/license_collector.go

echo "✅ Concluído!"
