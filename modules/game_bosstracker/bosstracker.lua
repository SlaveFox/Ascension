-- ===========================================
-- BOSS TRACKER SYSTEM
-- ===========================================
BossTracker = {}

-- Constantes
local OPCODE = 251 -- Opcode para comunicação com o servidor
local TICK_INTERVAL = 250 -- 500ms para atualização local
local REQUEST_INTERVAL = 250 -- 60 segundos para solicitar atualização do servidor
local FAST_REQUEST_INTERVAL = 250 -- 10 segundos quando há cooldowns ativos
local PAUSE_INTERVAL = 300000 -- 5 minutos quando não há cooldowns

-- Variáveis globais
local window = nil
local ticker = nil
local requestTicker = nil
local bossData = {}
local lastRequestTime = 0
local hasActiveCooldowns = false
local lastBossCount = 0

-- =========[ Helpers ]=========
local function getBossSlot(id)
    if not window then return nil end
    
    -- Tentar buscar slot existente
    local slot = window:recursiveGetChildById("boss" .. id)
    if slot then return slot end
    
    -- Se não existir, criar dinamicamente
    local contentsPanel = window:recursiveGetChildById("contentsPanel")
    if not contentsPanel then return nil end
    
    -- Criar novo slot
    slot = g_ui.createWidget("BossCreature", contentsPanel)
    slot:setId("boss" .. id)
    
    return slot
end

local function formatTime(seconds)
    if seconds <= 0 then return "Ready" end
    
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60
    
    if hours > 0 then
        return string.format("%02d:%02d:%02d", hours, minutes, secs)
    else
        return string.format("%02d:%02d", minutes, secs)
    end
end

local function getCooldownProgress(remainingTime, totalTime)
    if remainingTime <= 0 then return 100 end
    if totalTime <= 0 then return 0 end
    return math.max(0, 100 - (remainingTime / totalTime * 100))
end

local function setBossOutfit(widget, lookType)
    if not widget then return end
    widget:setOutfit({ type = lookType })
    widget:setAnimate(true)
end

-- =========[ Comunicação com Servidor ]=========
local function requestBossList()
    if not g_game.isOnline() then 
        return 
    end
    
    local data = {
        action = "getBossList"
    }
    
    g_game.getProtocolGame():sendExtendedOpcode(OPCODE, json.encode(data))
end

-- Declaração forward das funções
local updateAllBosses

-- =========[ Smart Update Functions ]=========
local function hasActiveCooldownsCheck()
    local currentTime = os.time()
    hasActiveCooldowns = false
    
    for _, bossInfo in pairs(bossData) do
        if bossInfo.remainingTime and bossInfo.remainingTime > 0 then
            hasActiveCooldowns = true
            break
        end
    end
    
    return hasActiveCooldowns
end

local function handleServerResponse(data)
    if not data or not data.bosses then 
        return 
    end
    
    -- Verificar se houve mudança significativa no número de bosses
    local currentBossCount = #data.bosses
    local bossCountChanged = (currentBossCount ~= lastBossCount)
    lastBossCount = currentBossCount
    
    -- Limpar dados antigos
    bossData = {}
    
    -- Processar dados do servidor
    for i, boss in ipairs(data.bosses) do
        if boss and boss.id then
            bossData[boss.id] = {
                id = boss.id,
                name = boss.name or "Unknown Boss",
                lookType = boss.looktype or 1,
                remainingTime = boss.remainingSeconds or 0,
                status = boss.timeText or "Ready",
                progressBar = boss.progress or 100
            }
        end
    end
    
    -- Atualizar estado de cooldowns
    hasActiveCooldowns = hasActiveCooldownsCheck()
    
    -- Atualizar UI
    if updateAllBosses then
        updateAllBosses()
    end
    
    -- Se houve mudança significativa, solicitar atualização mais frequente temporariamente
    if bossCountChanged then
        lastRequestTime = os.time() - (FAST_REQUEST_INTERVAL / 1000) + 1
    end
end

-- =========[ Atualização de UI ]=========
local function updateBossSlot(bossId, bossInfo)
    local slot = getBossSlot(bossId)
    if not slot then return end
    
    local creature = slot:getChildById("creature")
    local bossName = slot:getChildById("bossName")
    local timeLabel = slot:getChildById("timeLabel")
    local cooldownBar = slot:getChildById("cooldownBar")
    
    -- Sempre mostrar a outfit
    if creature and bossInfo then
        creature:setVisible(true)
        setBossOutfit(creature, bossInfo.lookType)
        creature:setTooltip(bossInfo.name)
    end
    
    if not bossInfo then
        -- Boss não encontrado
        if bossName then bossName:setText("No Boss") end
        if timeLabel then 
            timeLabel:setText("Unknown")
            timeLabel:setColor("#FF6666")
        end
        if cooldownBar then 
            cooldownBar:setPercent(0)
            cooldownBar:setBackgroundColor("#FF6666")
        end
        return
    end
    
    -- Atualizar informações do boss
    if bossName then bossName:setText(bossInfo.name) end
    
    if bossInfo.remainingTime > 0 then
        -- Em cooldown
        if timeLabel then 
            timeLabel:setText(formatTime(bossInfo.remainingTime))
            timeLabel:setColor("#FF6666")
        end
        if cooldownBar then 
            cooldownBar:setPercent(bossInfo.progressBar or 0)
            cooldownBar:setBackgroundColor("#FF6666")
        end
    else
        -- Pronto
        if timeLabel then 
            timeLabel:setText("Ready")
            timeLabel:setColor("#00FF00")
        end
        if cooldownBar then 
            cooldownBar:setPercent(100)
            cooldownBar:setBackgroundColor("#00FF00")
        end
    end
end

local function updateAllBosses()
    -- Verificar se a janela existe
    if not window or window:isDestroyed() then
        return
    end
    
    -- Criar lista ordenada: ready primeiro, depois por tempo restante
    local sortedBosses = {}
    for id, bossInfo in pairs(bossData) do
        if bossInfo then
            table.insert(sortedBosses, {
                id = id,
                bossInfo = bossInfo,
                remainingTime = bossInfo.remainingTime or 0,
                isReady = (bossInfo.remainingTime or 0) <= 0
            })
        end
    end
    
    -- Ordenar: ready primeiro, depois por tempo restante (menor primeiro)
    table.sort(sortedBosses, function(a, b)
        if a.isReady and not b.isReady then return true end
        if not a.isReady and b.isReady then return false end
        if a.isReady and b.isReady then return a.id < b.id end
        return a.remainingTime < b.remainingTime
    end)
    
    -- Atualizar slots na ordem correta (todos os bosses)
    for i = 1, #sortedBosses do
        local sortedBoss = sortedBosses[i]
        if sortedBoss then
            updateBossSlot(i, sortedBoss.bossInfo)
        else
            -- Slot vazio
            updateBossSlot(i, nil)
        end
    end
    
    -- Limpar slots extras se houver menos bosses que slots
    for i = #sortedBosses + 1, 50 do -- máximo 50 slots para segurança
        local slot = getBossSlot(i)
        if slot then
            slot:destroy()
        end
    end
    
    -- Não ajustar altura automaticamente para manter tamanho salvo pelo usuário
    
end

local function shouldRequestUpdate()
    local currentTime = os.time()
    local timeSinceLastRequest = currentTime - lastRequestTime
    
    -- Se há cooldowns ativos, usar intervalo rápido
    if hasActiveCooldowns then
        return timeSinceLastRequest >= (FAST_REQUEST_INTERVAL / 1000)
    else
        -- Se não há cooldowns, usar intervalo longo
        return timeSinceLastRequest >= (REQUEST_INTERVAL / 1000)
    end
end

local function tickFunction()
    -- Atualizar interface local
    updateAllBosses()
    
    -- Verificar se precisa solicitar dados do servidor
    if shouldRequestUpdate() then
        requestBossList()
        lastRequestTime = os.time()
    end
    
    -- Verificar mudanças de estado
    local currentCooldowns = hasActiveCooldownsCheck()
    if currentCooldowns ~= hasActiveCooldowns then
        hasActiveCooldowns = currentCooldowns
        -- Estado mudou, pode precisar ajustar frequência
    end
    
    ticker = scheduleEvent(tickFunction, TICK_INTERVAL)
end

local function requestTickerFunction()
    -- Esta função agora é gerenciada pelo tickFunction inteligente
    -- Mantida para compatibilidade, mas não será usada
    requestBossList()
    requestTicker = scheduleEvent(requestTickerFunction, REQUEST_INTERVAL)
end

local function startTicker()
    if ticker then return end
    lastRequestTime = os.time()
    hasActiveCooldowns = hasActiveCooldownsCheck()
    ticker = scheduleEvent(tickFunction, TICK_INTERVAL)
end

local function startRequestTicker()
    -- Não usar mais o requestTicker separado
    -- Tudo é gerenciado pelo tickFunction inteligente
    return
end

local function stopTicker()
    if ticker then
        removeEvent(ticker)
        ticker = nil
    end
end

local function stopRequestTicker()
    -- Não usar mais o requestTicker separado
    -- Tudo é gerenciado pelo tickFunction inteligente
    return
end

-- =========[ Event Handlers ]=========
local function onExtendedOpcode(protocol, opcode, buffer)
    if opcode ~= OPCODE then 
        return 
    end
    
    local success, data = pcall(function() return json.decode(buffer) end)
    if success and data then
        handleServerResponse(data)
    end
end

-- =========[ Hotkeys ]=========
local function onHotkey()
    BossTracker.toggle()
end

-- =========[ API Pública ]=========
function BossTracker.init()
    -- Conectar eventos
    connect(g_game, {
        onGameStart = function()
            -- Registrar hotkey quando o jogo iniciar
            g_keyboard.bindKeyDown("Ctrl+Shift+B", onHotkey)
            -- Também registrar uma alternativa mais simples
            g_keyboard.bindKeyDown("F12", onHotkey)
        end,
        onGameEnd = function()
            -- Remover hotkey quando o jogo terminar
            g_keyboard.unbindKeyDown("Ctrl+Shift+B")
            g_keyboard.unbindKeyDown("F12")
            BossTracker.hide()
        end
    })
    
    -- Registrar opcode handler
    ProtocolGame.registerExtendedOpcode(OPCODE, onExtendedOpcode)

    
    -- Carregar UI mas não mostrar ainda
    window = g_ui.loadUI('bosstracker', modules.game_interface.getRightPanel())
    if window then
        window:setup()
        window:hide()
    end
    
    -- Inicializar hotkeys se o jogo já estiver online
    if g_game.isOnline() then
        g_keyboard.bindKeyDown("Ctrl+Shift+B", onHotkey)
        g_keyboard.bindKeyDown("F12", onHotkey)
    end
end

function BossTracker.terminate()
    -- Parar tickers
    stopTicker()
    -- Não usar mais stopRequestTicker() - tudo é gerenciado pelo tickFunction inteligente
    
    -- Desconectar eventos
    disconnect(g_game, {
        onGameStart = BossTracker.show,
        onGameEnd = BossTracker.hide
    })
    
    -- Desregistrar opcode handler
    ProtocolGame.unregisterExtendedOpcode(OPCODE)
    
    -- Remover hotkey
    g_keyboard.unbindKeyDown("Ctrl+Shift+B")
    g_keyboard.unbindKeyDown("F12")
    
    -- Fechar janela
    if window and not window:isDestroyed() then
        window:destroy()
    end
    window = nil
    
    -- Limpar botão do topmenu
    if BossTracker.button then
        BossTracker.button = nil
    end
    
    -- Limpar variáveis de estado
    bossData = {}
    lastRequestTime = 0
    hasActiveCooldowns = false
    lastBossCount = 0
end

function BossTracker.show()
    if not window or window:isDestroyed() then
        return
    end
    
    -- Configurar cliques nos bosses para informações (dinamicamente)
    for i = 1, 50 do -- máximo 50 bosses
        local slot = getBossSlot(i)
        if slot then
            slot.onClick = function()
                -- Solicitar atualização imediata do servidor
                requestBossList()
                lastRequestTime = os.time()
            end
            slot:setTooltip("Click to refresh boss data")
        end
    end
    
    if window then
        window:show()
        window:raise()
        window:focus()
        updateAllBosses()
        startTicker()
        -- Não usar mais startRequestTicker() - tudo é gerenciado pelo tickFunction inteligente
        
        -- Solicitar dados iniciais do servidor
        requestBossList()
        lastRequestTime = os.time()
    end
end

function BossTracker.hide()
    if window and not window:isDestroyed() then
        window:hide()
    end
    if BossTracker.button then
        BossTracker.button:setOn(false)
    end
    stopTicker()
    -- Não usar mais stopRequestTicker() - tudo é gerenciado pelo tickFunction inteligente
end

function BossTracker.toggle()
    if not window or window:isDestroyed() then
        return
    end
    
    if not window:isVisible() then
        BossTracker.show()
        if BossTracker.button then
            BossTracker.button:setOn(true)
        end
    else
        BossTracker.hide()
        if BossTracker.button then
            BossTracker.button:setOn(false)
        end
    end
end

function BossTracker.refresh()
    requestBossList()
end


function BossTracker.center()
    if window and not window:isDestroyed() then
        local screenSize = g_window.getSize()
        local windowSize = window:getSize()
        local x = math.max(10, (screenSize.width - windowSize.width) / 2)
        local y = math.max(10, (screenSize.height - windowSize.height) / 2)
        
        window:setPosition({x = x, y = y})
        window:raise()
        window:focus()
    end
end

-- Exportar para uso global
_G.BossTracker = BossTracker