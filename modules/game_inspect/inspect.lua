local CLAN_OPCODE = 23
local Profile = false
local inspectWindow = nil
local playerName = nil
local sendShowItems = false

local IInventorySlotStyles = {
  [InventorySlotHead] = "HeadSlot",
  [InventorySlotNeck] = "NeckSlot",
  [InventorySlotBack] = "BackSlot",
  [InventorySlotBody] = "BodySlot",
  [InventorySlotRight] = "RightSlot",
  [InventorySlotLeft] = "LeftSlot",
  [InventorySlotLeg] = "LegSlot",
  [InventorySlotFeet] = "FeetSlot",
  [InventorySlotFinger] = "FingerSlot",
  [InventorySlotAmmo] = "AmmoSlot",
}

--=======================================
-- Inicialização
--=======================================
function init()
  connect(g_game, { onGameStart = create, onGameEnd = destroy })
  ProtocolGame.registerExtendedOpcode(CLAN_OPCODE, onReceiveInspectData)

  if g_game.isOnline() then
    create()
  end
end

function terminate()
  disconnect(g_game, { onGameStart = create, onGameEnd = destroy })
  ProtocolGame.unregisterExtendedOpcode(CLAN_OPCODE)
  destroy()
end

function create()
  inspectWindow = g_ui.displayUI("inspect")
  inspectWindow:hide()
end

function destroy()
  if inspectWindow then
    inspectWindow:destroy()
    inspectWindow = nil
  end
end

--=======================================
-- Receber dados do servidor
--=======================================
function onReceiveInspectData(protocol, opcode, buffer)
  local data = json.decode(buffer)
  local proto = data.protocol

  if proto == "item" then
    addItem(data.slot, data.item, data.name)
  elseif proto == "stats" then
    addStats(data.stats)
    sendShowItems = data.showItems
  elseif proto == "inspect" then
    addItem(data.slot, data.item, data.name)
    addStats(data.stats)
  end

  local accountPanel = inspectWindow:getChildById("Account")
  local showItemsCheckbox = inspectWindow:recursiveGetChildById("ShowItems")

  if playerName == g_game.getCharacterName() then
    accountPanel:setVisible(true)
    showItemsCheckbox:setVisible(true)
  else
    accountPanel:setVisible(false)
    showItemsCheckbox:setVisible(false)
  end
end

--=======================================
-- Solicitar inspeção
--=======================================
function inspect(creature)
  playerName = creature
  g_game.getProtocolGame():sendExtendedOpcode(CLAN_OPCODE, json.encode({ protocol = "inspect", playerName = creature }))
  toggle()
end

--=======================================
-- Atualizar Stats
--=======================================
function addStats(data)
  inspectWindow:setText(data.name .. " Infos")

  -- Classe e Tier
  local classWidget = inspectWindow:recursiveGetChildById("classId")
  if classWidget then classWidget:setText(data.className) end

  local tierStarWidget = inspectWindow:recursiveGetChildById("tierStar")
  if tierStarWidget then
    local starImage = (data.tierStar == 0) and "Prata.png" or (data.tierStar .. ".png")
    tierStarWidget:setImageSource("images/stars/" .. starImage)
  end

  -- Informações básicas
  for key, value in pairs(data) do
    local widget = inspectWindow:recursiveGetChildById(key)
    if widget then
      widget:setText(type(value) == "number" and comma_value(value) or value)
    end
  end

  updateProgress("healthBar", data.health, data.maxHealth)
  updateProgress("manaBar", data.mana, data.maxMana)

  -- Skills
  for i, skill in ipairs(data.skills) do
    local skillWidget = inspectWindow:recursiveGetChildById("skill" .. i)
    if skillWidget then
      local valueWidget = skillWidget:getChildById("value")
      valueWidget:setText(skill.total)

      if skill.bonus > 0 then
        valueWidget:setColor("#008b00")
        skillWidget:setTooltip("Skill: " .. (skill.total - skill.bonus) .. " \nBonus: " .. skill.bonus)
      else
        valueWidget:setColor("#bbbbbb")
        skillWidget:removeTooltip()
      end

      local percentWidget = skillWidget:getChildById("percent")
      percentWidget:setPercent(math.floor(skill.percent))
      percentWidget:setTooltip(tr("%s percent to go", 100 - skill.percent))
    end
  end

  -- Outras stats
  local extraStats = {
    {id = "textMagic", value = data.magic},
    {id = "stat1Text", value = data.criticalChange .. "%"},
    {id = "stat2Text", value = data.healthBonus .. "%"},
    {id = "stat3Text", value = data.manaBonus .. "%"},
    {id = "stat4Text", value = data.critDamage .. "%"},
    {id = "stat5Text", value = data.magicBonus .. "%"},
    {id = "stat6Text", value = data.damage .. "%"},
    {id = "stat7Text", value = data.defense .. "%"},
    {id = "stat8Text", value = data.lifeLeech .. "%"},
    {id = "stat9Text", value = data.manaLeech .. "%"},
    {id = "stat12Text", value = data.attackSpeed .. "%"},
    {id = "stat13Text", value = data.healthRegen .. "%"},
    {id = "stat14Text", value = data.manaRegen .. "%"},
  }

  for _, stat in ipairs(extraStats) do
    local statWidget = inspectWindow:recursiveGetChildById(stat.id)
    if statWidget then
      statWidget:setText(stat.value)
    end
  end

  -- Outfit
  local outfitBox = inspectWindow:recursiveGetChildById("outfitInspectBox")
  if outfitBox then
    outfitBox:setOutfit({type = data.outfit})
    if Profile then
      HTTP.downloadImage(data.imagem, function(path, err)
        if not err then outfitBox:setImageSource(path) end
      end)
    end
  end

  -- Últimas mortes
  updateDeathList(data.deaths)

  -- ShowItems toggle
  local showItemsButton = inspectWindow:recursiveGetChildById("ShowItems")
  showItemsButton:setChecked(not sendShowItems)
  showItemsButton.onClick = function()
    sendShowItems = not sendShowItems
    showItemsButton:setChecked(not sendShowItems)
    g_game.getProtocolGame():sendExtendedOpcode(CLAN_OPCODE, json.encode({ protocol = "showItem", isChecked = sendShowItems }))
  end
end

--=======================================
-- Atualizar Inventário
--=======================================
function addItem(slot, item, name)
  local inventoryPanel = inspectWindow:getChildById("inventoryPanel")
  local slotWidget = inventoryPanel:getChildById("slot" .. slot)
  
  if slotWidget then
    if item then
      slotWidget:setItemId(item)
      slotWidget:setStyle("InventoryItem")
      slotWidget:setTooltip(name)
    else
      slotWidget:setItem(nil)
      slotWidget:setStyle(IInventorySlotStyles[slot])
      slotWidget:setTooltip(nil)
    end
  end
end

--=======================================
-- Atualizar últimas mortes
--=======================================
function updateDeathList(deaths)
  local deathList = inspectWindow:recursiveGetChildById("deathScroll")
  deathList:destroyChildren()

  if deaths and #deaths > 0 then
    for _, deathText in ipairs(deaths) do
      local label = g_ui.createWidget("GameLabel", deathList)
      label:setText(deathText)
      label:setColor("#aaaaaa")
      label:setTextAutoResize(true)
      label:setWidth(deathList:getWidth() - 5)
      label:setTextWrap(true)
    end
  else
    local label = g_ui.createWidget("GameLabel", deathList)
    label:setText("Nenhuma morte recente.")
    label:setColor("#777777")
    label:setTextAutoResize(true)
  end
end

--=======================================
-- Utilitários
--=======================================
function updateProgress(widgetId, value, maxValue)
  local widget = inspectWindow:recursiveGetChildById(widgetId)
  if widget then
    widget:setText(value .. "/" .. maxValue)
    widget:setValue(value, 0, maxValue)
  end
end

function toggle()
  if not g_game.isOnline() then return end
  if inspectWindow:isVisible() then inspectWindow:hide() else inspectWindow:show() end
end

function show()
  if inspectWindow then inspectWindow:show() inspectWindow:raise() inspectWindow:focus() end
end

function hide()
  if inspectWindow then inspectWindow:hide() end
end
