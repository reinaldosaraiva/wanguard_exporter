# ⚠️ Deprecation Issue: prometheus/common/log

**Data:** 2026-01-13
**Status:** Resolvendo

---

## 🚨 Problema Detectado

Ao tentar atualizar para `prometheus/common` v0.66.1+, o pacote `github.com/prometheus/common/log` foi removido.

**Erro:**
```
github.com/tomvil/wanguard_exporter imports
	github.com/prometheus/common/log: cannot find module providing package github.com/prometheus/common/log
```

---

## 📋 Arquivos Afetados

Total de 10 arquivos usam `github.com/prometheus/common/log`:

1. `wanguard_exporter.go`
2. `collectors/anomalies_collector.go`
3. `collectors/actions_collector.go`
4. `collectors/sensors_collector.go`
5. `collectors/announcements_collector.go`
6. `collectors/collector_test.go`
7. `collectors/traffic_collector.go`
8. `collectors/components_collector.go`
9. `collectors/helpers.go`
10. `collectors/firewall_rules_collector.go`
11. `collectors/license_collector.go`

---

## 🔄 Plano de Migração

### Opção 1: Migrar para log padrão do Go (log)

**Vantagens:**
- ✅ Simples e direto
- ✅ Sem dependências adicionais
- ✅ Compatível com todas as versões do Go

**Desvantagens:**
- ❌ Não estruturado (texto simples)
- ❌ Sem suporte para levels (apenas Println, Fatal, etc.)
- ❌ Less flexible than slog

### Opção 2: Migrar para slog (Go 1.21+)

**Vantagens:**
- ✅ Structured logging
- ✅ Suporte para levels
- ✅ Integrado com stdlib do Go 1.21+
- ✅ Padrão moderno

**Desvantagens:**
- ❌ Requer Go 1.21+ (já estamos usando 1.24.11, então ok)
- ❌ Pequeno ajuste na sintaxe

### Opção 3: Manter versão antiga do prometheus/common

**Vantagens:**
- ✅ Sem mudanças de código

**Desvantagens:**
- ❌ Perde atualizações de segurança
- ❌ Perde correções de bugs
- ❌ Contra-indicado por long prazo

---

## ✅ Decisão: Migrar para slog (Go 1.21+)

**Justificativa:**
1. Já estamos usando Go 1.24.11
2. slog é o padrão moderno de logging em Go
3. Suporta structured logging
4. Permite melhores observabilidade
5. Futuro-proof

---

## 📝 Mudanças Necessárias

### 1. Remover Import
```go
// REMOVER
import "github.com/prometheus/common/log"
```

### 2. Adicionar Import slog
```go
// ADICIONAR
import "log/slog"
```

### 3. Criar Logger Global (compatibilidade)
```go
// Criar logger global para compatibilidade
var logger = slog.New(slog.NewTextHandler(os.Stdout, &slog.HandlerOptions{
    Level: slog.LevelInfo,
}))
```

### 4. Substituir Chamadas de Função

#### De:
```go
log.Infof("message")
log.Errorf("error: %v", err)
log.Warnf("warning")
log.Debug("debug message")
log.Fatal("fatal error")
```

#### Para:
```go
logger.Info("message")
logger.Error("error", "error", err)
logger.Warn("warning")
logger.Debug("debug message")
logger.Error("fatal error", "fatal", true)
os.Exit(1)
```

---

## 🔧 Script de Migração Automática

Vou criar um script para fazer a migração automaticamente em todos os arquivos afetados.

---

**Próxima Ação:** Executar migração para slog em todos os arquivos afetados.
