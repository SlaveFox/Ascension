--------------------------------------------------------------------------------
-- forgeSystem.lua - Lado Cliente (OTClient)
-- Sistema de Forja otimizado e compactado
--------------------------------------------------------------------------------

forgeSystem = {}
local Forge = { OPCODE = 200 }

-- Estado e referências de UI
local forgePanel, equippedContainer, equippedScrollBar, selectedItemBox
local materialSlots, itemWidgets = {}, {}
local selectedMainItemId, selectedMaterialId, upgradeValueLabel = nil, nil, nil

forgeSystem.lastMaterials = nil
forgeSystem.selectedMaterialType = nil

-- Função auxiliar para obter widget
local function getWidget(id)
  return forgePanel and forgePanel:recursiveGetChildById(id)
end

--------------------------------------------------------------------------------
-- ExtendedOpcode Handler
--------------------------------------------------------------------------------
function Forge.onExtendedOpcode(protocol, opcode, buffer)
  if opcode ~= Forge.OPCODE then return end
  local status, data = pcall(json.decode, buffer)
  if not status or not data then
    print("[ForgeSystem] Erro ao decodificar JSON.")
    return
  end

  if data.action == "open" then
    forgeSystem.open()
  elseif data.action == "update" then
    forgeSystem.updateEquippedItems(data.equippedItems)
  elseif data.action == "close" then
    forgeSystem.close()
  elseif data.action == "forge_result" and upgradeValueLabel then
    upgradeValueLabel:setText(data.message)
    upgradeValueLabel:setColor(data.success and "#28A745" or "#FF0000")
    scheduleEvent(function()
      if upgradeValueLabel then
        upgradeValueLabel:setText("Escolha um material para ver os detalhes.")
        upgradeValueLabel:setColor("yellow")
      end
    end, 1500)
  end
end

--------------------------------------------------------------------------------
-- Atualiza quantidade de material e exibição
--------------------------------------------------------------------------------
function forgeSystem.updateMaterialQuantity(itemId, change)
  if not forgeSystem.lastMaterials then return end
  for _, m in ipairs(forgeSystem.lastMaterials) do
    if m.id == itemId then
      m.count = math.max(0, m.count + change)
      break
    end
  end
  forgeSystem.updateMaterials(forgeSystem.lastMaterials)
end

--------------------------------------------------------------------------------
-- Inicialização / Terminação
--------------------------------------------------------------------------------
function forgeSystem.init()
  local otuiPath = "/modules/game_forgeSystem/forgeSystem.otui"
  if not g_resources.fileExists(otuiPath) then return end

  forgePanel = g_ui.loadUI(otuiPath, modules.game_interface.getRootPanel())
  if not forgePanel then return end
  forgePanel:hide()

  equippedContainer = getWidget("equippedItemsContainer")
  equippedScrollBar = getWidget("equippedItemsScrollBar")
  selectedItemBox   = getWidget("selectedItemBox")
  forgePanel.mainItemBox = getWidget("mainItemBox")
  materialSlots[1] = getWidget("materialSlot1")
  materialSlots[2] = getWidget("materialSlot2")
  materialSlots[3] = getWidget("materialSlot3")
  upgradeValueLabel = getWidget("upgradeValueLabel")

  connect(LocalPlayer, {
    onPositionChange = CloseChange,
    onInventoryChange = CloseChange,
    onFreeCapacityChange = CloseChange
})
connect(Container, {
    onOpen = CloseChange,
    onClose = CloseChange,
    onUpdateItem = CloseChange,
    onAddItem = CloseChange,
    onRemoveItem = CloseChange
})

  pcall(function() ProtocolGame.unregisterExtendedOpcode(Forge.OPCODE) end)
  ProtocolGame.registerExtendedOpcode(Forge.OPCODE, Forge.onExtendedOpcode)

  g_keyboard.bindKeyDown("Escape", function()
    if forgePanel and forgePanel:isVisible() then forgeSystem.close() end
  end)

  local clearButton = getWidget("clearMainItemButton")
  if clearButton then clearButton.onClick = forgeSystem.clearMainItem end

  local sBoostCheckbox = getWidget("successBoostCheckbox")
  if sBoostCheckbox then sBoostCheckbox.onCheckChange = forgeSystem.onSuccessBoostToggled end

  local helpButton = getWidget("helpButton")
  if helpButton then
    helpButton:setTooltip(
      "Guia da Forja\n\n" ..
      "? Clique esquerdo em um item para selecioná-lo.\n" ..
      "? Clique direito em um material para removê-lo.\n" ..
      "? Use o botão no canto superior para limpar o item principal.\n" ..
      "? Apenas um tipo de material por vez.\n" ..
      "? Após selecionar, clique em 'Imbuir' para finalizar.\n" ..
      "? Pressione 'ESC' para fechar."
    )
  end
end

function CloseChange()
  modules.game_forgeSystem.forgeSystem.close()
end

function forgeSystem.terminate()
  if forgePanel then forgePanel:destroy() end
  forgePanel = nil
  g_keyboard.unbindKeyDown("Escape")
  pcall(function() ProtocolGame.unregisterExtendedOpcode(Forge.OPCODE) end)
  equippedContainer, equippedScrollBar, selectedItemBox = nil, nil, nil
  materialSlots, itemWidgets = {}, {}
  selectedMainItemId, selectedMaterialId, upgradeValueLabel = nil, nil, nil
  forgeSystem.lastMaterials, forgeSystem.selectedMaterialType = nil, nil
end

--------------------------------------------------------------------------------
-- Abrir/Fechar Interface
--------------------------------------------------------------------------------
function forgeSystem.open()
  if not forgePanel then return end
  forgeSystem.clearMaterials() -- ?? Reset garantido
  forgePanel:show(); forgePanel:raise(); forgePanel:focus()
  local protocol = g_game.getProtocolGame()
  if protocol then
    protocol:sendExtendedOpcode(Forge.OPCODE, json.encode({ action = "request_items" }))
  end
end


function forgeSystem.close()
  if forgePanel then
    forgeSystem.clearMainItem()
    forgePanel:hide()
  end
end

--------------------------------------------------------------------------------
-- Atualiza a lista de itens (lado esquerdo)
--------------------------------------------------------------------------------
function forgeSystem.updateEquippedItems(equippedItems)
  if not equippedContainer then return end
  equippedContainer:destroyChildren()
  forgeSystem.availableMaterials = {}  -- Reinicia materiais disponíveis

  for _, item in pairs(equippedItems) do
    local panel = g_ui.createWidget("ForgeItemWidget", equippedContainer)
    panel:setId("equippedItem_" .. item.itemId)

    local icon = panel:recursiveGetChildById("itemIcon")
    if icon then
      icon:setItemId(tonumber(item.itemId))
      icon.onClick = function() return true end
      icon.onMousePress = function() return true end
      icon:setFocusable(false); icon:setPhantom(true); icon:setEnabled(false)
    end

    local slots, active = {}, 0
    for i = 1, item.slotsCount do
      local s = item.slots and item.slots[i] or "Vazio"
      table.insert(slots, s)
      if s ~= "Vazio" then active = active + 1 end
    end

    local label = panel:recursiveGetChildById("itemText")
    if label then
      label:setText(string.format("%s\n%s", item.itemName, table.concat(slots, "\n")))
    end

    local colors = { [0] = "gray", [1] = "#007BFF", [2] = "#28A745", [3] = "#FFD700" }
    panel:setBorderColor(colors[active] or "gray")
    panel.onClick = function() forgeSystem.selectMainItem(item) end

    if item.compatibleMaterials then
      for _, mat in pairs(item.compatibleMaterials) do
        forgeSystem.availableMaterials[mat.id] = mat.count
      end
    end
  end
end

function sendForgeRequest(item, materials, successBoost)
local data = {
    action = "forge",
    item = item.clientId,
    itemServerId = item.serverId,
    itemUniqueId = selectedMainItemUniqueId, -- ? ?? ESSENCIAL
    successBoost = successBoost or false,
    materials = {}
}

for _, mat in ipairs(materials) do
    table.insert(data.materials, { serverId = mat.serverId })
end
    g_game.getProtocolGame():sendExtendedOpcode(200, json.encode(data))
end

--------------------------------------------------------------------------------
-- Selecionar item principal
--------------------------------------------------------------------------------
function forgeSystem.selectMainItem(item)
selectedMainItemId = item.itemId -- clientId
selectedMainItemServerId = item.itemServerId -- serverId
selectedMainItemUniqueId = item.itemUniqueId -- ? salva o IUID recebido do servidor


    getWidget("mainItemBox"):setItemId(item.itemId)

    local label = getWidget("selectedItemLabel")
    if label then
        label:setText(item.itemName or "Item Desconhecido")
    end

    forgeSystem.appliedAttributes = {}
    if item.slots then
        for _, s in ipairs(item.slots) do
            local a = s:match("^(.-):")
            if a then
                forgeSystem.appliedAttributes[a] = true
            end
        end
    end

    forgeSystem.showMaterialsForMainItem(item.compatibleMaterials)
end

--------------------------------------------------------------------------------
-- Exibir materiais compatíveis
--------------------------------------------------------------------------------
function forgeSystem.showMaterialsForMainItem(materials)
  if not equippedContainer then return end
  equippedContainer:destroyChildren()
  itemWidgets = {}
  forgeSystem.lastMaterials = materials
  forgeSystem.selectedMaterialType = nil
  local title = getWidget("equippedItemsLabel")
  if title then title:setText("Materiais Compatíveis") end
  forgeSystem.updateMaterials(materials)
end

function forgeSystem.updateMaterials(materials)
  if not equippedContainer then return end
  equippedContainer:destroyChildren()
  for _, mat in pairs(materials) do
    local panel = g_ui.createWidget("ForgeMaterialWidget", equippedContainer)
    panel:setId("material_" .. (mat.serverId or mat.id))
    local icon = panel:recursiveGetChildById("materialIcon")
    if icon then
      icon:setItemId(tonumber(mat.clientId or mat.id))
      icon.onClick = function() return true end
      icon.onMousePress = function() return true end
      icon:setFocusable(false); icon:setPhantom(true); icon:setEnabled(false)
    end
    local attr = mat.attribute:match("^(.-):") or mat.attribute
    local label = panel:recursiveGetChildById("materialText")
    if label then label:setText(mat.attribute .. " (x" .. mat.count .. ")") end
    if forgeSystem.appliedAttributes and forgeSystem.appliedAttributes[attr] then
      panel:setOpacity(0.3)
      panel.onMousePress = function() return false end
    else
      panel.onMousePress = function(_, _, btn)
        if btn == MouseLeftButton then forgeSystem.addMaterialToSlot(mat.id)
        elseif btn == MouseRightButton then forgeSystem.removeMaterial(mat.id) end
      end
    end
  end
end

--------------------------------------------------------------------------------
-- Slots de materiais
--------------------------------------------------------------------------------
function forgeSystem.addMaterialToSlot(itemId)
    if forgeSystem.selectedMaterialType and forgeSystem.selectedMaterialType ~= itemId then return end
    if not forgeSystem.selectedMaterialType then
        forgeSystem.selectedMaterialType = itemId
        forgeSystem.updateMaterialOpacity()
    end

    local avail = forgeSystem.availableMaterials and forgeSystem.availableMaterials[itemId] or 0
    local current = 0
    for i = 1, 3 do
        if materialSlots[i].serverId == itemId then current = current + 1 end
    end
    if current >= avail or forgeSystem:getMaterialSlotCount() >= 3 then
        print("[ForgeSystem] Limite atingido: " .. avail)
        return
    end

    local matInfo = nil
    for _, m in ipairs(forgeSystem.lastMaterials or {}) do
        if m.serverId == itemId then
            matInfo = m
            break
        end
    end

    if matInfo then
        for i = 1, 3 do
            if not materialSlots[i].serverId then
                materialSlots[i]:setItemId(matInfo.clientId)
                 materialSlots[i].serverId = matInfo.serverId -- ?? ESSENCIAL
                materialSlots[i].serverId = matInfo.serverId
                forgeSystem.updateUpgradeValue()
                forgeSystem.updateMaterialQuantity(itemId, -1)
                forgeSystem.updateMaterialOpacity()
                return
            end
        end
    end
end


function forgeSystem.removeMaterial(itemId)
    for i = 3, 1, -1 do
        if materialSlots[i].serverId == itemId then
            materialSlots[i]:setItemId(0)
            materialSlots[i].serverId = nil
            forgeSystem.updateMaterialQuantity(itemId, 1)
            break
        end
    end
    local has = false
    for i = 1, 3 do if materialSlots[i].serverId then has = true; break end end
    if not has then
        forgeSystem.selectedMaterialType = nil
        forgeSystem.updateMaterialOpacity()
        for i = 1, 3 do materialSlots[i]:setBorderColor("gray") end
        getWidget("mainItemBox"):setBorderColor("gray")
        local rp = getWidget("rightPanel")
        if rp then rp:setBorderColor("gray") end
    end
    forgeSystem.updateUpgradeValue()
end


function forgeSystem.clearMaterials()
  for i = 1, 3 do
    materialSlots[i]:setItemId(0)
    materialSlots[i].serverId = nil
    materialSlots[i]:setBorderColor("gray")
  end
  selectedMaterialId = nil
  forgeSystem.selectedMaterialType = nil
  local rp = getWidget("rightPanel")
  if rp then rp:setBorderColor("gray") end
  forgeSystem.updateMaterialOpacity()
  forgeSystem.updateUpgradeValue()
end


--------------------------------------------------------------------------------
-- Opacidade e contagem dos slots de material
--------------------------------------------------------------------------------
function forgeSystem.updateMaterialOpacity()
  for _, w in pairs(equippedContainer:getChildren()) do
    local id = tonumber(w:getId():match("material_(%d+)"))
    w:setOpacity((forgeSystem.selectedMaterialType and id ~= forgeSystem.selectedMaterialType) and 0.3 or 1.0)
  end
end

function forgeSystem:getMaterialSlotCount()
  local count = 0
  for i = 1, 3 do if materialSlots[i]:getItemId() ~= 0 then count = count + 1 end end
  return count
end

--------------------------------------------------------------------------------
-- Atualiza label de upgrade e bordas
--------------------------------------------------------------------------------
function forgeSystem.updateUpgradeValue()
  if not upgradeValueLabel then return end
  
  local materialCount = forgeSystem:getMaterialSlotCount()
  local matData = nil
  for i = 1, 3 do
    local id = materialSlots[i].serverId
    if id ~= 0 and not matData then
      for _, d in ipairs(forgeSystem.lastMaterials or {}) do
        if d.id == id then matData = d; break end
      end
    end
  end
  if not matData then
    upgradeValueLabel:setText("Escolha um material para ver os detalhes.")
    forgeSystem.updateMaterialSlotBorders(0)
    return
  end
  
  local baseCost = matData.cost * materialCount
  local totalCost = (materialCount > 1) and (baseCost * 1.2) or baseCost
  local baseChance = matData.chance or 20
  local finalChance = math.max(baseChance - ((materialCount - 1) * 15), 10)
  
  local sBoost = getWidget("successBoostCheckbox")
  local boostEnabled = sBoost and sBoost:isChecked() or false
  if boostEnabled then finalChance, totalCost = 100, totalCost * 2 end
  
  local totalGain = matData.gain[1] * materialCount
  local tierName = (materialCount == 2 and "Intricate") or (materialCount == 3 and "Powerful") or "Basic"
  local attrName = matData.attribute:gsub("[:%d%%]", ""):gsub("^%s*(.-)%s*$", "%1")
  
  local durationText
  if matData.duration == 0 then
    durationText = "[Permanente]"
  else
    durationText = matData.duration .. " horas"
  end
  
  local details = string.format(
    "%s %s\n+%d (Máx: %d)\nDuração: %s\nChance de Sucesso: %d%%\nCusto: %d Gold",
    attrName, tierName, totalGain, matData.max, durationText, finalChance, totalCost
  )
  upgradeValueLabel:setText(details)
  forgeSystem.updateMaterialSlotBorders(materialCount)
end

function forgeSystem.onSuccessBoostToggled() forgeSystem.updateUpgradeValue() end

function forgeSystem.updateMaterialSlotBorders(count)
  local colors = { [0] = "gray", [1] = "#007BFF", [2] = "#28A745", [3] = "#FFD700" }
  local selColor = colors[count] or "gray"
  for i = 1, 3 do
    materialSlots[i]:setBorderColor(materialSlots[i]:getItemId() ~= 0 and selColor or "gray")
  end
  local mainBox = getWidget("mainItemBox")
  if mainBox then mainBox:setBorderColor(mainBox:getItemId() ~= 0 and selColor or "gray") end
  local rp = getWidget("rightPanel")
  if rp then rp:setBorderColor(selColor) end
end

--------------------------------------------------------------------------------
-- Limpar item principal
--------------------------------------------------------------------------------
function forgeSystem.clearMainItem()
  if not selectedMainItemId then return end
  selectedMainItemId = nil
  getWidget("mainItemBox"):setItemId(0)
  forgeSystem.clearMaterials()
  local title = getWidget("equippedItemsLabel")
  if title then title:setText("Itens para forjar") end
  getWidget("mainItemBox"):setBorderColor("gray")
  local rp = getWidget("rightPanel")
  if rp then rp:setBorderColor("gray") end
  local protocol = g_game.getProtocolGame()
  if protocol then
    protocol:sendExtendedOpcode(Forge.OPCODE, json.encode({ action = "request_items" }))
  end
end

--------------------------------------------------------------------------------
-- Iniciar a forja (botão "Imbuir")
--------------------------------------------------------------------------------
function forgeSystem.startForging()
    if not selectedMainItemId or not selectedMainItemServerId then
        print("[ForgeSystem] Erro: Item principal não selecionado corretamente.")
        return
    end

    local ids = {}
    for i = 1, 3 do
        local sid = materialSlots[i].serverId
        if sid then
            table.insert(ids, { serverId = sid })
        end
    end

    if #ids == 0 then
        print("[ForgeSystem] Erro: Nenhum material selecionado.")
        return
    end

    -- ?? Verificação de consistência
    if forgeSystem.selectedMaterialType == nil then
        print("[ForgeSystem] Erro: Tipo de material não reconhecido.")
        return
    end

    if #ids > forgeSystem.availableMaterials[forgeSystem.selectedMaterialType] then
        print("[ForgeSystem] Erro: Quantidade de materiais inválida.")
        return
    end

    local sBoost = getWidget("successBoostCheckbox")
    local boost = sBoost and sBoost:isChecked() or false

    sendForgeRequest({ clientId = selectedMainItemId, serverId = selectedMainItemServerId }, ids, boost)

    forgeSystem.clearMainItem()
end


return forgeSystem