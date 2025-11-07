# Boss Tracker - Integração Cliente-Servidor

## Mudanças Realizadas

### 1. Remoção de Dados Mockados
- Removido `MOCK_BOSSES` com dados estáticos
- Removido sistema de persistência local (`saveBossData`/`loadBossData`)
- Removido funções de teste (`killBoss`, `resetAllBosses`)

### 2. Implementação de Comunicação com Servidor
- **Opcode**: 250 (mesmo usado no servidor)
- **Protocolo**: JSON via Extended Opcode
- **Requisições**: Automáticas a cada 30 segundos + manual via clique

### 3. Estrutura de Dados do Servidor
```lua
{
    action = "updateBossList",
    bosses = {
        {
            id = 20000,
            name = "Hidan Boss",
            looktype = 128,
            status = "Ready" ou "HH:MM:SS",
            remainingTime = 0,
            progressBar = 100
        }
    }
}
```

### 4. Funcionalidades Implementadas

#### Comunicação Automática
- Solicita lista de bosses ao abrir a janela
- Atualiza automaticamente a cada 30 segundos
- Processa respostas do servidor em tempo real

#### Interface Dinâmica
- Mostra até 5 bosses simultaneamente
- Ordena por status: Ready primeiro, depois por tempo restante
- Atualiza progress bars e contadores em tempo real

#### Interação do Usuário
- **F12** ou **Ctrl+Shift+B**: Abrir/fechar janela
- **Clique em boss**: Solicitar atualização imediata
- **Tooltip**: "Click to refresh boss data"

### 5. Funções de Debug
```lua
BossTracker.refresh()  -- Solicitar atualização manual
BossTracker.debug()    -- Mostrar informações de debug
BossTracker.center()   -- Centralizar janela
```

### 6. Tratamento de Erros
- Verifica se o jogo está online antes de enviar requisições
- Trata erros de JSON parsing
- Fallback para bosses não encontrados
- Interface responsiva mesmo sem dados

### 7. Compatibilidade
- Mantém mesma estrutura de UI (bosstracker.otui)
- Compatível com sistema de hotkeys existente
- Integração transparente com o servidor

## Como Usar

1. **Automaticamente**: O sistema solicita dados ao abrir a janela
2. **Manual**: Use `BossTracker.refresh()` no console
3. **Clique**: Clique em qualquer boss para atualizar

## Configuração do Servidor

Certifique-se de que o servidor está configurado com:
- `lib/Raposo_BossTracker.lua` - Sistema principal
- `creaturescripts/scripts/opcode/RaposoOpcodes.lua` - Handler do opcode 250
- `creaturescripts/scripts/boss_tracker_login.lua` - Envio inicial no login
- `talkactions/scripts/boss_tracker.lua` - Comando de teste `/bosstracker`

## Troubleshooting

### Problemas Comuns
1. **Bosses não aparecem**: Verifique se o servidor está enviando dados
2. **Opcode não funciona**: Confirme que o opcode 250 está registrado
3. **Dados não atualizam**: Verifique conexão com servidor

### Debug
```lua
BossTracker.debug()  -- Verificar estado do sistema
BossTracker.refresh() -- Forçar atualização
```

## Estrutura de Arquivos
```
modules/game_bosstracker/
├── bosstracker.lua      # Sistema principal (atualizado)
├── bosstracker.otui     # Interface (atualizada)
├── bosstracker.otmod    # Configuração do módulo
└── CLIENT_INTEGRATION.md # Esta documentação
```
