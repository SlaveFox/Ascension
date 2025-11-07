-- Rolette UI à Raposo Standard (com support a amount)
-- - Suporte a OpenMain
-- - Consistência de IDs (itemReward serverId, clientId para UI)
-- - Proteções: no double-spin, reset de offset, cleanup de eventos
-- - Exibição de quantidade (amount) no carrossel e no resultado

local roletteWin            -- janela da roleta (carrossel)
local rolettePanel
local roletteContainer
local roletteMainWin        -- janela principal (estoques/keys)
local roletteMainVisible = false

local rollingEvent = nil
local isRolling    = false
local offset       = 0

-- Ajustáveis
local TOTAL_ITEMS_VISIBLE = 12       -- deve bater com o servidor
local GameOpcodeRolette   = 45

-- Dinâmica da rolagem
local initialSpeed = 100        -- velocidade inicial
local currentSpeed = initialSpeed
local deceleration = 10         -- desaceleração simples (subtração fixa)
local animationInterval = 30   -- intervalo de atualização (30ms)

-- cache
-- [{itemReward=serverId, clientId=?, name=?, rarity=?, chance=?, amount=?}, ...]
local lastRoletteItems = {}

-- --------------- Helpers ---------------

local function cancelRolling()
  if rollingEvent then
    removeEvent(rollingEvent)
    rollingEvent = nil
  end
  isRolling = false
end

local function ensureContainer()
  if not roletteWin or not rolettePanel or not roletteContainer then
    return false
  end
  return true
end

local function setItemFrame(widget, rarity)
  if rarity == "common" then
    widget:setImageSource("assets/itemcommon.png")
  elseif rarity == "rare" then
    widget:setImageSource("assets/itemrare.png")
  elseif rarity == "legendary" then
    widget:setImageSource("assets/itemlegendary.png")
  else
    widget:setImageSource("assets/itemcommon.png")
  end
end

local function toggleMain(show)
  roletteMainVisible = not not show
  if roletteMainWin then
    roletteMainWin:setVisible(roletteMainVisible)
  end
end

-- --------------- Lifecycle ---------------

function init()
  -- Janela principal (estoques/keys)
  roletteMainWin = g_ui.loadUI("winrolette", modules.game_interface.getRootPanel())
  if roletteMainWin then roletteMainWin:hide() end

  -- Janela da roleta
  roletteWin = g_ui.loadUI("rolette", modules.game_interface.getRootPanel())
  if roletteWin then roletteWin:hide() end

  rolettePanel     = roletteWin and roletteWin:getChildById('rolettePanel') or nil
  roletteContainer = rolettePanel and rolettePanel:getChildById('roletteContainer') or nil

  ProtocolGame.registerExtendedOpcode(GameOpcodeRolette, onPlayerReceiveRolette)
end

function terminate()
  cancelRolling()
  ProtocolGame.unregisterExtendedOpcode(GameOpcodeRolette)

  roletteWin         = nil
  rolettePanel       = nil
  roletteContainer   = nil
  roletteMainWin     = nil
  roletteMainVisible = false
end

-- --------------- Abertura Manual (toggle) ---------------

function exibirwinprin()
  if not roletteMainVisible then
    toggleMain(true)
    g_game.getProtocolGame():sendExtendedOpcode(GameOpcodeRolette, json.encode({ type = "baus" }))
  else
    naoexibirwinprin()
  end
end

-- --------------- Handlers do servidor ---------------

function onPlayerReceiveRolette(protocol, opcode, payload)
  local ok, data = pcall(function() return json.decode(payload) end)
  if not ok or not data then return end

  -- Abre a janela principal sob comando do servidor
  if data.type == "OpenMain" then
    toggleMain(true)
    g_game.getProtocolGame():sendExtendedOpcode(GameOpcodeRolette, json.encode({ type = "baus" }))
    return
  end

  -- Recebe lista e mostra carrossel
  -- Suporta tanto "OpenRolette" quanto "OpenRollete" (para compatibilidade)
  if data.type == "OpenRolette" or data.type == "OpenRollete" then
    lastRoletteItems = data.items or {}

    -- Troca skin da janela conforme o chest
    if roletteWin then
      if data.chestType == "rare" then
        roletteWin:setImageSource("assets/windowrare.png")
      elseif data.chestType == "common" then
        roletteWin:setImageSource("assets/windowcommon.png")
      elseif data.chestType == "legendary" then
        roletteWin:setImageSource("assets/windowlegendary.png")
      end
    end

    exibir(lastRoletteItems)
    toggleMain(false)
    return
  end

  -- Resultado do giro
  if data.type == "GameOn" and data.item then
    -- Servidor envia: itemReward (serverId), clientId, name, amount (opcional)
    GameOn(
      data.item.itemReward,
      data.item.clientId,
      data.item.name,
      data.item.amount or 1
    )
    return
  end

  -- Estoques/keys
  if data.type == "BausInfo" then
    if not roletteMainWin then return end

    local commonQty    = (data.baus and data.baus.common) or "?"
    local rareQty      = (data.baus and data.baus.rare) or "?"
    local legendaryQty = (data.baus and data.baus.legendary) or "?"

    local wCommon    = roletteMainWin:getChildById("common")
    local wRare      = roletteMainWin:getChildById("rare")
    local wLegendary = roletteMainWin:getChildById("legendary")
    if wCommon    then wCommon:setText("Common: " .. tostring(commonQty)) end
    if wRare      then wRare:setText("Rare: " .. tostring(rareQty)) end
    if wLegendary then wLegendary:setText("Legendary: " .. tostring(legendaryQty)) end

    local commonWidget    = roletteMainWin:getChildById("commonkey")
    local rareWidget      = roletteMainWin:getChildById("rarekey")
    local legendaryWidget = roletteMainWin:getChildById("legendarykey")

    if commonWidget and data.keys and data.keys.common then
      commonWidget:setItemId(data.keys.common.clientId or 0)
      commonWidget:setItemCount(data.keys.common.count or 1)
      commonWidget:setTooltip(data.keys.common.name or "Common Card")
    end
    if rareWidget and data.keys and data.keys.rare then
      rareWidget:setItemId(data.keys.rare.clientId or 0)
      rareWidget:setItemCount(data.keys.rare.count or 1)
      rareWidget:setTooltip(data.keys.rare.name or "Rare Card")
    end
    if legendaryWidget and data.keys and data.keys.legendary then
      legendaryWidget:setItemId(data.keys.legendary.clientId or 0)
      legendaryWidget:setItemCount(data.keys.legendary.count or 1)
      legendaryWidget:setTooltip(data.keys.legendary.name or "Legendary Card")
    end

    local commonText    = roletteMainWin:getChildById("keyscommon")
    local rareText      = roletteMainWin:getChildById("keysrare")
    local legendaryText = roletteMainWin:getChildById("keyslegendary")

    if commonText    and data.keys and data.keys.common then commonText:setText("Você Possui: " .. (data.keys.common.playerCount or 0)) end
    if rareText      and data.keys and data.keys.rare then   rareText:setText("Você Possui: " .. (data.keys.rare.playerCount or 0)) end
    if legendaryText and data.keys and data.keys.legendary then legendaryText:setText("Você Possui: " .. (data.keys.legendary.playerCount or 0)) end

    return
  end

  -- Lista de recompensas (quando solicitado) - nomes + amount
  if data.type == "BauRewards" then
    local title = "Recompensas do Baú (" .. (data.chestType or "?") .. ")"
    local lines = {}
    for i, r in ipairs(data.rewards or {}) do
      local amt = r.amount or 1
      local nm  = r.name or "Item"
      if amt > 1 then
        table.insert(lines, string.format("%d. %s x%d", i, nm, amt))
      else
        table.insert(lines, string.format("%d. %s", i, nm))
      end
    end
    displayInfoBox(title, table.concat(lines, "\n"))
    return
  end
end

-- --------------- UI: mostrar lista (carrossel) ---------------

local function createAmountBadge(parent, amount)
  -- Se seu Roletteitem já tiver um child "amountLabel", use-o.
  -- Caso contrário, criamos um label simples ancorado.
  local lbl = parent:getChildById("amountLabel")
  if not lbl then
    lbl = g_ui.createWidget("UILabel", parent)
    lbl:setId("amountLabel")
    lbl:setPhantom(false)
    lbl:setFont("baby-14")
    lbl:setColor("#FFFFFF")
    lbl:setTextAutoResize(true)
    lbl:setTextAlign(AlignBottomRight)
    lbl:addAnchor(AnchorBottom, "parent", AnchorBottom)
    lbl:addAnchor(AnchorRight,  "parent", AnchorRight)
    lbl:setMarginBottom(2)
    lbl:setMarginRight(4)
    lbl:setBackgroundColor("#00000066") -- leve dark para destacar
    lbl:setPadding(2)
  end
  if amount and amount > 1 then
    lbl:setText("x" .. tostring(amount))
    lbl:show()
  else
    lbl:setText("")
    lbl:hide()
  end
  return lbl
end

function exibir(items)
  if not ensureContainer() then return end

  -- segurança
  cancelRolling()
  offset       = 0
  currentSpeed = initialSpeed

  roletteWin:show()
  roletteContainer:destroyChildren()

  local n   = math.max(TOTAL_ITEMS_VISIBLE, 1)
  local len = #items
  if len == 0 then return end

  -- preenche 2 blocos idênticos para looping suave
  local function pushWidget(i, idx)
    local data = items[((idx - 1) % len) + 1]
    local w = g_ui.createWidget("Roletteitem", roletteContainer)
    w:setId("rolette" .. i)
    w:setSize("130 120")
    w:setItemId(data.clientId or 0)            -- clientId para UI
    -- w:setItemCount(math.max(1, data.amount or 1)) -- mostra stack quando stackável
    setItemFrame(w, data.rarity)

    -- Badge xN (para qualquer item; se in-stack não for mostrado, badge cobre isso)
    createAmountBadge(w, data.amount or 1)
  end

  for i = 1, n do pushWidget(i, i) end
  for i = 1, n do pushWidget(i + n, i) end
end

-- --------------- UI: resultado ---------------

local resultWin
local function showResult(clientId, name, amount)
  -- Fecha a interface da roleta imediatamente
  if roletteWin then
    roletteWin:hide()
  end
  
  resultWin = g_ui.loadUI("itemResult", modules.game_interface.getRootPanel())
  if not resultWin then return end
  resultWin:show()

  local itemDisplay = resultWin:getChildById("itemDisplay")
  local resultLabel = resultWin:getChildById("resultText")
  local qtyLabel    = resultWin:getChildById("resultAmount") -- se seu .otui tiver um label para isso

  if itemDisplay then
    itemDisplay:setItemId(clientId or 0) -- UI: usa clientId
    itemDisplay:setItemCount(math.max(1, amount or 1))
  end

  local nm = name or "item"
  if resultLabel then
    if (amount or 1) > 1 then
      resultLabel:setText("Parabéns, você ganhou\n" .. nm .. " x" .. tostring(amount))
    else
      resultLabel:setText("Parabéns, você ganhou\n" .. nm)
    end
    resultLabel:setTextAutoResize(true)
    resultLabel:setTextWrap(true)
    resultLabel:setTextAlign(AlignTopCenter)
  end

  if qtyLabel then
    if (amount or 1) > 1 then
      qtyLabel:setText("x" .. tostring(amount))
      qtyLabel:show()
    else
      qtyLabel:setText("")
      qtyLabel:hide()
    end
  end

  -- Fecha automaticamente a interface de resultado após 3 segundos
  scheduleEvent(function()
    if resultWin then
      resultWin:hide()
      resultWin = nil
    end
    -- Não reabre a interface principal automaticamente
  end, 3000)
end

-- --------------- Lógica do giro ---------------

function GameOn(targetServerId, targetClientId, targetName, targetAmount)
  if isRolling then
    -- evita spin duplo
    return
  end
  if not ensureContainer() then return end
  if #lastRoletteItems == 0 then return end

  -- encontra índice do item alvo pelo serverId (itemReward)
  local targetIndex
  for i, data in ipairs(lastRoletteItems) do
    if data.itemReward == targetServerId then
      targetIndex = i
      break
    end
  end
  if not targetIndex then return end

  -- medidas
  local panelWidth = rolettePanel:getWidth()
  local halfPanel  = panelWidth / 2

  local firstChild = roletteContainer:getChildByIndex(1)
  if not firstChild then return end
  local itemWidth = firstChild:getWidth()

  local singleBlockSize = itemWidth * TOTAL_ITEMS_VISIBLE

  -- alvo: centro do item alvo no bloco
  local itemCenterOffset = (targetIndex - 1) * itemWidth + (itemWidth / 2)
  local target_offset    = itemCenterOffset - halfPanel
  if target_offset < 0 then
    target_offset = target_offset + singleBlockSize
  end

  -- reset
  cancelRolling()
  isRolling    = true
  currentSpeed = initialSpeed
  offset       = 0
  roletteContainer:setX(0)

  local function stepGameOn()
    -- Atualiza posição
    offset = offset + currentSpeed
    roletteContainer:setX(-offset)

    -- Loop suave quando ultrapassa o bloco
    if offset >= singleBlockSize then
      offset = offset - singleBlockSize
      roletteContainer:setX(-offset)
    end

    -- Calcula distância até o alvo
    local dist = math.abs(offset - target_offset)
    
    -- Desacelera quando próximo do alvo
    if dist < currentSpeed then
      currentSpeed = currentSpeed - deceleration
      
      -- Para quando velocidade mínima atingida
      if currentSpeed <= 0.5 then
        offset = target_offset
        roletteContainer:setX(-offset)
        isRolling = false
        rollingEvent = nil
        
        -- Mostra resultado e fecha interface da roleta
        showResult(targetClientId, targetName, targetAmount or 1)
        return
      end
    end
    
    -- Continua animação
    rollingEvent = scheduleEvent(stepGameOn, animationInterval)
  end

  stepGameOn()
end

-- --------------- Ações (botões) ---------------

function abririnterfacebau(tipo)
  -- tipo: "common"/"rare"/"legendary"
  g_game.getProtocolGame():sendExtendedOpcode(GameOpcodeRolette, json.encode({ type = "jogar", action = tipo }))
end

function abririnfo(tipo)
  g_game.getProtocolGame():sendExtendedOpcode(GameOpcodeRolette, json.encode({ type = "info", action = tipo }))
end

-- Fechamentos

function naoexibir()
  if roletteWin then
    roletteWin:hide()
  end
  if resultWin then
    resultWin:hide()
    resultWin = nil
  end
  -- Não reabre a interface principal automaticamente
end

function naoexibirwinprin()
  toggleMain(false)
end
