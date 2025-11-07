-- ===========================================
-- Interface do Sistema de Tier (Cliente)
-- By Raposo (refatorado)
-- ===========================================
modules = modules or {}
modules.game_tier = modules.game_tier or {}
local tier = modules.game_tier

-- ===== Constantes / estado =====
local OPCODE = 30
local LEVELS_PER_TIER = 5
local FILL_COLOR = "#A6230D"

-- UI refs
local window, actionButton, upgradeProgress
local goldLabel, premiumLabel, ringProgressBar, creatureBox, itemSlotsPanel
local rings, fills, rankIcons = {}, {}, {}

-- eventos
local cooldownEvent = nil

-- ===== Mappers =====
local RANK_IMAGE = {
  Unranked="unranked", Bronze="bronze", Prata="prata", Ouro="ouro",
  Platina="platina", Diamante="diamante", Mestre="mestre",
  GrandeMestre="grandemestre", Desafiante="desafiante",
  Mitico="mitico", Lendario="lendario",
}

-- ===========================================
-- Utils
-- ===========================================
local function clamp(v, a, b) return math.max(a, math.min(b, v or 0)) end

local function setPercent(widget, pct)
  if not widget then return end
  if widget.setPercent then widget:setPercent(pct)
  elseif widget.setValue then widget:setValue(pct)
  else widget.value = pct end
end

local function safeSetText(widget, txt)
  if widget and widget.setText then widget:setText(txt or "") end
end

local function getRef(pathTable)
  local ref = window
  for _, id in ipairs(pathTable) do
    if not ref then return nil end
    ref = ref:getChildById(id)
  end
  return ref
end

local function clearCooldownEvent()
  if cooldownEvent then removeEvent(cooldownEvent) end
  cooldownEvent = nil
end

local function formatHMS(sec)
  sec = math.max(0, tonumber(sec) or 0)
  local h = math.floor(sec / 3600)
  local m = math.floor((sec % 3600) / 60)
  local s = sec % 60
  return string.format("%02d:%02d:%02d", h, m, s)
end

local function makeButtonGreen(btn)
  if not btn then return end
  if btn.addStyle then pcall(function() btn:addStyle("success") end) end
  local lbl = btn:getChildById("text") or btn
  if lbl and lbl.setColor then pcall(function() lbl:setColor("#3cbc3c") end) end
end

local function resetButtonStyle(btn)
  if not btn then return end
  if btn.removeStyle then pcall(function() btn:removeStyle("success") end) end
  local lbl = btn:getChildById("text") or btn
  if lbl and lbl.setColor then pcall(function() lbl:setColor("#ffffff") end) end
end

-- ===========================================
-- Cooldown progress
-- ===========================================
local sentFinishOnce = false  -- manter se já existir

local function startCooldownProgress(totalSeconds, remaining)
  sentFinishOnce = false
  clearCooldownEvent()
  if not upgradeProgress then return end

  local timeLabel = upgradeProgress:getChildById("timeLabel")
  local elapsed = math.max(0, totalSeconds - remaining)

  local function tick()
    elapsed = elapsed + 1
    local rest = math.max(0, totalSeconds - elapsed)
    setPercent(upgradeProgress, math.min(elapsed / totalSeconds * 100, 100))
    if timeLabel then safeSetText(timeLabel, formatHMS(rest)) end

    if rest > 0 then
      cooldownEvent = scheduleEvent(tick, 1000)
    else
      -- chegou no zero: muda o botão para "Concluir Upgrade"
      clearCooldownEvent()
      setPercent(upgradeProgress, 100)
      safeSetText(timeLabel, "00:00:00")
      setupActionForReadyToFinish()
    end
  end

  -- estado inicial
  setPercent(upgradeProgress, math.min(elapsed / totalSeconds * 100, 100))
  if timeLabel then safeSetText(timeLabel, formatHMS(remaining)) end
  cooldownEvent = scheduleEvent(tick, 1000)
end

-- ===========================================
-- Rings / fills / rank icons
-- ===========================================
local function updateRingsVisual(level, doneSource, pendingSource)
  doneSource    = doneSource    or "images/ring"
  pendingSource = pendingSource or "images/ring"
  for i = 1, 6 do
    local w = rings[i]
    if w and w.setImageSource then
      w:setImageSource(i <= (level + 1) and doneSource or pendingSource)
    end
  end
end

local function updateFills(level)
  for i = 1, 6 do
    local fill = fills[i]
    if fill then
      local reached = (i <= (level + 1))
      fill:setVisible(reached)
      if reached and fill.setImageColor then fill:setImageColor(FILL_COLOR) end
    end
  end
end

function tier.setRingLevel(level)
  level = clamp(tonumber(level) or 0, 0, LEVELS_PER_TIER)
  setPercent(ringProgressBar, (level / LEVELS_PER_TIER) * 100)
  updateRingsVisual(level)
  updateFills(level)
end

local function updateRankBadges(rank, level)
  -- anel central (ring1) sempre mostra o rank atual
  local base = RANK_IMAGE[rank or ""] and ("images/ranks/" .. RANK_IMAGE[rank]) or nil
  if base and rankIcons[1] then
    rankIcons[1]:setImageSource(base)
    rankIcons[1]:setVisible(true)
  end
  -- esconde todos os pequenos
  for i = 2, 6 do if rankIcons[i] then rankIcons[i]:setVisible(false) end end
  -- mostra apenas a quantidade = level atual (nos anéis menores)
  local lvl = clamp(level or 0, 0, LEVELS_PER_TIER)
  for i = 2, math.min(1 + lvl, 6) do
    if rankIcons[i] and base then
      rankIcons[i]:setImageSource(base)
      rankIcons[i]:setVisible(true)
    end
  end
end

-- ===========================================
-- Slots / custos
-- ===========================================
local function createCostSlots(requirements)
  if not itemSlotsPanel then return end
  itemSlotsPanel:destroyChildren()

  if not requirements then return end

  -- ?silver? é tratado como gold bars na lógica do servidor;
  -- aqui renderizamos apenas como informação (slot ilustrativo).
  if (requirements.silver or 0) > 0 then
    local slot = g_ui.createWidget("SlotTemplate", itemSlotsPanel)
    slot:setItemId(3043) -- gold coin (ilustrativo)
    local qty = slot:getChildById("qty")
    if qty then qty:setText(tostring(requirements.silver)) end
    slot:setTooltip("Necessário: " .. tostring(requirements.silver) .. " gold bars")
  end

  if (requirements.clientId or 0) > 0 then
    local slot = g_ui.createWidget("SlotTemplate", itemSlotsPanel)
    slot:setItemId(requirements.clientId)
    local qty2 = slot:getChildById("qty")
    if qty2 then qty2:setText(tostring(requirements.itemCount or 0)) end
    local itemName = requirements.itemName or "Item"
    slot:setTooltip("Necessário: " .. tostring(requirements.itemCount or 0) .. "x " .. itemName)
  end
end

-- ===========================================
-- Action button
-- ===========================================
local function setActionButton(text, enabled, onClick)
  if not actionButton then return end
  actionButton:setText(text or "")
  actionButton:setEnabled(enabled ~= false)
  actionButton.onClick = onClick or function() end
end

local function setupActionForReadyToFinish()
  setActionButton("Concluir Upgrade", true, function()
    g_game.getProtocolGame():sendExtendedOpcode(OPCODE, json.encode({ action = "finishUpgrade" }))
  end)
  makeButtonGreen(actionButton)
end


local function setupActionForCooldown()
  setActionButton("Finalizar Upgrade", true, function()
    local cost = 10
    local msg = "Deseja finalizar o upgrade agora por " .. cost .. " pontos premium?"
    local box
    box = displayGeneralBox("Confirmação", msg, {
      { text="Sim", callback=function()
          g_game.getProtocolGame():sendExtendedOpcode(OPCODE, json.encode({ action="finishNow" }))
          clearCooldownEvent()
          if upgradeProgress then
            setPercent(upgradeProgress, 0)
            safeSetText(upgradeProgress:getChildById("timeLabel"), "00:00:00")
          end
          box:destroy()
        end },
      { text="Não", callback=function() box:destroy() end },
    }, nil, nil, true)
  end)
end

local function setupActionForStart()
  setActionButton("Iniciar Upgrade", true, function()
    g_game.getProtocolGame():sendExtendedOpcode(OPCODE, json.encode({ action="upgrade" }))
  end)
end

-- ===========================================
-- Render principal a partir do servidor
-- ===========================================
function tier.onServerData(data)
  if data.type ~= "OpenTier" then return end
  local p = data.playerData
  if not p then return end

  -- outfit
  if creatureBox and creatureBox.setOutfit and p.lookType then
    creatureBox:setOutfit({
      type=p.lookType, head=p.lookHead or 0, body=p.lookBody or 0,
      legs=p.lookLegs or 0, feet=p.lookFeet or 0, addons=p.lookAddons or 0
    })
    creatureBox:setAnimate(true)
  end

  -- badges
  updateRankBadges(p.rank, p.level)

  -- action
  -- action (3 estados)
  if p.readyToFinish then
    setupActionForReadyToFinish()
  elseif p.inCooldown and (p.cooldownRemaining or 0) > 0 then
    setupActionForCooldown()
  else
    setupActionForStart()
  end


  -- stats panel
  local statsPanel = window and window:recursiveGetChildById("statsPanel") or nil
  if statsPanel then
    safeSetText(statsPanel:recursiveGetChildById("statName"),    (p.name or "-"))
    safeSetText(statsPanel:recursiveGetChildById("statRank"),   "Rank: " .. (p.rank or "-") .. " " .. (p.level or 0))
    safeSetText(statsPanel:recursiveGetChildById("statDano"),   "Dano: +"   .. (p.bonusDamagePercent  or 0) .. "%")
    safeSetText(statsPanel:recursiveGetChildById("statDefesa"), "Defesa: +" .. (p.bonusDefensePercent or 0) .. "%")
    safeSetText(statsPanel:recursiveGetChildById("statVida"),   "Vida: +"   .. (p.bonusVidaPercent    or 0) .. "%")
    safeSetText(statsPanel:recursiveGetChildById("statMana"),   "Mana: +"   .. (p.bonusManaPercent    or 0) .. "%")

    safeSetText(statsPanel:recursiveGetChildById("evolveVida"),   "+" .. (p.nextVidaPercent    or 0) .. "% de vida")
    safeSetText(statsPanel:recursiveGetChildById("evolveMana"),   "+" .. (p.nextManaPercent    or 0) .. "% de mana")
    safeSetText(statsPanel:recursiveGetChildById("evolveAtaque"), "+" .. (p.nextDamagePercent  or 0) .. "% de ataque")
    safeSetText(statsPanel:recursiveGetChildById("evolveDefesa"), "+" .. (p.nextDefensePercent or 0) .. "% de defesa")
  end

  -- saldos
  safeSetText(goldLabel, tostring(p.balance or 0))
  safeSetText(premiumLabel, tostring(p.premiumPoints or 0))

  -- cooldown bar
  if upgradeProgress then
    if p.inCooldown and p.cooldownRemaining and p.cooldownTotal then
      startCooldownProgress(p.cooldownTotal, p.cooldownRemaining)
    else
      clearCooldownEvent()
      setPercent(upgradeProgress, 0)
      safeSetText(upgradeProgress:getChildById("timeLabel"), "00:00:00")
    end
  end

  -- custos
  createCostSlots(p.requirements)

  -- progress visual por nível
  if p.level then tier.setRingLevel(p.level) end
end

-- ===========================================
-- INIT / TERMINATE / OPEN/CLOSE
-- ===========================================
local function wireRefs()
  goldLabel       = getRef({ "topRow", "goldValue", "text" }) or getRef({ "goldValue", "text" })
  premiumLabel    = getRef({ "topRow", "premiumValue", "text" }) or getRef({ "premiumValue", "text" })
  ringProgressBar = getRef({ "ringRow", "ringProgress" })

  local leftTop = getRef({ "contentRow", "leftBigPanel", "leftTop" })
  creatureBox   = leftTop and leftTop:getChildById("creatureBox") or nil

  local leftBottom = getRef({ "contentRow", "leftBigPanel", "leftBottom" })
  itemSlotsPanel   = leftBottom and leftBottom:getChildById("itemSlots") or nil

  upgradeProgress  = window:recursiveGetChildById("upgradeProgress")
  actionButton     = window:recursiveGetChildById("actionButton")

  -- rings / fills / rank icons
  for i = 1, 6 do
    rings[i] = getRef({ "ringRow", "ring"..i })
    fills[i] = rings[i] and rings[i]:getChildById("ring"..i.."Fill") or nil
    if fills[i] then fills[i]:setVisible(false) end
    rankIcons[i] = window:recursiveGetChildById("ring"..i.."Rank")
  end
end

function init()
  ProtocolGame.registerExtendedOpcode(OPCODE, function(_, _, buffer)
    local ok, data = pcall(json.decode, buffer)
    if ok then tier.onServerData(data) end
  end)
  connect(g_game, { onGameEnd = tier.closeTierWindow })
end

function terminate()
  ProtocolGame.unregisterExtendedOpcode(OPCODE)
  disconnect(g_game, { onGameEnd = tier.closeTierWindow })
  tier.closeTierWindow()
end

function tier.openTierWindow()
  if not window then
    window = g_ui.loadUI("/modules/game_tier/tier.otui", modules.game_interface.getRootPanel())
    wireRefs()

    if creatureBox and creatureBox.setOutfit then creatureBox:setOutfit({ type = 38 }) end
    setActionButton("Carregando...", false, function() end)
  end

  window:show(); window:raise(); window:focus()
  if g_game.isOnline() then
    g_game.getProtocolGame():sendExtendedOpcode(OPCODE, json.encode({ action="requestData" }))
  end
end

function tier.closeTierWindow()
  clearCooldownEvent()
  if window then window:destroy() end
  window, actionButton, upgradeProgress = nil, nil, nil
  goldLabel, premiumLabel, ringProgressBar, creatureBox, itemSlotsPanel = nil, nil, nil, nil, nil
  rings, fills, rankIcons = {}, {}, {}
end

function tier.toggleTierWindow()
  if window and window:isVisible() then tier.closeTierWindow() else tier.openTierWindow() end
end
