-- ===========================================
-- PREY SYSTEM (UI enxuto)
-- ===========================================
Prey = {}

local getSlot, applyAffordability
local currentPreyCards, currentCashGold, currentBankGold, currentGoldTotal = 0,0,0,0
local preyKeyBind, window, preyTracker = nil, nil, nil
local allMonsters, monsterLookTypeCache = {}, {}
local selectedListLabelBySlot = {}
local OPCODE = 206

local slotMonsters = { preySlot1 = {}, preySlot2 = {}, preySlot3 = {} }
local selectedOutfit = {
  preySlot1 = { widget = nil, monster = nil },
  preySlot2 = { widget = nil, monster = nil },
  preySlot3 = { widget = nil, monster = nil }
}
local clientSlots = { preySlot1 = {}, preySlot2 = {}, preySlot3 = {} }

function getSlot(id) return window and window:recursiveGetChildById(id) end

-- -------- helpers básicos --------
local function setLabelAffordable(w, ok)
  if not w then return end
  local inner = w.getChildById and w:getChildById("text") or w
  if inner and inner.setColor then inner:setColor(ok and "#CCCCCC" or "#FF6666") end
end

local function setEnabledSafe(w, en, tip)
  if w and w.setEnabled then w:setEnabled(en) end
  if w and (not en) and tip then w:setTooltip(tip) end
end

local function setTextSafe(target, txt)
  if not target then return end
  local lbl = type(target) == "userdata" and target:getChildById("text") or (window and window:recursiveGetChildById(target))
  if lbl and lbl.setText then lbl:setText(tostring(txt or "")) end
end

local function setImageSafe(w, src) if w and w.setImageSource then w:setImageSource(src) end end
local function formatCooldown(sec) if not sec or sec<=0 then return "Free" end local h=math.floor(sec/3600) local m=math.floor((sec%3600)/60) return string.format("%02d:%02d",h,m) end
local function findUpToSlot(w) while w and not (w.getId and w:getId():match("^preySlot%d$")) do w = w:getParent() end; return w end
local function getLookTypeFor(name)
  if not name or name=="" then return 0 end
  if monsterLookTypeCache[name] then return monsterLookTypeCache[name] end
  local lt = 0
  if g_things.getCreatureOutfitByName then
    local info = g_things.getCreatureOutfitByName(name); if info and info.type then lt = info.type end
  end
  monsterLookTypeCache[name] = lt; return lt
end
local function setOutfitSafe(box, name, fallback)
  if not box then return end
  local lt = fallback or getLookTypeFor(name) or 0
  box:setOutfit({ type = lt }); box:setAnimate(true); box:setCenter(true); box:setTooltip(name)
end

-- -------- affordability --------
applyAffordability = function(slotId)
  local root = getSlot(slotId); if not root then return end
  local costs = clientSlots[slotId] or {}

  -- Reroll lista (gold)
  do
    local costGold = tonumber(costs.cost or 0) or 0
    local bottom = root:recursiveGetChildById("bonusGoldBottom")
    local topHit = root:recursiveGetChildById("bonusGoldTopPanel") or root:recursiveGetChildById("bonusGoldTopValue")
    local ok = (costGold <= 0) or (currentGoldTotal >= costGold)
    setLabelAffordable(bottom, ok)
    if topHit then setEnabledSafe(topHit, ok, "Not enough gold") end
  end
  -- Reroll bônus (cards)
  do
    local cost = tonumber(costs.bonusCost or 1) or 1
    setLabelAffordable(root:recursiveGetChildById("bonusCardReroll"), currentPreyCards >= cost)
    setEnabledSafe(root:recursiveGetChildById("bonusReroll"), currentPreyCards >= cost, "Not enough Prey Cards")
  end
  -- Select Creature (cards)
  do
    local cost = tonumber(costs.selectCost or 5) or 5
    setLabelAffordable(root:recursiveGetChildById("selectCreatureReroll"), currentPreyCards >= cost)
    setEnabledSafe(root:recursiveGetChildById("selectCreature"), currentPreyCards >= cost, "Not enough Prey Cards")
  end
  -- Auto
  do
    local cost = tonumber(costs.autoCost or 1) or 1
    local lbl  = root:recursiveGetChildById("checkboxCard1Left")
    local box  = root:recursiveGetChildById("automaticBonusReroll")
    local ok   = currentPreyCards >= cost
    setLabelAffordable(lbl, ok)
    if box then setEnabledSafe(box, box:isChecked() or ok, "Not enough Prey Cards") end
  end
  -- Lock
  do
    local cost = tonumber(costs.lockCost or 1) or 1
    local lbl  = root:recursiveGetChildById("checkboxCard2Left")
    local box  = root:recursiveGetChildById("lockPrey")
    local ok   = currentPreyCards >= cost
    setLabelAffordable(lbl, ok)
    if box then setEnabledSafe(box, box:isChecked() or ok, "Not enough Prey Cards") end
  end
end

local function reapplyAllAffordability()
  applyAffordability("preySlot1"); applyAffordability("preySlot2"); applyAffordability("preySlot3")
end

-- -------- UI bits --------
local function resetOutfitBorder(w) if w and not w:isDestroyed() then w:setBorderColor("alpha") end end
local function setSelectedBorder(w)
  if not w or w:isDestroyed() then return end
  w:setBorderColorBottom("#6e6e6e"); w:setBorderColorRight("#6e6e6e"); w:setBorderColorTop("#222222"); w:setBorderColorLeft("#222222")
end

local function generateStars(panel, step)
  if not panel then return end
  step = step or 0; panel:destroyChildren()
  for i=1,10 do
    local star = g_ui.createWidget('UIButton', panel); star:setId("star"..i)
    setImageSafe(star, i<=step and "prey/prey_star" or "prey/prey_nostar")
    star:setSize({width=10, height=10}); star:setPhantom(true)
  end
end

local BONUS_ICONS = {
  [1]="prey/prey_bigdamage",[2]="prey/prey_bigdefense",[3]="prey/prey_bigxp",[4]="prey/prey_bigloot"
}

-- Constantes de bônus (baseado no sistema de inspiração)
local PREY_BONUS_DAMAGE_BOOST = 0
local PREY_BONUS_DAMAGE_REDUCTION = 1
local PREY_BONUS_XP_BONUS = 2
local PREY_BONUS_IMPROVED_LOOT = 3
local PREY_BONUS_NONE = 4

local function updateChooseButtonIcon(slotId)
  local slot = getSlot(slotId); if not slot then return end
  local btn = slot:recursiveGetChildById("bonusButton"); if not btn then return end
  local has = selectedOutfit[slotId] and selectedOutfit[slotId].monster
  btn:setIcon(has and "prey/prey_choose" or "prey/prey_choose_gray")
end

-- -------- renderers --------
local function renderSelectionGrid(slotId, list)
  local slot = getSlot(slotId); if not slot then return end
  local panel = slot:recursiveGetChildById('outfitGridPanel'); if not panel then return end
  panel:destroyChildren(); if not list or #list==0 then return end
  for i, m in ipairs(list) do
    local outfit = g_ui.createWidget("CreatureOutfitSelection", panel)
    outfit:setId(slotId.."_outfit"..i); outfit:setTooltip(m.name or "Unknown")
    local box = outfit:getChildById("outfitBox"); if box then setOutfitSafe(box, m.name or "Unknown", (m.outfit and m.outfit.lookType) or 0) end
    outfit.onClick = function(w) Prey.onSelectCreature(w) end
  end
end

local function renderCostCooldown(slotWidget, slotData)
  if not slotWidget or not slotData then return end
  local slotId = slotWidget:getId() or ""
  local top = slotWidget:recursiveGetChildById("bonusGoldTopValue")
  if top then
    local label = top:getChildById("text"); if label then label:setText(formatCooldown(slotData.cooldown)) end
  end
  setTextSafe(slotWidget:recursiveGetChildById("bonusGoldBottom"), slotData.cost or 0)
  setTextSafe(slotWidget:recursiveGetChildById("bonusCardReroll"),    (clientSlots[slotId] and clientSlots[slotId].bonusCost)  or slotData.bonusCost  or 1)
  setTextSafe(slotWidget:recursiveGetChildById("selectCreatureReroll"),(clientSlots[slotId] and clientSlots[slotId].selectCost) or slotData.selectCost or 0)
  setTextSafe(slotWidget:recursiveGetChildById("checkboxCard1Left"),  (clientSlots[slotId] and clientSlots[slotId].autoCost)   or slotData.autoCost   or 1)
  setTextSafe(slotWidget:recursiveGetChildById("checkboxCard2Left"),  (clientSlots[slotId] and clientSlots[slotId].lockCost)   or slotData.lockCost   or 1)
end

local function renderActiveInfo(slotId, info)
  local slot = getSlot(slotId); if not slot then return end

  do
    local title = info.monster or "Prey Slot"
    local children = slot.getChildren and slot:getChildren() or {}
    for i = #children, 1, -1 do
      local ch = children[i]
      if ch and ch.setText then ch:setText(title); break end
    end
  end

  local preview = slot:recursiveGetChildById("creaturePreview")
  if preview and (info.monster or (info.outfit and info.outfit.lookType)) then
    local box = preview:getChildById("outfitBoxActive")
    if box then
      setOutfitSafe(box, info.monster or "Unknown", (info.outfit and info.outfit.lookType) or 0)
    end
  end

  local banner = slot:recursiveGetChildById("bannerImage")
  if banner then
    setImageSafe(banner, BONUS_ICONS[info.bonusType] or "prey/prey_bignobonus")
  end

  if info.step then
    generateStars(slot:recursiveGetChildById("leftPanelStar"),  info.step)
    generateStars(slot:recursiveGetChildById("rightPanelStar"), info.step)
  end

  if info.timeLeft and info.totalDuration and info.active then
    local panel = slot:recursiveGetChildById('preyProgressContainer')
    if panel then
      panel:setVisible(true)
      local bar   = panel:recursiveGetChildById('preyProgressBar')
      local label = panel:recursiveGetChildById('preyProgressLabel')
      if bar and label then
        local rem = math.max(0, info.timeLeft)
        local dur = math.max(1, info.totalDuration)
        local pct = math.max(1, math.floor((rem / dur) * 100))
        bar:setPercent(pct)
        label:setText(string.format("%dh %dm remaining", math.floor(rem / 3600), math.floor((rem % 3600) / 60)))
        bar:setBackgroundColor(pct >= 50 and "#00cc00" or (pct >= 11 and "#ffcc00" or "#ff0000"))
      end
    end
  end
end

local function bindActiveActions(slotId, activePanel)
  if not activePanel then return end
  local goldTop = activePanel:recursiveGetChildById("bonusGoldTopPanel")
  if goldTop then
    local target = goldTop:recursiveGetChildById("bonusGoldTopValue") or goldTop
    target.onClick = function()
      local c = clientSlots[slotId] or {}; local costGold = tonumber(c.cost or 0) or 0
      if costGold>0 and currentGoldTotal < costGold then return end
      Prey.startMonsterReroll(slotId)
    end
  end
  local bonusBtn = activePanel:recursiveGetChildById("bonusReroll")
  if bonusBtn then
    bonusBtn.onClick = function()
      local c = clientSlots[slotId] or {}; local cost = tonumber(c.bonusCost or 1) or 1
      if currentPreyCards < cost then return end
      Prey.onClickRerollBonus(activePanel)
    end
  end
  local selectBtn = activePanel:recursiveGetChildById("selectCreature")
  if selectBtn then
    selectBtn.onClick = function()
      local c = clientSlots[slotId] or {}; local cost = tonumber(c.selectCost or 0) or 0
      if currentPreyCards < cost then return end
      g_game.getProtocolGame():sendExtendedOpcode(OPCODE, json.encode({ action="select_creature", slot=slotId, ts=os.time() }))
    end
  end
  local autoBox = activePanel:recursiveGetChildById("automaticBonusReroll")
  if autoBox then
    autoBox:setEnabled(true); autoBox:setPhantom(false)
    autoBox.onCheckChange = function(_, checked)
      local cost = tonumber((clientSlots[slotId] or {}).autoCost or 1) or 1
      if checked and currentPreyCards < cost then autoBox:setChecked(false); return end
      g_game.getProtocolGame():sendExtendedOpcode(OPCODE, json.encode({ action="toggle_auto_bonus", slot=slotId, enabled=checked, ts=os.time() }))
    end
  end
  local lockBox = activePanel:recursiveGetChildById("lockPrey")
  if lockBox then
    lockBox:setEnabled(true); lockBox:setPhantom(false)
    lockBox.onCheckChange = function(_, checked)
      local cost = tonumber((clientSlots[slotId] or {}).lockCost or 1) or 1
      if checked and currentPreyCards < cost then lockBox:setChecked(false); return end
      g_game.getProtocolGame():sendExtendedOpcode(OPCODE, json.encode({ action="toggle_lock_prey", slot=slotId, enabled=checked, ts=os.time() }))
    end
  end
end

-- -------- Slot renderer (ativo/seleção/bloqueado) --------
function Prey.renderSlot(slotId, data)
  data = data or {}
  if data.info and data.info.monster then data.active = true end

  local cs = clientSlots[slotId] or {}
  clientSlots[slotId] = cs

  if data.cost       ~= nil then cs.cost       = data.cost       end
  if data.cooldown   ~= nil then cs.cooldown   = data.cooldown   end
  if data.bonusCost  ~= nil then cs.bonusCost  = data.bonusCost  end
  if data.selectCost ~= nil then cs.selectCost = data.selectCost end
  if data.autoCost   ~= nil then cs.autoCost   = data.autoCost   end
  if data.lockCost   ~= nil then cs.lockCost   = data.lockCost   end
  if data.locked     ~= nil then cs.locked     = data.locked     end
  if data.active     ~= nil then cs.active     = data.active     end
  if data.info       ~= nil then cs.info       = data.info       end
  if data.monsters   ~= nil then slotMonsters[slotId] = data.monsters end

  local slot = getSlot(slotId)
  if not slot then
    if preyTracker then Prey.updateTracker() end
    return
  end

  slot:destroyChildren()

  if cs.active and cs.info then
    local panel = g_ui.createWidget("PreyActivePanel", slot)
    renderActiveInfo(slotId, cs.info)
    renderCostCooldown(slot, cs)

    local autoBox = panel:recursiveGetChildById("automaticBonusReroll")
    if autoBox and data.autoEnabled ~= nil then autoBox:setChecked(data.autoEnabled and true or false) end
    local lockBox = panel:recursiveGetChildById("lockPrey")
    if lockBox and data.lockEnabled ~= nil then lockBox:setChecked(data.lockEnabled and true or false) end

    local choose = panel:recursiveGetChildById("bonusButton")
    if choose then choose.onClick = function() Prey.onChooseBonus(slotId) end end
    bindActiveActions(slotId, panel)

    local goldTop = panel:recursiveGetChildById("bonusGoldTopPanel")
    if goldTop then
      Prey.bindTooltip(goldTop, "Rerolla a lista usando gold (reseta o cooldown).")
      local v = goldTop:recursiveGetChildById("bonusGoldTopValue")
      if v then Prey.bindTooltip(v, "Rerolla a lista usando gold (reseta o cooldown).") end
    end
    local bonusBtn = panel:recursiveGetChildById("bonusReroll")
    if bonusBtn then
      local bc = tonumber(cs.bonusCost or 1) or 1
      Prey.bindTooltip(bonusBtn, string.format("Rerolla apenas o bônus (%d Prey Card%s).", bc, bc > 1 and "s" or ""))
    end
    local selectA = panel:recursiveGetChildById("selectCreature")
    if selectA then
      local sc = tonumber(cs.selectCost or 0) or 0
      Prey.bindTooltip(selectA, string.format("Escolher uma criatura específica (%d Prey Card%s).", sc, sc ~= 1 and "s" or ""))
    end
    if autoBox then
      local ac = tonumber(cs.autoCost or 1) or 1
      Prey.bindTooltip(autoBox, string.format("Auto Bonus Reroll ao avançar o step (%d Prey Card%s para ativar).", ac, ac > 1 and "s" or ""))
    end
    if lockBox then
      local lc = tonumber(cs.lockCost or 1) or 1
      Prey.bindTooltip(lockBox, string.format("Trava o bônus atual (%d Prey Card%s para ativar).", lc, lc > 1 and "s" or ""))
    end
    local chooseA = panel:recursiveGetChildById('bonusButton'); if chooseA then Prey.bindTooltip(chooseA, "Aplicar bônus na criatura selecionada.") end

    applyAffordability(slotId)

  elseif slotMonsters[slotId] and #slotMonsters[slotId] > 0 then
    local sel = g_ui.createWidget("PreySelectionPanel", slot)
    sel:setText("Select a creature")
    renderSelectionGrid(slotId, slotMonsters[slotId])
    generateStars(sel:recursiveGetChildById("leftPanelStar"), 0)
    generateStars(sel:recursiveGetChildById("rightPanelStar"), 0)

    local bb = sel:recursiveGetChildById('bonusButton')
    if bb then
      bb.onClick = function() Prey.onChooseBonus(slotId) end
      Prey.bindTooltip(bb, "Aplicar bônus na criatura selecionada.")
    end
    updateChooseButtonIcon(slotId)

    renderCostCooldown(slot, cs)

    local goldTopS = sel:recursiveGetChildById("bonusGoldTopPanel")
    if goldTopS then
      Prey.bindTooltip(goldTopS, "Rerolla a lista usando gold (reseta o cooldown).")
      local v = goldTopS:recursiveGetChildById("bonusGoldTopValue")
      if v then Prey.bindTooltip(v, "Rerolla a lista usando gold (reseta o cooldown).") end
    end
    local bonusBtnS = sel:recursiveGetChildById("bonusReroll")
    if bonusBtnS then
      local bc = tonumber(cs.bonusCost or 1) or 1
      Prey.bindTooltip(bonusBtnS, string.format("Rerolla apenas o bônus (%d Prey Card%s).", bc, bc > 1 and "s" or ""))
    end
    local selectS = sel:recursiveGetChildById("selectCreature")
    if selectS then
      local sc = tonumber(cs.selectCost or 0) or 0
      Prey.bindTooltip(selectS, string.format("Escolher uma criatura específica (%d Prey Card%s).", sc, sc ~= 1 and "s" or ""))
      selectS.onClick = function()
        local cost = tonumber((clientSlots[slotId] or {}).selectCost or sc) or 0
        if currentPreyCards < cost then return end
        g_game.getProtocolGame():sendExtendedOpcode(OPCODE, json.encode({
          action = "select_creature",
          slot   = slotId,
          ts     = os.time()
        }))
      end
    end

    applyAffordability(slotId)

  else
    local locked = g_ui.createWidget("PreyLockedPanel", slot)
    locked:setText("Locked Slot")
    local btn = locked:recursiveGetChildById("unlockButton"); if btn then btn.onClick = function() Prey.onUnlockSlot(slotId) end end
    local costLabel = locked:recursiveGetChildById("unlockCostLabel")
    if costLabel and Prey.unlockCosts and Prey.unlockCosts[slotId] then setTextSafe(costLabel, Prey.unlockCosts[slotId]) end
  end
end

-- -------- Ações --------
function Prey.onSelectCreature(w)
  if not w then return end
  local root = findUpToSlot(w); if not root then return end
  local slotId = root:getId()
  local cur = selectedOutfit[slotId]
  if cur and cur.widget == w then
    resetOutfitBorder(w); selectedOutfit[slotId] = { widget=nil, monster=nil }; updateChooseButtonIcon(slotId); return
  end
  if cur and cur.widget and not cur.widget:isDestroyed() then resetOutfitBorder(cur.widget) end
  local name = w:getTooltip() or "Unknown"
  selectedOutfit[slotId] = { widget=w, monster=name }; setSelectedBorder(w); updateChooseButtonIcon(slotId)
end

function Prey.onChooseBonus(slotId)
  local sel = selectedOutfit[slotId]; if not sel or not sel.monster then return end
  g_game.getProtocolGame():sendExtendedOpcode(OPCODE, json.encode({ action="choose_bonus", slot=slotId, monster=sel.monster, ts=os.time() }))
end

function Prey.onReroll(slotId) g_game.getProtocolGame():sendExtendedOpcode(OPCODE, json.encode({ action="reroll", slot=slotId, ts=os.time() })) end
function Prey.onClickReroll(w) local r=findUpToSlot(w); if not r then return end; Prey.onReroll(r:getId()) end
function Prey.onClickRerollBonus(w) local r=findUpToSlot(w); if not r then return end; g_game.getProtocolGame():sendExtendedOpcode(OPCODE, json.encode({ action="reroll_bonus", slot=r:getId(), ts=os.time() })) end

function Prey.startMonsterReroll(slotId)
  -- >>> add isto:
  local cs = clientSlots[slotId] or {}
  cs.active = false
  cs.info   = nil
  clientSlots[slotId] = cs
  -- <<<

  local slot = getSlot(slotId); if not slot then return end
  slot:destroyChildren()
  local sel = g_ui.createWidget("PreySelectionPanel", slot)
  local grid = sel:recursiveGetChildById('outfitGridPanel')
  if grid then local l=g_ui.createWidget('UILabel', grid); l:setText("Carregando novas criaturas..."); l:setPhantom(true) end
  selectedOutfit[slotId] = { widget=nil, monster=nil }
  local bb = sel:recursiveGetChildById('bonusButton'); if bb then bb.onClick=function() Prey.onChooseBonus(slotId) end end
  updateChooseButtonIcon(slotId); Prey.onReroll(slotId)
end


function Prey.onUnlockSlot(arg)
  local slotId
  if type(arg) == "string" then
    slotId = arg
  else
    local w = findUpToSlot(arg); slotId = w and w:getId() or nil
  end
  if not slotId or not slotId:match("^preySlot[23]$") then return end
  local cost = Prey.unlockCosts and Prey.unlockCosts[slotId]; if not cost then return end
  local box; box = displayGeneralBox("Confirmar Desbloqueio", string.format("Deseja desbloquear %s por %d Prey Cards?", slotId, cost),
    { {text="Sim", callback=function() g_game.getProtocolGame():sendExtendedOpcode(OPCODE, json.encode({ action="unlock_slot", slot=slotId, ts=os.time() })); if box then box:destroy() end end},
      {text="Não", callback=function() if box then box:destroy() end end} }, nil,nil,true)
end

-- -------- Monster picker --------
function Prey.openMonsterPicker(slotId)
  local slot = window and window:recursiveGetChildById(slotId); if not slot then return end
  slot:destroyChildren()
  local listPanel = g_ui.createWidget("PreyMonsterListPanel", slot)
  local chooseBtn = listPanel:recursiveGetChildById("bonusButton"); if chooseBtn then chooseBtn.onClick=function() Prey.onChooseBonus(slotId) end end

  local sel = selectedOutfit[slotId]
  if sel and sel.monster then
    local prev = window:recursiveGetChildById("outfitBoxPreview")
    if prev then local lt=getLookTypeFor(sel.monster); if lt==0 then lt=21 end; prev:setOutfit({type=lt}); prev:setTooltip(sel.monster); prev:setAnimate(true); prev:setCenter(true) end
  end
  Prey.populateMonsterList(); updateChooseButtonIcon(slotId)
end

function Prey.populateMonsterList(list)
  if type(list)=="table" then
    allMonsters = list
    for _,m in ipairs(allMonsters) do local name = m.name or m; if type(m)=="table" and m.outfit and m.outfit.lookType then monsterLookTypeCache[name]=m.outfit.lookType else getLookTypeFor(name) end end
  end
  local panel = window and window:recursiveGetChildById("monsterList"); if not panel then return end
  panel:destroyChildren(); selectedListLabelBySlot = {}
  for _, m in ipairs(allMonsters) do
    local name = m.name or m
    local lbl = g_ui.createWidget("UILabel", panel)
    lbl:setText(name); lbl:setColor("#CCCCCC"); lbl:setFont("verdana-11px-monochrome"); lbl:setTextAutoResize(true); lbl:setPhantom(false); lbl:setTooltip("Clique para selecionar "..name)
    lbl.onClick = function(w)
      local slotRoot = findUpToSlot(w) or (window and window:recursiveGetChildById("preySlot3")); local sid = (slotRoot and slotRoot:getId()) or "preySlot3"
      local prev = selectedListLabelBySlot[sid]; if prev and not prev:isDestroyed() then prev:setColor("#CCCCCC") end
      selectedListLabelBySlot[sid] = w; w:setColor("#FFFF66")
      local lt = getLookTypeFor(name); if lt==0 then lt=21 end
      local previewBox = window and window:recursiveGetChildById("outfitBoxPreview")
      if previewBox then previewBox:setOutfit({type=lt}); previewBox:setTooltip(name); previewBox:setAnimate(true); previewBox:setCenter(true) end
      selectedOutfit[sid] = { widget=w, monster=name }; updateChooseButtonIcon(sid)
    end
  end
end

function Prey.onSearchMonster(edit)
  local text = edit:getText():lower()
  local panel = window and window:recursiveGetChildById("monsterList"); if not panel then return end
  for _, child in ipairs(panel:getChildren()) do local name = child:getText():lower(); child:setVisible(text=="" or name:find(text,1,true)) end
end

-- -------- tooltips (texto no lowPanel) --------
local defaultLowPanelText = "Passe o mouse sobre um botão para ver a descrição."
local function setLowPanelText(t) if not window then return end local l = window:recursiveGetChildById("lowPanelLabel"); if l then l:setText(t or "") end end
function Prey.bindTooltip(w, text) if not w then return end w.onHoverChange=function(_,hov) setLowPanelText(hov and text or defaultLowPanelText) end end

-- -------- protocolo --------
local function handleServerPayload(data)
  if data.slots then for sid, sd in pairs(data.slots) do Prey.renderSlot(sid, sd) end end
  if data.allMonsters then Prey.populateMonsterList(data.allMonsters) end
  if data.unlockCosts then Prey.unlockCosts = { preySlot2 = tonumber(data.unlockCosts.preySlot2) or (Prey.unlockCosts and Prey.unlockCosts.preySlot2), preySlot3 = tonumber(data.unlockCosts.preySlot3) or (Prey.unlockCosts and Prey.unlockCosts.preySlot3) } end
if data.monsters and data.slot then
  local cs = clientSlots[data.slot] or {}
  Prey.renderSlot(data.slot, {
    active     = false,           -- <<< força modo seleção
    info       = nil,             -- <<< limpa info antiga
    monsters   = data.monsters,
    cost       = data.cost,
    cooldown   = data.cooldown,
    bonusCost  = (data.bonusCost~=nil)  and data.bonusCost  or cs.bonusCost,
    selectCost = (data.selectCost~=nil) and data.selectCost or cs.selectCost,
    autoCost   = (data.autoCost~=nil)   and data.autoCost   or cs.autoCost,
    lockCost   = (data.lockCost~=nil)   and data.lockCost   or cs.lockCost
  })
  selectedOutfit[data.slot] = { widget=nil, monster=nil }
  updateChooseButtonIcon(data.slot)
end

  if data.action=="choose_bonus" and data.slot and data.preyInfo then
    local slot = getSlot(data.slot); if slot then slot:destroyChildren(); g_ui.createWidget("PreyActivePanel", slot) end
    renderActiveInfo(data.slot, data.preyInfo)
    if data.slots and data.slots[data.slot] then renderCostCooldown(getSlot(data.slot), data.slots[data.slot]) end
    do
      local panel  = getSlot(data.slot)
      local autoBx = panel and panel:recursiveGetChildById("automaticBonusReroll")
      local lockBx = panel and panel:recursiveGetChildById("lockPrey")
      if autoBx then autoBx:setChecked(false) end
      if lockBx then lockBx:setChecked(false) end
      applyAffordability(data.slot)
    end
    bindActiveActions(data.slot, getSlot(data.slot))
  end
  if data.action=="reroll_bonus" and data.slot and data.preyInfo then renderActiveInfo(data.slot, data.preyInfo) end
  if data.action=="select_creature" and data.slot and data.ok and not data.monsters then Prey.openMonsterPicker(data.slot) end

  if data.slot2Enabled ~= nil then Prey.renderSlot("preySlot2", data.slot2Enabled and ((data.slots and data.slots.preySlot2) or { monsters=slotMonsters.preySlot2 }) or {}) end
  if data.slot3Enabled ~= nil then Prey.renderSlot("preySlot3", data.slot3Enabled and ((data.slots and data.slots.preySlot3) or { monsters=slotMonsters.preySlot3 }) or {}) end
  if data.action=="slot2_unlocked" and data.slot2Enabled then Prey.renderSlot("preySlot2", (data.slots and data.slots.preySlot2) or { monsters=slotMonsters.preySlot2 }) end
  if data.action=="slot3_unlocked" and data.slot3Enabled then Prey.renderSlot("preySlot3", (data.slots and data.slots.preySlot3) or { monsters=slotMonsters.preySlot3 }) end

  if data.action=="toggle_auto_bonus" and data.slot then
    local sw = getSlot(data.slot); if sw then local b=sw:recursiveGetChildById("automaticBonusReroll"); if b and data.enabled~=nil then b:setChecked(data.enabled and true or false) end end
  end
  if data.action=="toggle_lock_prey" and data.slot then
    local sw = getSlot(data.slot); if sw then local b=sw:recursiveGetChildById("lockPrey"); if b and data.enabled~=nil then b:setChecked(data.enabled and true or false) end end
  end

  if data.preyCard ~= nil then currentPreyCards = tonumber(data.preyCard) or 0; setTextSafe(window and window:recursiveGetChildById("preyCardLabel"), data.preyCard); reapplyAllAffordability() end
  if data.balance ~= nil or data.money ~= nil then
    currentBankGold = tonumber(data.balance or currentBankGold) or 0
    currentCashGold = tonumber(data.money   or currentCashGold) or 0
    currentGoldTotal = currentBankGold + currentCashGold
    local footer = window and window:recursiveGetChildById("footerLabel"); if footer then setTextSafe(footer, currentBankGold) end
    reapplyAllAffordability()
  end
  
  if preyTracker and preyTracker:isVisible() then
    Prey.updateTracker()
  end
end

-- -------- init/show --------
function Prey.init()
  ProtocolGame.registerExtendedOpcode(OPCODE, function(_,_,buf)
    local ok, data = pcall(json.decode, buf)
    if ok and data then handleServerPayload(data) end
  end)
  preyKeyBind = g_keyboard.bindKeyDown('Ctrl+Y', function() Prey.toggle() end)
  g_keyboard.bindKeyDown('Ctrl+Shift+Y', function() Prey.toggleTracker() end)

  connect(g_game, {
    onGameStart = function()
      Prey.requestData()
      if preyTracker then Prey.updateTracker() end
    end
  })

  _G.Prey = Prey
end

function Prey.terminate() 
  if window then window:destroy() end; window=nil
  if preyTracker then preyTracker:destroy() end; preyTracker=nil
end

function Prey.toggle() if window and window:isVisible() then window:hide() else Prey.show() end end
function Prey.show()
  if not window then window = g_ui.displayUI('prey') end
  Prey.renderSlot("preySlot1", { monsters = slotMonsters.preySlot1 })
  Prey.renderSlot("preySlot2", {})
  Prey.renderSlot("preySlot3", {})
  Prey.requestData()
  window:show(); window:raise(); window:focus()
end
function Prey.hide() if window then window:hide() end end

-- -------- PreyTracker functions --------
function Prey.showTracker()
  if not preyTracker then
    preyTracker = g_ui.displayUI('preytracker')
    if preyTracker then
      preyTracker:setParent(modules.game_interface.getRightPanel(), true)
      preyTracker:setup()
      preyTracker:setContentMaximumHeight(100)
      preyTracker:setContentMinimumHeight(47)
    end
  end
  if preyTracker then
    preyTracker:show()
    preyTracker:raise()
    if not ((clientSlots.preySlot1 and clientSlots.preySlot1.info) or
            (clientSlots.preySlot2 and clientSlots.preySlot2.info) or
            (clientSlots.preySlot3 and clientSlots.preySlot3.info)) then
      Prey.requestData()
    end
    Prey.updateTracker()
  end
end

function Prey.hideTracker()
  if preyTracker then preyTracker:hide() end
end

function Prey.toggleTracker()
  if preyTracker and preyTracker:isVisible() then
    Prey.hideTracker()
  else
    Prey.showTracker()
  end
end

function Prey.updateTracker()
  if not preyTracker then return end
  for i = 1, 3 do
    local slotId = "preySlot" .. i
    local slotIndex = i - 1
    Prey.updateTrackerSlot(slotIndex, slotId)
  end
end

function Prey.updateTrackerSlot(slot, slotId)
  if not preyTracker then return end
  
  local tracker = preyTracker.contentsPanel["slot" .. (slot + 1)]
  if not tracker then return end

  local slotData = clientSlots[slotId]
  tracker:show()
  
  if slotData and slotData.locked == true then
    tracker.creature:hide()
    tracker.noCreature:show()
    tracker.creatureName:setText("Locked")
    tracker.time:setPercent(0)
    tracker.preyType:setIcon("prey/prey_no_bonus")
    local tooltip = "Locked Prey Slot. \n\nClick in this window to open the prey dialog."
    for _, element in pairs({tracker.creatureName, tracker.creature, tracker.preyType, tracker.time}) do
      element:setTooltip(tooltip)
      element.onClick = function() Prey.show() end
    end
    return
  end
  
  if not slotData or not slotData.active or not slotData.info then
    tracker.creature:hide()
    tracker.noCreature:show()
    tracker.creatureName:setText("Inactive")
    tracker.time:setPercent(0)
    tracker.preyType:setIcon("prey/prey_no_bonus")
    local tooltip = "Inactive Prey. \n\nClick in this window to open the prey dialog."
    for _, element in pairs({tracker.creatureName, tracker.creature, tracker.preyType, tracker.time}) do
      element:setTooltip(tooltip)
      element.onClick = function() Prey.show() end
    end
    return
  end
  
  local info = slotData.info
  local creatureName = info.monster or "Unknown"
  
  tracker.noCreature:hide()
  local creatureWidget = tracker:recursiveGetChildById("creature")
  if not creatureWidget then return end
  
  creatureWidget:show()
  creatureWidget:setVisible(true)
  creatureWidget:setEnabled(true)
  tracker.creatureName:setText(creatureName)
  
  local appliedLT
  if info.outfit and info.outfit.lookType then
    appliedLT = tonumber(info.outfit.lookType)
  elseif info.outfit and info.outfit.type then
    appliedLT = tonumber(info.outfit.type)
  else
    appliedLT = tonumber(getLookTypeFor(creatureName)) or 0
  end
  if appliedLT == 0 then appliedLT = 21 end
  creatureWidget:setOutfit({ type = appliedLT })
  creatureWidget:setAnimate(true)
  creatureWidget:setCenter(true)

  local bonusIcon = Prey.getSmallIconPath(info.bonusType)
  if bonusIcon then tracker.preyType:setIcon(bonusIcon) else tracker.preyType:setIcon("prey/") end
  
  if info.timeLeft and info.totalDuration then
    local timeLeft = info.timeLeft
    local percent = (timeLeft / (2 * 60 * 60)) * 100
    tracker.time:setPercent(percent)
    
    local bonusDesc = Prey.getBonusDescription(info.bonusType) or "Unknown"
    local tooltip = string.format("Creature: %s\nDuration: %s\nGrade: %d/10\nType: %s\n\nClick in this window to open the prey dialog.",
      creatureName, 
      Prey.timeleftTranslation(timeLeft, true),
      info.step or 0,
      bonusDesc)
    
    for _, element in pairs({tracker.creatureName, tracker.creature, tracker.preyType, tracker.time}) do
      element:setTooltip(tooltip)
      element.onClick = function() Prey.show() end
    end
  end
end

-- Funções auxiliares para o tracker
function Prey.getSmallIconPath(bonusType)
  local path = "prey/"
  if bonusType == PREY_BONUS_DAMAGE_BOOST or bonusType == 1 then
    return path.."prey_damage"
  elseif bonusType == PREY_BONUS_DAMAGE_REDUCTION or bonusType == 2 then
    return path.."prey_defense"
  elseif bonusType == PREY_BONUS_XP_BONUS or bonusType == 3 then
    return path.."prey_xp"
  elseif bonusType == PREY_BONUS_IMPROVED_LOOT or bonusType == 4 then
    return path.."prey_loot"
  end
  return "prey/prey_no_bonus"
end

function Prey.getBonusDescription(bonusType)
  if bonusType == PREY_BONUS_DAMAGE_BOOST or bonusType == 1 then
    return "Damage Boost"
  elseif bonusType == PREY_BONUS_DAMAGE_REDUCTION or bonusType == 2 then
    return "Damage Reduction"
  elseif bonusType == PREY_BONUS_XP_BONUS or bonusType == 3 then
    return "XP Bonus"
  elseif bonusType == PREY_BONUS_IMPROVED_LOOT or bonusType == 4 then
    return "Improved Loot"
  end
  return "Unknown"
end

function Prey.timeleftTranslation(timeleft, forPreyTimeleft)
  if timeleft == 0 then
    if forPreyTimeleft then
      return "infinite bonus"
    end
    return "Free"
  end
  local hours = string.format("%02.f", math.floor(timeleft/3600))
  local mins = string.format("%02.f", math.floor(timeleft/60 - (hours*60)))
  return hours .. ":" .. mins
end

-- -------- server comm --------
function Prey.requestData() g_game.getProtocolGame():sendExtendedOpcode(OPCODE, json.encode({ action="open", ts=os.time() })) end
function Prey.openShop()
  if modules and modules.game_shop then
    if modules.game_shop.openShop then modules.game_shop.openShop('prey')
    elseif modules.game_shop.sendShopInfo then modules.game_shop.sendShopInfo(true) end
  else
    local OPEN_SHOP_OPCODE = 33; local ok,p = pcall(json.encode, {type="openShop"}); if ok then g_game.getProtocolGame():sendExtendedOpcode(OPEN_SHOP_OPCODE, p) end
  end
  Prey.hide()
end
