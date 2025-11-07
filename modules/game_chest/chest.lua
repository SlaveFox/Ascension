local chestWindow, receiveItemWidget, buttonChest = nil, nil, nil
local chestOpcode = 43
local widgetBorderMargins = {}

-- animações em andamento
local chestEventUnFocus, chestEventFocus = nil, nil

local spriteIdLock = 12928

-- tamanhos
local SMALL_W, SMALL_H = 80, 60
local BIG_W,   BIG_H   = 160, 120

-- seleção explícita
local selectedChest = nil
local didInitSelection = false
local isOpening = false -- evita encolher durante a abertura

-- mata animações pendentes
local function killAnimEvents()
  if chestEventFocus then removeEvent(chestEventFocus); chestEventFocus = nil end
  if chestEventUnFocus then removeEvent(chestEventUnFocus); chestEventUnFocus = nil end
end

function init()
  connect(g_game, { onGameStart = naoexibir, onGameEnd = naoexibir })
  connect(LocalPlayer, { onPositionChange = onPositionChange })

  chestWindow = g_ui.loadUI("chest", modules.game_interface.getRootPanel())
  buttonChest = modules.client_topmenu.addRightGameToggleButton('Chest', tr('Chest'), '/images/topbuttons/chest', exibir, false, 1)
  buttonChest:setOn(false)

  ProtocolGame.registerExtendedOpcode(chestOpcode, onPlayerReceiveChest)
  chestWindow:hide()
end

function terminate()
  disconnect(g_game, { onGameStart = naoexibir, onGameEnd = naoexibir })
  disconnect(LocalPlayer, { onPositionChange = onPositionChange })
  ProtocolGame.unregisterExtendedOpcode(chestOpcode)
  chestWindow:hide()
end

function exibir()
  if buttonChest:isOn() then
    naoexibir()
  else
    -- seleção inicial só nesta abertura
    selectedChest = nil
    didInitSelection = false
    isOpening = false

    g_game.getProtocolGame():sendExtendedOpcode(chestOpcode, json.encode({ type = "chestSystem" }))
    chestWindow:show()
    buttonChest:setOn(true)
  end
end

function onPositionChange(creature, newPos, oldPos)
  if creature:isLocalPlayer() and chestWindow:isVisible() then
    naoexibir()
  end
end

function naoexibir()
  killAnimEvents()
  chestWindow:hide()
  buttonChest:setOn(false)
  selectedChest = nil
  didInitSelection = false
  isOpening = false
  removeReceiveItem()
end

-- Mapeamento de baús e suas chaves
local chestKeys = {
  [1] = "chest/GoldKey",
  [2] = "chest/SilverKey",
  [3] = "chest/BronzeKey"
}

-- Helpers de tamanho
local function forceSize(widget, w, h)
  if not widget then return end
  widget:setWidth(w); widget:setHeight(h)
end

local function getChestPanel()
  return chestWindow.chestPanel or chestWindow:getChildById('chestPanel')
end

local function getChestWidgetByIndex(i)
  local panel = getChestPanel(); if not panel then return nil end
  local name = 'chest' .. tostring(i)
  return panel[name] or panel:getChildById(name)
end

local function setOthersSmall(exceptWidget)
  for i = 1, 3 do
    local w = getChestWidgetByIndex(i)
    if w and w ~= exceptWidget then
      forceSize(w, SMALL_W, SMALL_H)
    end
  end
end

-- Atualiza exibição da chave
function updateKeyDisplay(chestIndex, keyCount)
  local chestPanel = getChestPanel(); if not chestPanel then return end
  local keyPanel = chestPanel.keyPanel or chestPanel:getChildById('keyPanel'); if not keyPanel then return end

  keyPanel:destroyChildren()

  local keyLabelWidget = g_ui.createWidget("UILabel", keyPanel)
  keyLabelWidget:addAnchor(AnchorLeft, "parent", AnchorLeft)
  keyLabelWidget:addAnchor(AnchorVerticalCenter, "parent", AnchorVerticalCenter)
  keyLabelWidget:setText("Keys:")
  keyLabelWidget:setMarginRight(5)

  local keyImageWidget = g_ui.createWidget("UIItem", keyPanel)
  keyImageWidget:addAnchor(AnchorLeft, keyLabelWidget:getId(), AnchorRight)
  keyImageWidget:addAnchor(AnchorVerticalCenter, "parent", AnchorVerticalCenter)
  keyImageWidget:setMarginRight(5)
  keyImageWidget:setImageSource(chestKeys[chestIndex] or "chest/GoldKey")

  local keyTextWidget = g_ui.createWidget("UILabel", keyPanel)
  keyTextWidget:addAnchor(AnchorLeft, keyImageWidget:getId(), AnchorRight)
  keyTextWidget:addAnchor(AnchorVerticalCenter, "parent", AnchorVerticalCenter)
  keyTextWidget:setText("x" .. (keyCount or 0))
  keyTextWidget:setTooltip("Você possui " .. (keyCount or 0) .. " chave(s) para este baú.")
end

-- animações
function setAnimateUnfocusChild(widget)
  if not widget then return end
  if chestEventUnFocus then removeEvent(chestEventUnFocus); chestEventUnFocus = nil end
  widget:setImageSource("chest/chest1")

  local startH, startW = widget:getHeight(), widget:getWidth()
  local targetH, targetW = SMALL_H, SMALL_W
  local duration, startTime = 600, g_clock.millis()

  chestEventUnFocus = cycleEvent(function()
    local now = g_clock.millis()
    local p = math.min(1, (now - startTime) / duration)
    local e = math.sin(p * math.pi * 0.5)
    widget:setHeight(startH + (targetH - startH) * e)
    widget:setWidth (startW + (targetW - startW) * e)
    if p >= 1 then
      removeEvent(chestEventUnFocus); chestEventUnFocus = nil
    end
  end, 30)
end

function setAnimateFocusChild(widget)
  if not widget then return end
  if chestEventFocus then removeEvent(chestEventFocus); chestEventFocus = nil end

  local startH, startW = widget:getHeight(), widget:getWidth()
  local targetH, targetW = BIG_H, BIG_W
  local duration, startTime = 600, g_clock.millis()

  chestEventFocus = cycleEvent(function()
    local now = g_clock.millis()
    local p = math.min(1, (now - startTime) / duration)
    local e = math.sin(p * math.pi * 0.5)
    widget:setHeight(startH + (targetH - startH) * e)
    widget:setWidth (startW + (targetW - startW) * e)
    if p >= 1 then
      removeEvent(chestEventFocus); chestEventFocus = nil
    end
  end, 30)
end

-- seleção explícita com “anti-duplo-grande”
local function selectChest(widget)
  if not widget then return end

  -- clicar no mesmo: se estiver pequeno, cresce de novo
  if widget == selectedChest then
    if widget:getWidth() < BIG_W or widget:getHeight() < BIG_H then
      killAnimEvents()
      setOthersSmall(widget)           -- outros pequenos imediato
      setAnimateFocusChild(widget)     -- anima pra grande
      widget:focus()
    end
    return
  end

  -- troca de seleção rápida: cancela animações globais e ACERTA tamanhos já
  killAnimEvents()
  setOthersSmall(widget)               -- todos os outros ficam pequenos instantâneo
  selectedChest = widget
  setAnimateFocusChild(widget)         -- anima só o selecionado
  widget:focus()

  -- HUD keys + botão abrir
  updateKeyDisplay(widget.index, widget.key or 0)
  local chestPanel = getChestPanel()
  local openButton = chestPanel and (chestPanel.openChest or chestPanel:getChildById('openChest')) or nil
  if openButton then openButton:setEnabled((widget.key or 0) > 0) end

  removeReceiveItem()
end

-- Handler do opcode
function onPlayerReceiveChest(_, _, payload)
  local ok, json_data = pcall(function() return json.decode(payload) end)
  if not ok or not json_data then return end

  local chestPanel = getChestPanel(); if not chestPanel then return end
  local openButton = chestPanel.openChest or chestPanel:getChildById('openChest')

  if json_data.type == "chestUpdate" then
    for _, chestData in ipairs(json_data.chestData or {}) do
      local chestName   = "chest" .. tostring(chestData.index)
      local chestWidget = chestPanel[chestName] or chestPanel:getChildById(chestName)
      if chestWidget then
        chestWidget:setImageSource("chest/chest1")
        chestWidget.index = chestData.index
        chestWidget.key   = chestData.key
        chestWidget:setMarginRight(0); chestWidget:setMarginBottom(0); chestWidget:setMarginLeft(0)

        -- listas
        if chestData.index == 1 then
          if chestWidget.fragmentLock then chestWidget.fragmentLock:setItemId(spriteIdLock) end
          chestWidget:setMarginBottom(10)
          if chestWidget.chestList1 then
            chestWidget.chestList1:destroyChildren()
            for _, itemData in ipairs(chestData.fragmentos or {}) do
              local itemWidget = g_ui.createWidget("ItemFragment", chestWidget.chestList1)
              itemWidget:setItemId(itemData.id)
            end
          end
        elseif chestData.index == 2 then
          chestWidget:setMarginRight(140)
          if chestWidget.chestList2 then
            chestWidget.chestList2:destroyChildren()
            for _, itemData in ipairs(chestData.fragmentos or {}) do
              local itemWidget = g_ui.createWidget("ItemFragment", chestWidget.chestList2)
              itemWidget:setItemId(itemData.id)
            end
          end
        elseif chestData.index == 3 then
          chestWidget:setMarginLeft(140)
          if chestWidget.chestList3 then
            chestWidget.chestList3:destroyChildren()
            for _, itemData in ipairs(chestData.fragmentos or {}) do
              local itemWidget = g_ui.createWidget("ItemFragment", chestWidget.chestList3)
              itemWidget:setItemId(itemData.id)
            end
          end
        end

        -- clique: seleciona (com proteção contra dois grandes)
        chestWidget.onClick = function() selectChest(chestWidget) end

        -- tamanhos imediatos em updates (exceto se abrindo)
        if not isOpening then
          if selectedChest == chestWidget then
            forceSize(chestWidget, BIG_W, BIG_H)
            setOthersSmall(chestWidget)
          else
            forceSize(chestWidget, SMALL_W, SMALL_H)
          end
        end
      end
    end

    -- seleção inicial (apenas uma vez por abertura): baú do meio = index 1
    if not didInitSelection then
      local defaultChest = chestPanel:getChildById('chest1') or chestPanel.chest1
      if defaultChest then
        setOthersSmall(defaultChest)
        forceSize(defaultChest, SMALL_W, SMALL_H) -- base antes do grow
        selectChest(defaultChest)
      end
      didInitSelection = true
    else
      -- garantir consistência pós-update se não estiver abrindo
      if selectedChest and not isOpening then
        forceSize(selectedChest, BIG_W, BIG_H)
        setOthersSmall(selectedChest)
      end
    end

    if openButton then
      openButton.onClick = function()
        local fc = selectedChest
        if fc then
          g_game.getProtocolGame():sendExtendedOpcode(chestOpcode, json.encode({ type="openChest", index=fc.index }))
        end
      end
      local fc = selectedChest
      openButton:setEnabled(fc and (fc.key or 0) > 0 or false)
    end

  elseif json_data.type == "updateSucess" or json_data.type == "updateSuccess" then
    if selectedChest then
      selectedChest.key = json_data.key or selectedChest.key
      updateKeyDisplay(selectedChest.index, selectedChest.key or 0)
      if openButton then openButton:setEnabled((selectedChest.key or 0) > 0) end
    end

    if openButton then openButton:setEnabled(false) end
    removeReceiveItem()
    openChest(
      openButton,
      selectedChest or (chestPanel:getFocusedChild()),
      json_data.itemId,
      json_data.fragmentCount
    )
  end
end

function openChest(widgetUse, chestWidget, itemId, count)
  local chestPanel = getChestPanel(); if not chestPanel then return end
  local parentWidget = selectedChest or chestPanel:getFocusedChild()
  local frameCount, openDuration = 6, 300
  local interval = math.floor(openDuration / frameCount)

  isOpening = true
  chestPanel:setEnabled(false)
  updateKeys("afterOpen")

  -- garante tamanho grande do selecionado mesmo durante a abertura
  if selectedChest then
    forceSize(selectedChest, BIG_W, BIG_H)
    setOthersSmall(selectedChest)
  end

  for i = 1, frameCount do
    scheduleEvent(function()
      chestWidget:setImageSource("chest/chest" .. i)
      if i == frameCount then
        if widgetUse then widgetUse:setEnabled(true) end
        chestPanel:setEnabled(true)
        playSmokeAnimation(parentWidget, itemId, count)
        scheduleEvent(function()
          updateKeys("afterShowItem")
          closeChestAnimation(chestWidget)
        end, 1000)
      end
    end, interval * i)
  end
end

function updateKeys(stage)
  local chestPanel = getChestPanel(); if not chestPanel then return end
  local fc = selectedChest or chestPanel:getFocusedChild()
  local chestIndex = fc and fc.index or nil
  if chestIndex then
    g_game.getProtocolGame():sendExtendedOpcode(chestOpcode, json.encode({
      type  = "updateKeys",
      stage = stage,
      index = chestIndex
    }))
  end
end

function closeChestAnimation(chestWidget)
  local frameCount, closeDuration = 6, 300
  local interval = math.floor(closeDuration / frameCount)

  for i = frameCount, 1, -1 do
    scheduleEvent(function()
      chestWidget:setImageSource("chest/chest" .. i)
      if i == 1 then
        removeReceiveItem()
        local chestPanel = getChestPanel()
        if chestPanel then chestPanel:setEnabled(true) end
        -- mantém o selecionado GRANDE no fim
        if selectedChest then
          forceSize(selectedChest, BIG_W, BIG_H)
          setOthersSmall(selectedChest)
        end
        isOpening = false
      end
    end, interval * (frameCount - i + 1))
  end
end

function playSmokeAnimation(parentWidget, itemId, count)
  local smokeFrameCount, smokeDuration = 3, 100
  local smokeInterval = math.floor(smokeDuration / smokeFrameCount)

  local smokeWidget = g_ui.createWidget("ItemFragment", parentWidget)
  smokeWidget:addAnchor(AnchorTop, "parent", AnchorTop)
  smokeWidget:addAnchor(AnchorHorizontalCenter, "parent", AnchorHorizontalCenter)

  for i = 1, smokeFrameCount do
    scheduleEvent(function()
      smokeWidget:setImageSource("chest/Smoke" .. i)
      if i == smokeFrameCount then
        scheduleEvent(function()
          smokeWidget:destroy()
          receiveItemWidget = g_ui.createWidget("ItemFragment", parentWidget)
          receiveItemWidget:addAnchor(AnchorTop, "parent", AnchorTop)
          receiveItemWidget:addAnchor(AnchorHorizontalCenter, "parent", AnchorHorizontalCenter)
          receiveItemWidget:setItemId(itemId)
          receiveItemWidget:setItemCount(count)
        end, 140)
      end
    end, smokeInterval * i)
  end
end

function removeReceiveItem()
  if receiveItemWidget then
    receiveItemWidget:destroy()
    receiveItemWidget = nil
  end
end
