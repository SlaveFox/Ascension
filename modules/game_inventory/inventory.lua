-- ==== Compat / Guards para slots extras e nomes ====
if not rawget(_G, 'InventorySlotExt1') then InventorySlotExt1 = 12 end
if not rawget(_G, 'InventorySlotExt2') then InventorySlotExt2 = 13 end
if not rawget(_G, 'InventorySlotPurse') then InventorySlotPurse = 11 end
if not rawget(_G, 'InventorySlotNeck') and rawget(_G, 'InventorySlotNecklace') then
  InventorySlotNeck = InventorySlotNecklace
end

Icons = {}
Icons[PlayerStates.Poison]     = { tooltip = tr('You are poisoned'), path = '/images/game/states/poisoned',            id = 'condition_poisoned' }
Icons[PlayerStates.Burn]       = { tooltip = tr('You are burning'),  path = '/images/game/states/burning',             id = 'condition_burning' }
Icons[PlayerStates.Energy]     = { tooltip = tr('You are electrified'), path = '/images/game/states/electrified',      id = 'condition_electrified' }
Icons[PlayerStates.Drunk]      = { tooltip = tr('You are drunk'),    path = '/images/game/states/drunk',               id = 'condition_drunk' }
Icons[PlayerStates.ManaShield] = { tooltip = tr('You are protected by a magic shield'), path = '/images/game/states/magic_shield', id = 'condition_magic_shield' }
Icons[PlayerStates.Paralyze]   = { tooltip = tr('You are paralysed'), path = '/images/game/states/slowed',              id = 'condition_slowed' }
Icons[PlayerStates.Haste]      = { tooltip = tr('You are hasted'),   path = '/images/game/states/haste',               id = 'condition_haste' }
Icons[PlayerStates.Swords]     = { tooltip = tr('You may not logout during a fight'), path = '/images/game/states/logout_block', id = 'condition_logout_block' }
Icons[PlayerStates.Drowning]   = { tooltip = tr('You are drowning'), path = '/images/game/states/drowning',             id = 'condition_drowning' }
Icons[PlayerStates.Freezing]   = { tooltip = tr('You are freezing'), path = '/images/game/states/freezing',             id = 'condition_freezing' }
Icons[PlayerStates.Dazzled]    = { tooltip = tr('You are dazzled'),  path = '/images/game/states/dazzled',              id = 'condition_dazzled' }
Icons[PlayerStates.Cursed]     = { tooltip = tr('You are cursed'),   path = '/images/game/states/cursed',               id = 'condition_cursed' }
Icons[PlayerStates.PartyBuff]  = { tooltip = tr('You are strengthened'), path = '/images/game/states/strengthened',     id = 'condition_strengthened' }
Icons[PlayerStates.PzBlock]    = { tooltip = tr('You may not logout or enter a protection zone'), path = '/images/game/states/protection_zone_block', id = 'condition_protection_zone_block' }
Icons[PlayerStates.Pz]         = { tooltip = tr('You are within a protection zone'), path = '/images/game/states/protection_zone', id = 'condition_protection_zone' }
Icons[PlayerStates.Bleeding]   = { tooltip = tr('You are bleeding'), path = '/images/game/states/bleeding',             id = 'condition_bleeding' }
Icons[PlayerStates.Hungry]     = { tooltip = tr('You are hungry'),   path = '/images/game/states/hungry',               id = 'condition_hungry' }
Icons[PlayerStates.Invisible]  = { tooltip = tr('You are invisible'), path = '/images/game/states/invisible',           id = 'condition_invisible' }

-- Mapeia extras do client para nomes semânticos
local InventorySlotRing2 = InventorySlotExt1 -- 12
local InventorySlotGem   = InventorySlotExt2 -- 13

InventorySlotStyles = {
  [InventorySlotHead]   = "HeadSlot",
  [InventorySlotNeck]   = "NeckSlot",
  [InventorySlotBack]   = "BackSlot",
  [InventorySlotBody]   = "BodySlot",
  [InventorySlotRight]  = "RightSlot",
  [InventorySlotLeft]   = "LeftSlot",
  [InventorySlotLeg]    = "LegSlot",
  [InventorySlotFeet]   = "FeetSlot",
  [InventorySlotFinger] = "FingerSlot",
  [InventorySlotAmmo]   = "AmmoSlot",
  [InventorySlotRing2]  = "Finger2Slot", -- OTUI id: slot12
  [InventorySlotGem]    = "GemSlot"      -- OTUI id: slot13
}

local EXTRA_SLOTS = { InventorySlotRing2, InventorySlotGem }

inventoryWindow = nil
inventoryPanel = nil
inventoryButton = nil
purseButton = nil

combatControlsWindow = nil
fightOffensiveBox = nil
fightBalancedBox = nil
fightDefensiveBox = nil
chaseModeButton = nil
safeFightButton = nil
mountButton = nil
fightModeRadioGroup = nil
buttonPvp = nil

soulLabel = nil
capLabel = nil
conditionPanel = nil
moreButton = nil
extraButtonsPanel = nil
isExpanded = false

function init()
  connect(LocalPlayer, {
    onInventoryChange = onInventoryChange,
    onBlessingsChange = onBlessingsChange
  })
  connect(g_game, { onGameStart = refresh })

  g_keyboard.bindKeyDown('Ctrl+I', toggle)

  inventoryWindow = g_ui.loadUI('inventory', modules.game_interface.getRightPanel())
  inventoryWindow:disableResize()
  inventoryPanel = inventoryWindow:getChildById('contentsPanel'):getChildById('inventoryPanel')
  if not inventoryWindow.forceOpen then
    inventoryButton = modules.client_topmenu.addRightGameToggleButton('inventoryButton', tr('Inventory') .. ' (Ctrl+I)', '/images/topbuttons/inventory', toggle)
    inventoryButton:setOn(true)
  end
  
  purseButton = inventoryWindow:recursiveGetChildById('purseButton')
  if purseButton then
    purseButton.onClick = function()
      local purse = g_game.getLocalPlayer():getInventoryItem(InventorySlotPurse)
      if purse then g_game.use(purse) end
    end
  end
  
  fightOffensiveBox = inventoryWindow:recursiveGetChildById('fightOffensiveBox')
  fightBalancedBox  = inventoryWindow:recursiveGetChildById('fightBalancedBox')
  fightDefensiveBox = inventoryWindow:recursiveGetChildById('fightDefensiveBox')

  chaseModeButton = inventoryWindow:recursiveGetChildById('chaseModeBox')
  safeFightButton = inventoryWindow:recursiveGetChildById('safeFightBox')
  buttonPvp       = inventoryWindow:recursiveGetChildById('buttonPvp')

  mountButton = inventoryWindow:recursiveGetChildById('mountButton')
  if mountButton then mountButton.onClick = onMountButtonClick end

  whiteDoveBox  = inventoryWindow:recursiveGetChildById('whiteDoveBox')
  whiteHandBox  = inventoryWindow:recursiveGetChildById('whiteHandBox')
  yellowHandBox = inventoryWindow:recursiveGetChildById('yellowHandBox')
  redFistBox    = inventoryWindow:recursiveGetChildById('redFistBox')

  fightModeRadioGroup = UIRadioGroup.create()
  fightModeRadioGroup:addWidget(fightOffensiveBox)
  fightModeRadioGroup:addWidget(fightBalancedBox)
  fightModeRadioGroup:addWidget(fightDefensiveBox)

  connect(fightModeRadioGroup, { onSelectionChange = onSetFightMode })
  connect(chaseModeButton,     { onCheckChange     = onSetChaseMode })
  connect(safeFightButton,     { onCheckChange     = onSetSafeFight })
  if buttonPvp then connect(buttonPvp, { onClick = onSetSafeFight2 }) end

  connect(g_game, {
    onGameStart       = online,
    onGameEnd         = offline,
    onFightModeChange = update,
    onChaseModeChange = update,
    onSafeFightChange = update,
    onPVPModeChange   = update,
    onWalk            = check,
    onAutoWalk        = check
  })

  connect(LocalPlayer, { onOutfitChange = onOutfitChange })

  if g_game.isOnline() then online() end

  soulLabel      = inventoryWindow:recursiveGetChildById('soulLabel')
  capLabel       = inventoryWindow:recursiveGetChildById('capLabel')
  conditionPanel = inventoryWindow:recursiveGetChildById('conditionPanel')
  moreButton     = inventoryWindow:recursiveGetChildById('moreButton')
  extraButtonsPanel = inventoryWindow:recursiveGetChildById('extraButtonsPanel')

  if moreButton then
    moreButton.onClick = onMoreButtonClick
  end
  
  -- Configurar botões extras
  local extraButton1 = inventoryWindow:recursiveGetChildById('extraButton1')
  if extraButton1 then
    extraButton1:setTooltip(tr('Boss Tracker'))
    extraButton1.onClick = function()
      if BossTracker then
        BossTracker.toggle()
      end
    end
  end
  
  local extraButton2 = inventoryWindow:recursiveGetChildById('extraButton2')
  if extraButton2 then
    extraButton2:setTooltip(tr('Bestiary Tracker'))
    extraButton2.onClick = function()
      if _G.toggleTracker then
        _G.toggleTracker()
      elseif _G.G_BESTIARY and _G.G_BESTIARY.Tracker and _G.G_BESTIARY.Tracker.UI then
        if _G.G_BESTIARY.Tracker.UI:isVisible() then
          _G.G_BESTIARY.Tracker.UI:close()
        else
          _G.G_BESTIARY.Tracker.UI:open()
        end
      end
    end
  end
  
  local extraButton3 = inventoryWindow:recursiveGetChildById('extraButton3')
  if extraButton3 then
    extraButton3:setTooltip(tr('Health Info'))
    extraButton3.onClick = function()
      if modules.game_healthinfo and modules.game_healthinfo.toggle then
        modules.game_healthinfo.toggle()
      end
    end
  end
  
  local extraButton4 = inventoryWindow:recursiveGetChildById('extraButton4')
  if extraButton4 then
    extraButton4:setTooltip(tr('PvP Arena'))
    extraButton4.onClick = function()
      if _G.pvp and _G.pvp.toggle then
        _G.pvp.toggle()
      end
    end
  end

  connect(LocalPlayer, {
    onStatesChange       = onStatesChange,
    onSoulChange         = onSoulChange,
    onFreeCapacityChange = onFreeCapacityChange
  })

  refresh()
  inventoryWindow:setup()
end

function terminate()
  disconnect(LocalPlayer, {
    onInventoryChange = onInventoryChange,
    onBlessingsChange = onBlessingsChange
  })
  disconnect(g_game, { onGameStart = refresh })

  g_keyboard.unbindKeyDown('Ctrl+I')

  if g_game.isOnline() then offline() end
  fightModeRadioGroup:destroy()
  
  disconnect(g_game, {
    onGameStart       = online,
    onGameEnd         = offline,
    onFightModeChange = update,
    onChaseModeChange = update,
    onSafeFightChange = update,
    onPVPModeChange   = update,
    onWalk            = check,
    onAutoWalk        = check
  })

  disconnect(LocalPlayer, { onOutfitChange = onOutfitChange })
  disconnect(LocalPlayer, {
    onStatesChange       = onStatesChange,
    onSoulChange         = onSoulChange,
    onFreeCapacityChange = onFreeCapacityChange
  })

  inventoryWindow:destroy()
  if inventoryButton then inventoryButton:destroy() end
end

function toggleAdventurerStyle(hasBlessing)
  for slot = InventorySlotFirst, (rawget(_G,'InventorySlotLast') or InventorySlotPurse) do
    local w = inventoryPanel:getChildById('slot' .. slot)
    if w then w:setOn(hasBlessing) end
  end
  for _, slot in ipairs(EXTRA_SLOTS) do
    local w = inventoryPanel:getChildById('slot' .. slot)
    if w then w:setOn(hasBlessing) end
  end
end

function refresh()
  local player = g_game.getLocalPlayer()

  for i = InventorySlotFirst, InventorySlotPurse do
    if g_game.isOnline() then
      onInventoryChange(player, i, player:getInventoryItem(i))
    else
      onInventoryChange(player, i, nil)
    end
  end

  for _, slot in ipairs(EXTRA_SLOTS) do
    onInventoryChange(player, slot, (g_game.isOnline() and player:getInventoryItem(slot) or nil))
  end

  toggleAdventurerStyle(player and Bit.hasBit(player:getBlessings(), Blessings.Adventurer) or false)

  if player then
    onSoulChange(player, player:getSoul())
    onFreeCapacityChange(player, player:getFreeCapacity())
    onStatesChange(player, player:getStates(), 0)
  end

  if purseButton then purseButton:setVisible(g_game.getFeature(GamePurseSlot)) end
end

function toggle()
  if not inventoryButton then return end
  if inventoryButton:isOn() then
    inventoryWindow:close()
    inventoryButton:setOn(false)
  else
    inventoryWindow:open()
    inventoryButton:setOn(true)
  end
end

function onMiniWindowClose()
  if not inventoryButton then return end
  inventoryButton:setOn(false)
end

local function applyEpicShader(itemWidget)
  local it = itemWidget:getItem()
  if not it then return end
  local firstLine = it:getTooltip():match("([^\r\n]+)") or ""
  local baseName  = firstLine:match("^(.-)%s*%(") or firstLine
  local suffix    = baseName:match("(%+%d+)$")
  if suffix then
    local n = tonumber(suffix:sub(2))
    if n and n >= 1 and n <= 12 then
      it:setShader(suffix)
      return
    end
  end
  it:setShader(nil)
end

local function isExtraSlot(slot)
  local result = slot == InventorySlotRing2 or slot == InventorySlotGem
  return result
end

-- hooked events
function onInventoryChange(player, slot, item, oldItem)
  if slot > InventorySlotPurse and not isExtraSlot(slot) then 
    return 
  end
  if slot == InventorySlotPurse then 
    return 
  end

  local itemWidget = inventoryPanel:getChildById('slot' .. slot)
  if not itemWidget then 
    return 
  end

  if item then
    itemWidget:setStyle('InventoryItem')
    itemWidget:setItem(item)
    applyEpicShader(itemWidget)
  else
    itemWidget:setStyle(InventorySlotStyles[slot])
    itemWidget:setItem(nil)
  end
end

function onBlessingsChange(player, blessings, oldBlessings)
  local hasAdventurerBlessing = Bit.hasBit(blessings, Blessings.Adventurer)
  if hasAdventurerBlessing ~= Bit.hasBit(oldBlessings, Blessings.Adventurer) then
    toggleAdventurerStyle(hasAdventurerBlessing)
  end
end

-- controls
function update()
  local fightMode = g_game.getFightMode()
  if fightMode == FightOffensive then
    fightModeRadioGroup:selectWidget(fightOffensiveBox)
  elseif fightMode == FightBalanced then
    fightModeRadioGroup:selectWidget(fightBalancedBox)
  else
    fightModeRadioGroup:selectWidget(fightDefensiveBox)
  end

  local chaseMode = g_game.getChaseMode()
  chaseModeButton:setChecked(chaseMode == ChaseOpponent)

  local safeFight = g_game.isSafeFight()
  safeFightButton:setChecked(not safeFight)
  if buttonPvp then buttonPvp:setOn(not safeFight) end

  if g_game.getFeature(GamePVPMode) then
    local pvpMode = g_game.getPVPMode()
    local pvpWidget = getPVPBoxByMode(pvpMode)
  end
end

function check()
  if modules.client_options.getOption('autoChaseOverride') then
    if g_game.isAttacking() and g_game.getChaseMode() == ChaseOpponent then
      g_game.setChaseMode(DontChase)
    end
  end
end

function online()
  local player = g_game.getLocalPlayer()
  if player then
    local char = g_game.getCharacterName()
    local lastCombatControls = g_settings.getNode('LastCombatControls')

    if not table.empty(lastCombatControls) and lastCombatControls[char] then
      g_game.setFightMode(lastCombatControls[char].fightMode)
      g_game.setChaseMode(lastCombatControls[char].chaseMode)
      g_game.setSafeFight(lastCombatControls[char].safeFight)
      if lastCombatControls[char].pvpMode then
        g_game.setPVPMode(lastCombatControls[char].pvpMode)
      end
    end

    if g_game.getFeature(GamePlayerMounts) then
      if mountButton then
        mountButton:setVisible(true)
        mountButton:setChecked(player:isMounted())
      end
    else
      if mountButton then mountButton:setVisible(false) end
    end
  end

  update()
end

function offline()
  local lastCombatControls = g_settings.getNode('LastCombatControls') or {}

  if conditionPanel then conditionPanel:destroyChildren() end

  local player = g_game.getLocalPlayer()
  if player then
    local char = g_game.getCharacterName()
    lastCombatControls[char] = {
      fightMode = g_game.getFightMode(),
      chaseMode = g_game.getChaseMode(),
      safeFight = g_game.isSafeFight()
    }
    if g_game.getFeature(GamePVPMode) then
      lastCombatControls[char].pvpMode = g_game.getPVPMode()
    end
    g_settings.setNode('LastCombatControls', lastCombatControls)
  end
end

function onSetFightMode(self, selectedFightButton)
  if not selectedFightButton then return end
  local id = selectedFightButton:getId()
  local mode = (id == 'fightOffensiveBox' and FightOffensive) or
               (id == 'fightBalancedBox' and FightBalanced) or
               FightDefensive
  g_game.setFightMode(mode)
end

function onSetChaseMode(self, checked)
  g_game.setChaseMode(checked and ChaseOpponent or DontChase)
end

function onSetSafeFight(self, checked)
  g_game.setSafeFight(not checked)
  if buttonPvp then buttonPvp:setOn(checked) end
end

function onSetSafeFight2(self)
  onSetSafeFight(self, not safeFightButton:isChecked())
end

function onSetPVPMode(self, selectedPVPButton)
  if not selectedPVPButton then return end
  local id = selectedPVPButton:getId()
  local mode = PVPWhiteDove
  if id == 'whiteHandBox'  then mode = PVPWhiteHand
  elseif id == 'yellowHandBox' then mode = PVPYellowHand
  elseif id == 'redFistBox'    then mode = PVPRedFist
  end
  g_game.setPVPMode(mode)
end

function onMountButtonClick(self, mousePos)
  local player = g_game.getLocalPlayer()
  if player then player:toggleMount() end
end

function onOutfitChange(localPlayer, outfit, oldOutfit)
  if outfit.mount == oldOutfit.mount then return end
  if mountButton then mountButton:setChecked(outfit.mount ~= nil and outfit.mount > 0) end
end

function getPVPBoxByMode(mode)
  local w = nil
  if     mode == PVPWhiteDove  then w = whiteDoveBox
  elseif mode == PVPWhiteHand  then w = whiteHandBox
  elseif mode == PVPYellowHand then w = yellowHandBox
  elseif mode == PVPRedFist    then w = redFistBox
  end
  return w
end

-- status
function toggleIcon(bitChanged)
  local cfg = Icons[bitChanged]
  if not cfg then return end
  local icon = conditionPanel and conditionPanel:getChildById(cfg.id)
  if icon then
    icon:destroy()
  else
    icon = g_ui.createWidget('ConditionWidget', conditionPanel)
    icon:setId(cfg.id)
    icon:setImageSource(cfg.path)
    icon:setTooltip(cfg.tooltip)
  end
end

function onSoulChange(localPlayer, soul)
  if not soul then return end
  soulLabel:setText(tr('Soul') .. ':\n' .. soul)
end

function onFreeCapacityChange(player, freeCapacity)
  if not freeCapacity then return end
  if freeCapacity > 99    then freeCapacity = math.floor(freeCapacity * 10) / 10 end
  if freeCapacity > 999   then freeCapacity = math.floor(freeCapacity) end
  if freeCapacity > 99999 then freeCapacity = math.min(9999, math.floor(freeCapacity/1000)) .. "k" end
  capLabel:setText(tr('Cap') .. ':\n' .. freeCapacity)
end

function onStatesChange(localPlayer, now, old)
  if now == old then return end
  local bitsChanged = bit32.bxor(now, old)
  for i = 1, 32 do
    local pow = math.pow(2, i-1)
    if pow > bitsChanged then break end
    local bitChanged = bit32.band(bitsChanged, pow)
    if bitChanged ~= 0 then toggleIcon(bitChanged) end
  end
end

function onMoreButtonClick()
  if not extraButtonsPanel or not inventoryWindow then
    return
  end
  
  isExpanded = not isExpanded
  
  if isExpanded then
    extraButtonsPanel:setVisible(true)
    inventoryWindow:setHeight(250)
    if moreButton then
      moreButton:setText(tr('Less'))
    end
  else
    extraButtonsPanel:setVisible(false)
    inventoryWindow:setHeight(220)
    if moreButton then
      moreButton:setText(tr('More'))
    end
  end
end
