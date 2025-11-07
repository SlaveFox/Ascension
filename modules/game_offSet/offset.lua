OffsetManager = {}

local offsetWindow = nil
local offsetButton = nil
local outfitWidget = nil
local itemWidget = nil
local effectWidget = nil
local currentDirection = nil
local otmlData = { creatures = {}, items = {}, effects = {} }
local filename = "Tibia.otml"
local directory = "data/things/860/"
local OffsetOptions = {"Outfit", "Item", "Effect"}
local currentDisplacementType = nil
local currentSubDisplacement = nil
local isSubOutfitEnabled = false

local function validateNumericInput(inputWidget)
  inputWidget:setText(inputWidget:getText():gsub("[^%d%-]", ""))
end

local offsets = {
    ["left"] = { offsetX = 0, offsetY = 0 },
    ["right"] = { offsetX = 0, offsetY = 0 },
    ["up"] = { offsetX = 0, offsetY = 0 },
    ["down"] = { offsetX = 0, offsetY = 0 }
}

function init()
  g_ui.importStyle('offset.otui')
  loadOtmlFile()
  backupOtmlFile()

  offsetButton = modules.client_topmenu.addLeftGameButton(
    'offsetButton', 
    tr('Offset Manager'), 
    nil,  
    OffsetManager.toggle, 
    false, 
    1
  )

  offsetWindow = g_ui.createWidget('OffsetWindow', modules.game_interface.getRootPanel())

  setupComboBox()
  outfitWidget = offsetWindow:recursiveGetChildById('outfitView')
  itemWidget = offsetWindow:recursiveGetChildById('itemView')
  effectWidget = offsetWindow:recursiveGetChildById('effectView')

  outfitWidget:hide()
  itemWidget:hide()
  effectWidget:hide()
  offsetWindow:hide()

  setupNumericFields()
  setupIdInputValidation()

  local movementCheck = offsetWindow:recursiveGetChildById('movement')
  movementCheck.onCheckChange = function(checkBox, checked)
    if outfitWidget:isVisible() then
      outfitWidget:setAnimate(checked)
    end
  end
  OffsetManager.bindKeys()
end

function OffsetManager.toggleDirection(direction)
  if currentDirection == direction then
    return
  end

  if currentDirection then
    local offsetXField = offsetWindow:recursiveGetChildById('offsetX')
    local offsetYField = offsetWindow:recursiveGetChildById('offsetY')
    local prevOffsetX = tonumber(offsetXField:getText()) or 0
    local prevOffsetY = tonumber(offsetYField:getText()) or 0
    offsets[currentDirection].offsetX = prevOffsetX
    offsets[currentDirection].offsetY = prevOffsetY
  end

  currentDirection = direction

  local offsetX = offsets[direction].offsetX or 0
  local offsetY = offsets[direction].offsetY or 0
  local offsetXField = offsetWindow:recursiveGetChildById('offsetX')
  local offsetYField = offsetWindow:recursiveGetChildById('offsetY')

  offsetXField:setText(tostring(offsetX))
  offsetYField:setText(tostring(offsetY))

  local checkUp = offsetWindow:recursiveGetChildById('checkUp')
  local checkRight = offsetWindow:recursiveGetChildById('checkRight')
  local checkDown = offsetWindow:recursiveGetChildById('checkDown')
  local checkLeft = offsetWindow:recursiveGetChildById('checkLeft')

  checkUp:setChecked(direction == 'up')
  checkRight:setChecked(direction == 'right')
  checkDown:setChecked(direction == 'down')
  checkLeft:setChecked(direction == 'left')

  if outfitWidget:isVisible() then
    local directions = {
      up = Directions.North,
      right = Directions.East,
      down = Directions.South,
      left = Directions.West
    }

    local newDirection = directions[direction]
    if newDirection then
      outfitWidget:setDirection(newDirection)
    end
  end
end



function onMovementChange(checkBox, checked)
  previewCreature:setAnimate(checked)
  settings.movement = checked
end

function updateCheckboxes(selectedDirection)
  local checkUp = offsetWindow:recursiveGetChildById('checkUp')
  local checkRight = offsetWindow:recursiveGetChildById('checkRight')
  local checkDown = offsetWindow:recursiveGetChildById('checkDown')
  local checkLeft = offsetWindow:recursiveGetChildById('checkLeft')

  checkUp:setChecked(selectedDirection == 'up')
  checkRight:setChecked(selectedDirection == 'right')
  checkDown:setChecked(selectedDirection == 'down')
  checkLeft:setChecked(selectedDirection == 'left')
end


function setupIdInputValidation()
  local idInput = offsetWindow:getChildById('idInput')
  idInput.onTextChange = function() validateNumericInput(idInput) end
end

function terminate()
  if offsetWindow then offsetWindow:destroy() end
  if offsetButton then offsetButton:destroy() end
end

function OffsetManager.toggle()
  if offsetWindow:isVisible() then
    offsetWindow:hide()
    offsetButton:setOn(false)
  else
    offsetWindow:show()
    offsetWindow:raise()
    offsetWindow:focus()
    offsetButton:setOn(true)
  end
end

function setupComboBox()
  local offsetComboBox = offsetWindow:getChildById('offsetComboBox')
  local opacityComboBox = offsetWindow:getChildById('effectOpacityComboBox')
  local opacityOutfitPanel = offsetWindow:getChildById('OpacityOutfit')

  if not opacityOutfitPanel then
    return
  end

  for _, option in ipairs(OffsetOptions) do
    offsetComboBox:addOption(option)
  end

  offsetComboBox.onOptionChange = function(_, option)
    local displacementTypeComboBox = offsetWindow:getChildById('displacementTypeComboBox')
    local directionsPanel = offsetWindow:getChildById('DirectionsPanel')
    local offsetXField = offsetWindow:recursiveGetChildById('offsetX')
    local offsetYField = offsetWindow:recursiveGetChildById('offsetY')
    local idInput = offsetWindow:getChildById('idInput')
    local chaseModeBox = offsetWindow:recursiveGetChildById('movement')
    local opacityField = offsetWindow:recursiveGetChildById('opacityInput')
    local offsetPanel = offsetWindow:getChildById('OffsetPanel')
    local opacityPanel = offsetWindow:getChildById('OpacityPanel')

    opacityField:setText('1.0')
    idInput:setText('')

    if effectWidget:isVisible() then
      effectWidget:hide()
      effectWidget:setEffect(nil)
    end

    if option == 'Outfit' then
      displacementTypeComboBox:setVisible(true)
      opacityComboBox:setVisible(false)
      opacityPanel:setVisible(false)
      offsetPanel:setVisible(true)
      outfitWidget:show()
      itemWidget:hide()
      effectWidget:hide()
      offsetWindow:getChildById('preview'):show()
      directionsPanel:setVisible(true)
      chaseModeBox:show()

      if displacementTypeComboBox:getText() == 'Outfit Displacement' then
        opacityOutfitPanel:setVisible(true)
      end

      outfitWidget:setOutfit({})
      OffsetManager.toggleDirection("down")
      OffsetManager.viewOffset()

    elseif option == 'Item' then
      outfitWidget:setOutfit({})
      outfitWidget:hide()
      itemWidget:show()
      effectWidget:hide()
      offsetWindow:getChildById('preview'):show()
      directionsPanel:setVisible(false)
      chaseModeBox:hide()
      displacementTypeComboBox:setVisible(false)
      opacityComboBox:setVisible(true)

      local selectedOpacityOption = opacityComboBox:getText()
      if selectedOpacityOption == 'None' then
        offsetPanel:setVisible(true)
        opacityPanel:setVisible(false)
      else
        offsetPanel:setVisible(false)
        opacityPanel:setVisible(true)
      end

      OffsetManager.viewOffset()

    elseif option == 'Effect' then
      outfitWidget:hide()
      itemWidget:hide()
      effectWidget:show()
      opacityComboBox:setVisible(true)

      local selectedOpacityOption = opacityComboBox:getText()
      if selectedOpacityOption == 'None' then
        offsetPanel:setVisible(true)
        opacityPanel:setVisible(false)
      else
        offsetPanel:setVisible(false)
        opacityPanel:setVisible(true)
      end

      directionsPanel:setVisible(false)
      chaseModeBox:hide()
      displacementTypeComboBox:setVisible(false)

      OffsetManager.viewOffset()
    end

    if option ~= 'Outfit' then
      opacityOutfitPanel:setVisible(false)
    end

    OffsetManager.resetOffset()
  end

  local displacementTypeComboBox = offsetWindow:getChildById('displacementTypeComboBox')
  displacementTypeComboBox:addOption("Outfit Displacement")
  displacementTypeComboBox:addOption("Name Displacement")
  displacementTypeComboBox:addOption("Target Displacement")

  opacityComboBox:addOption("None")
  opacityComboBox:addOption("Opacity")

  displacementTypeComboBox.onOptionChange = function(_, option)
    currentDisplacementType = option
    OffsetManager.toggleDirection("down")

    local id = tonumber(offsetWindow:getChildById('idInput'):getText())
    if currentDisplacementType == "Outfit Displacement" then
      opacityOutfitPanel:setVisible(true)
      OffsetManager.viewOffset()
    elseif currentDisplacementType == "Name Displacement" then
      -- Aqui, o painel fica visível para Name Displacement
      opacityOutfitPanel:setVisible(true)
      local nameDisplacement = otmlData.creatures[id] and otmlData.creatures[id]["name-displacement"]
      if nameDisplacement then
        offsets["up"].offsetX = nameDisplacement.North and nameDisplacement.North[1] or 0
        offsets["up"].offsetY = nameDisplacement.North and nameDisplacement.North[2] or 0
        offsets["right"].offsetX = nameDisplacement.East and nameDisplacement.East[1] or 0
        offsets["right"].offsetY = nameDisplacement.East and nameDisplacement.East[2] or 0
        offsets["down"].offsetX = nameDisplacement.South and nameDisplacement.South[1] or 0
        offsets["down"].offsetY = nameDisplacement.South and nameDisplacement.South[2] or 0
        offsets["left"].offsetX = nameDisplacement.West and nameDisplacement.West[1] or 0
        offsets["left"].offsetY = nameDisplacement.West and nameDisplacement.West[2] or 0
      else
        offsets["up"].offsetX = 0
        offsets["up"].offsetY = 0
        offsets["right"].offsetX = 0
        offsets["right"].offsetY = 0
        offsets["down"].offsetX = 0
        offsets["down"].offsetY = 0
        offsets["left"].offsetX = 0
        offsets["left"].offsetY = 0
      end
      updateOffsetFields()
    elseif currentDisplacementType == "Target Displacement" then
      opacityOutfitPanel:setVisible(false)
      local nameDisplacement = otmlData.creatures[id] and otmlData.creatures[id]["name-displacement"]
      if nameDisplacement then
        offsets["up"].offsetX = nameDisplacement.North and nameDisplacement.North[1] or 0
        offsets["up"].offsetY = nameDisplacement.North and nameDisplacement.North[2] or 0
        offsets["right"].offsetX = nameDisplacement.East and nameDisplacement.East[1] or 0
        offsets["right"].offsetY = nameDisplacement.East and nameDisplacement.East[2] or 0
        offsets["down"].offsetX = nameDisplacement.South and nameDisplacement.South[1] or 0
        offsets["down"].offsetY = nameDisplacement.South and nameDisplacement.South[2] or 0
        offsets["left"].offsetX = nameDisplacement.West and nameDisplacement.West[1] or 0
        offsets["left"].offsetY = nameDisplacement.West and nameDisplacement.West[2] or 0
      else
        offsets["up"].offsetX = 0
        offsets["up"].offsetY = 0
        offsets["right"].offsetX = 0
        offsets["right"].offsetY = 0
        offsets["down"].offsetX = 0
        offsets["down"].offsetY = 0
        offsets["left"].offsetX = 0
        offsets["left"].offsetY = 0
      end
      updateOffsetFields()
    end

    OffsetManager.viewOffset()
  end

  opacityComboBox.onOptionChange = function(_, option)
    local offsetPanel = offsetWindow:getChildById('OffsetPanel')
    local opacityPanel = offsetWindow:getChildById('OpacityPanel')

    if option == 'None' then
      offsetPanel:setVisible(true)
      opacityPanel:setVisible(false)
    else
      offsetPanel:setVisible(false)
      opacityPanel:setVisible(true)
    end
  end
end


function OffsetManager.bindKeys()
  local rootPanel = modules.game_interface.getRootPanel()

  g_keyboard.bindKeyPress('Shift+Up', function()
    if offsetWindow and offsetWindow:isVisible() then
      OffsetManager.onUp()
    end
  end, rootPanel)

  g_keyboard.bindKeyPress('Shift+Down', function()
    if offsetWindow and offsetWindow:isVisible() then
      OffsetManager.onDown()
    end
  end, rootPanel)

  g_keyboard.bindKeyPress('Shift+Left', function()
    if offsetWindow and offsetWindow:isVisible() then
      OffsetManager.onLeft()
    end
  end, rootPanel)

  g_keyboard.bindKeyPress('Shift+Right', function()
    if offsetWindow and offsetWindow:isVisible() then
      OffsetManager.onRight()
    end
  end, rootPanel)

  g_keyboard.bindKeyPress('Ctrl+Up', function()
    if offsetWindow and offsetWindow:isVisible() then
      OffsetManager.toggleDirection('up')
    end
  end, rootPanel)

  g_keyboard.bindKeyPress('Ctrl+Down', function()
    if offsetWindow and offsetWindow:isVisible() then
      OffsetManager.toggleDirection('down')
    end
  end, rootPanel)

  g_keyboard.bindKeyPress('Ctrl+Left', function()
    if offsetWindow and offsetWindow:isVisible() then
      OffsetManager.toggleDirection('left')
    end
  end, rootPanel)

  g_keyboard.bindKeyPress('Ctrl+Right', function()
    if offsetWindow and offsetWindow:isVisible() then
      OffsetManager.toggleDirection('right')
    end
  end, rootPanel)

  g_keyboard.bindKeyPress('Alt+Left', function()
    if offsetWindow and offsetWindow:isVisible() then
      OffsetManager.decreaseOutfitId()
    end
  end, rootPanel)

  g_keyboard.bindKeyPress('Alt+Right', function()
    if offsetWindow and offsetWindow:isVisible() then
      OffsetManager.increaseOutfitId()
    end
  end, rootPanel)
end


function OffsetManager.onUp()
  local offsetYField = offsetWindow:recursiveGetChildById('offsetY')
  local currentY = tonumber(offsetYField:getText()) or 0
  offsetYField:setText(tostring(currentY - 1))
  OffsetManager.saveOffset()
end

function OffsetManager.onDown()
  local offsetYField = offsetWindow:recursiveGetChildById('offsetY')
  local currentY = tonumber(offsetYField:getText()) or 0
  offsetYField:setText(tostring(currentY + 1))
  OffsetManager.saveOffset()
end

function OffsetManager.onLeft()
  local offsetXField = offsetWindow:recursiveGetChildById('offsetX')
  local currentX = tonumber(offsetXField:getText()) or 0
  offsetXField:setText(tostring(currentX - 1))
  OffsetManager.saveOffset()
end

function OffsetManager.onRight()
  local offsetXField = offsetWindow:recursiveGetChildById('offsetX')
  local currentX = tonumber(offsetXField:getText()) or 0
  offsetXField:setText(tostring(currentX + 1))
  OffsetManager.saveOffset()
end

function OffsetManager.increaseOutfitId()
  local idInput = offsetWindow:getChildById('idInput')
  local currentId = tonumber(idInput:getText()) or 0
  local newId = currentId + 1
  idInput:setText(tostring(newId))
  OffsetManager.viewOffset()
end

function OffsetManager.decreaseOutfitId()
  local idInput = offsetWindow:getChildById('idInput')
  local currentId = tonumber(idInput:getText()) or 0
  if currentId > 1 then
    local newId = currentId - 1
    idInput:setText(tostring(newId))
    OffsetManager.viewOffset()
  elseif currentId == 1 then
    -- Não permite ir abaixo de 1, mas permite ir para 0 para limpar
    idInput:setText('0')
    OffsetManager.viewOffset()
  end
end


function setupNumericFields()
  local panel = offsetWindow:getChildById('OffsetPanel')

  local numericFields = {'offsetX', 'offsetY'}
  for _, fieldId in ipairs(numericFields) do
    local field = panel:getChildById(fieldId)
    if field then
      field.onTextChange = function() validateNumericInput(field) end
    end
  end
end

function OffsetManager.reloadOtmlFile()
  local version = g_game.getClientVersion()
  local otmlPath = resolvepath('/things/' .. version .. '/Tibia.otml')

  if g_things.loadOtml(otmlPath) then
    OffsetManager.viewOffset()
  end
end


function OffsetManager.toggleOpacityMode()
  local selectedOption = offsetWindow:getChildById('effectOpacityComboBox'):getText()
  local opacityPanel = offsetWindow:getChildById('OpacityPanel')
  local offsetXField = offsetWindow:recursiveGetChildById('offsetX')
  local offsetYField = offsetWindow:recursiveGetChildById('offsetY')

  if selectedOption == 'Opacity' then
    opacityPanel:setVisible(true)
    offsetXField:setVisible(false)
    offsetYField:setVisible(false)
  else
    opacityPanel:setVisible(false)
    offsetXField:setVisible(true)
    offsetYField:setVisible(true)
  end
end

function updateOffsetFields()
  local offsetXField = offsetWindow:recursiveGetChildById('offsetX')
  local offsetYField = offsetWindow:recursiveGetChildById('offsetY')

  if not currentDirection then
    return
  end

  local currentOffsetX = offsets[currentDirection].offsetX or 0
  local currentOffsetY = offsets[currentDirection].offsetY or 0

  offsetXField:setText(tostring(currentOffsetX))
  offsetYField:setText(tostring(currentOffsetY))
end

function OffsetManager.loadAndShowOutfit(outfitId)
  if not outfitId or outfitId == 0 then
    outfitWidget:hide()
    return
  end

  local outfit = { type = outfitId, head = 78, body = 68, legs = 58, feet = 76, direction = currentDirection }
  outfitWidget:show()
  itemWidget:hide()
  outfitWidget:setOutfit(outfit)
end

function OffsetManager.loadAndShowItem(itemId)
  local item = Item.create(itemId, 1)
  if item then
    itemWidget:show()
    outfitWidget:hide()
    itemWidget:setItem(item)
  end
end

function OffsetManager.loadAndShowEffect(effectId)
  if not effectId or effectId == 0 then
    effectWidget:hide()
    return
  end

  local effect = Effect.create()
  if not effect then
    return
  end

  effect:setEffect(effectId)

  effectWidget:show()
  outfitWidget:hide()
  itemWidget:hide()

  if effectWidget.setEffect then
    effectWidget:setEffect(effect)
  end
end

function OffsetManager.toggleSubOutfitDisplacement()
  isSubOutfitEnabled = not isSubOutfitEnabled

  updateSubOutfitCheckbox(isSubOutfitEnabled)

end

function updateSubOutfitCheckbox(enabled)
  -- Obt�m o CheckBox de forma segura e atualiza seu estado visual
  local checkBox = offsetWindow:recursiveGetChildById('subOutfitCheckBox')
  if checkBox then
    checkBox:setChecked(enabled)
  else
  end
end

function OffsetManager.viewOffset()
  local id = tonumber(offsetWindow:getChildById('idInput'):getText())
  local subId = tonumber(offsetWindow:getChildById('subIdInput') and offsetWindow:getChildById('subIdInput'):getText())
  local isSubOutfitChecked = offsetWindow:recursiveGetChildById('subOutfitCheckBox'):isChecked()

  if not id or id <= 0 then
    return
  end

  local selectedOption = offsetWindow:getChildById('offsetComboBox'):getText()
  local displacementTypeComboBox = offsetWindow:getChildById('displacementTypeComboBox')
  local displacementType = displacementTypeComboBox:getText()

  local offsetXField = offsetWindow:recursiveGetChildById('offsetX')
  local offsetYField = offsetWindow:recursiveGetChildById('offsetY')

  local opacityOutfitPanel = offsetWindow:getChildById('OpacityOutfit')
  local opacityFieldOutfit = opacityOutfitPanel and opacityOutfitPanel:getChildById('opacityInput')

  local opacityPanel = offsetWindow:getChildById('OpacityPanel')
  local opacityFieldPanel = opacityPanel and opacityPanel:getChildById('opacityInput')

  if not opacityFieldOutfit or not opacityFieldPanel then
    return
  end

  -- Verifica se é SubOutfit + Name Displacement
  if selectedOption == 'Outfit' and isSubOutfitChecked and subId and subId > 0 then
    local subData = otmlData.creatures[id] and otmlData.creatures[id].subOutfitDisplacements and otmlData.creatures[id].subOutfitDisplacements[subId]
    if subData then
      if displacementType == "Name Displacement" and subData["name-displacement"] then
        local nameDisp = subData["name-displacement"]
        local northOffset = nameDisp.North or "0 0"
        local eastOffset = nameDisp.East or "0 0"
        local southOffset = nameDisp.South or "0 0"
        local westOffset = nameDisp.West or "0 0"

        offsets["up"].offsetX, offsets["up"].offsetY = northOffset:match("(%-?%d+)%s+(%-?%d+)")
        offsets["right"].offsetX, offsets["right"].offsetY = eastOffset:match("(%-?%d+)%s+(%-?%d+)")
        offsets["down"].offsetX, offsets["down"].offsetY = southOffset:match("(%-?%d+)%s+(%-?%d+)")
        offsets["left"].offsetX, offsets["left"].offsetY = westOffset:match("(%-?%d+)%s+(%-?%d+)")
      else
        local northOffset = subData.North or "0 0"
        local eastOffset = subData.East or "0 0"
        local southOffset = subData.South or "0 0"
        local westOffset = subData.West or "0 0"

        offsets["up"].offsetX, offsets["up"].offsetY = northOffset:match("(%-?%d+)%s+(%-?%d+)")
        offsets["right"].offsetX, offsets["right"].offsetY = eastOffset:match("(%-?%d+)%s+(%-?%d+)")
        offsets["down"].offsetX, offsets["down"].offsetY = southOffset:match("(%-?%d+)%s+(%-?%d+)")
        offsets["left"].offsetX, offsets["left"].offsetY = westOffset:match("(%-?%d+)%s+(%-?%d+)")
      end

      offsetXField:setText(tostring(offsets["down"].offsetX or 0))
      offsetYField:setText(tostring(offsets["down"].offsetY or 0))
      opacityFieldOutfit:setText(string.format("%.1f", subData.opacity or 1.0))
    end

    updateOffsetFields()
    OffsetManager.loadAndShowOutfit(subId)
    OffsetManager.toggleDirection("down")
    return
  end

  if selectedOption == 'Outfit' then
    if displacementType == 'Outfit Displacement' then
      local outfitDisplacement = otmlData.creatures[id] and otmlData.creatures[id]["outfit-displacement"]
      if outfitDisplacement then
        local northOffset = outfitDisplacement.North or "0 0"
        local eastOffset = outfitDisplacement.East or "0 0"
        local southOffset = outfitDisplacement.South or "0 0"
        local westOffset = outfitDisplacement.West or "0 0"

        offsets["up"].offsetX, offsets["up"].offsetY = northOffset:match("(%-?%d+)%s+(%-?%d+)")
        offsets["right"].offsetX, offsets["right"].offsetY = eastOffset:match("(%-?%d+)%s+(%-?%d+)")
        offsets["down"].offsetX, offsets["down"].offsetY = southOffset:match("(%-?%d+)%s+(%-?%d+)")
        offsets["left"].offsetX, offsets["left"].offsetY = westOffset:match("(%-?%d+)%s+(%-?%d+)")
        opacityFieldOutfit:setText(string.format("%.1f", outfitDisplacement.opacity or 1.0))
      else
        offsets["up"].offsetX, offsets["up"].offsetY = 0, 0
        offsets["right"].offsetX, offsets["right"].offsetY = 0, 0
        offsets["down"].offsetX, offsets["down"].offsetY = 0, 0
        offsets["left"].offsetX, offsets["left"].offsetY = 0, 0

        opacityFieldOutfit:setText('1.0')
      end

    -- NOVO: tratamento para Name Displacement
    elseif displacementType == 'Name Displacement' then
      local nameDisplacement = otmlData.creatures[id] and otmlData.creatures[id]["name-displacement"]
      if nameDisplacement then
        local northOffset = nameDisplacement.North or "0 0"
        local eastOffset = nameDisplacement.East or "0 0"
        local southOffset = nameDisplacement.South or "0 0"
        local westOffset = nameDisplacement.West or "0 0"

        offsets["up"].offsetX, offsets["up"].offsetY = northOffset:match("(%-?%d+)%s+(%-?%d+)")
        offsets["right"].offsetX, offsets["right"].offsetY = eastOffset:match("(%-?%d+)%s+(%-?%d+)")
        offsets["down"].offsetX, offsets["down"].offsetY = southOffset:match("(%-?%d+)%s+(%-?%d+)")
        offsets["left"].offsetX, offsets["left"].offsetY = westOffset:match("(%-?%d+)%s+(%-?%d+)")
      else
        offsets["up"].offsetX, offsets["up"].offsetY = 0, 0
        offsets["right"].offsetX, offsets["right"].offsetY = 0, 0
        offsets["down"].offsetX, offsets["down"].offsetY = 0, 0
        offsets["left"].offsetX, offsets["left"].offsetY = 0, 0
      end
      -- Atualiza os campos e exibe o outfit com os valores de Name Displacement
      updateOffsetFields()
      OffsetManager.loadAndShowOutfit(id)
      
    elseif displacementType == 'Target Displacement' then
      local targetDisplacement = otmlData.creatures[id] and otmlData.creatures[id]["target-displacement"]
      if targetDisplacement then
        local northOffset = targetDisplacement.North or "0 0"
        local eastOffset = targetDisplacement.East or "0 0"
        local southOffset = targetDisplacement.South or "0 0"
        local westOffset = targetDisplacement.West or "0 0"

        offsets["up"].offsetX, offsets["up"].offsetY = northOffset:match("(%-?%d+)%s+(%-?%d+)")
        offsets["right"].offsetX, offsets["right"].offsetY = eastOffset:match("(%-?%d+)%s+(%-?%d+)")
        offsets["down"].offsetX, offsets["down"].offsetY = southOffset:match("(%-?%d+)%s+(%-?%d+)")
        offsets["left"].offsetX, offsets["left"].offsetY = westOffset:match("(%-?%d+)%s+(%-?%d+)")
      else
        offsets["up"].offsetX, offsets["up"].offsetY = 0, 0
        offsets["right"].offsetX, offsets["right"].offsetY = 0, 0
        offsets["down"].offsetX, offsets["down"].offsetY = 0, 0
        offsets["left"].offsetX, offsets["left"].offsetY = 0, 0
      end

    end

    updateOffsetFields()
    OffsetManager.loadAndShowOutfit(id)
  end

  if selectedOption == 'Item' then
    local itemDisplacement = otmlData.items[id] and otmlData.items[id]["item-displacement"]
    if itemDisplacement then
      offsetXField:setText(tostring(itemDisplacement.x or 0))
      offsetYField:setText(tostring(itemDisplacement.y or 0))
      opacityFieldPanel:setText(string.format("%.1f", itemDisplacement.opacity or 1.0))
    else
      offsetXField:setText('0')
      offsetYField:setText('0')
      opacityFieldPanel:setText('1.0')
    end
    OffsetManager.loadAndShowItem(id)

  elseif selectedOption == 'Effect' then
    local effectDisplacement = otmlData.effects[id] and otmlData.effects[id]["effect-displacement"]
    if effectDisplacement then
      offsetXField:setText(tostring(effectDisplacement.x or 0))
      offsetYField:setText(tostring(effectDisplacement.y or 0))
      opacityFieldPanel:setText(string.format("%.1f", effectDisplacement.opacity or 1.0))
    else
      offsetXField:setText('0')
      offsetYField:setText('0')
      opacityFieldPanel:setText('1.0')
    end
    OffsetManager.loadAndShowEffect(id)
  end

  OffsetManager.toggleDirection("down")
  offsetWindow:recursiveGetChildById('checkDown'):setChecked(true)
end



function OffsetManager.saveOffset()
  local id = tonumber(offsetWindow:getChildById('idInput'):getText())
  local isSubOutfitChecked = offsetWindow:recursiveGetChildById('subOutfitCheckBox'):isChecked()
  local subId = nil
  local selectedDirection = currentDirection
  local displacementType = offsetWindow:getChildById('displacementTypeComboBox'):getText()

  if isSubOutfitChecked then
    local subIdInput = offsetWindow:getChildById('subIdInput')
    if subIdInput then
      subId = tonumber(subIdInput:getText())
    end
  end

  if not id or id <= 0 then return end

  local opacityOutfitPanel = offsetWindow:getChildById('OpacityOutfit')
  local opacityFieldOutfit = opacityOutfitPanel and opacityOutfitPanel:getChildById('opacityInput')
  local opacityPanel = offsetWindow:getChildById('OpacityPanel')
  local opacityFieldPanel = opacityPanel and opacityPanel:getChildById('opacityInput')

  local subOutfitOpacityValue = 1.0
  if opacityFieldOutfit and isSubOutfitChecked then
    subOutfitOpacityValue = tonumber(opacityFieldOutfit:getText()) or 1.0
  end

  local outfitOpacityValue = 1.0
  if not isSubOutfitChecked and opacityFieldOutfit then
    outfitOpacityValue = tonumber(opacityFieldOutfit:getText()) or 1.0
  end

  local itemEffectOpacityValue = 1.0
  if opacityFieldPanel then
    itemEffectOpacityValue = tonumber(opacityFieldPanel:getText()) or 1.0
  end

  local previousDirection = currentDirection
  if previousDirection then
    offsets[previousDirection].offsetX = tonumber(offsetWindow:recursiveGetChildById('offsetX'):getText()) or 0
    offsets[previousDirection].offsetY = tonumber(offsetWindow:recursiveGetChildById('offsetY'):getText()) or 0
  end

  local displacement = {
    North = {offsets["up"].offsetX or 0, offsets["up"].offsetY or 0},
    East = {offsets["right"].offsetX or 0, offsets["right"].offsetY or 0},
    South = {offsets["down"].offsetX or 0, offsets["down"].offsetY or 0},
    West = {offsets["left"].offsetX or 0, offsets["left"].offsetY or 0}
  }

  if isSubOutfitChecked and subId and subId > 0 then
    otmlData.creatures[id] = otmlData.creatures[id] or {}
    otmlData.creatures[id]["subOutfitDisplacements"] = otmlData.creatures[id]["subOutfitDisplacements"] or {}
    otmlData.creatures[id]["subOutfitDisplacements"][subId] = otmlData.creatures[id]["subOutfitDisplacements"][subId] or {}

    if displacementType == "Name Displacement" then
      otmlData.creatures[id]["subOutfitDisplacements"][subId]["name-displacement"] = {}
      for direction, coords in pairs(displacement) do
        otmlData.creatures[id]["subOutfitDisplacements"][subId]["name-displacement"][direction] =
          string.format("%d %d", coords[1], coords[2])
      end
    else
      for direction, coords in pairs(displacement) do
        otmlData.creatures[id]["subOutfitDisplacements"][subId][direction] = string.format("%d %d", coords[1], coords[2])
      end
      otmlData.creatures[id]["subOutfitDisplacements"][subId].opacity = subOutfitOpacityValue
    end

    saveOtmlFile()
    OffsetManager.reloadOtmlFile()

    if selectedDirection then
      OffsetManager.toggleDirection(selectedDirection)
    end
    return
  end

  local selectedOption = offsetWindow:getChildById('offsetComboBox'):getText()

  if selectedOption == 'Outfit' then
    otmlData.creatures[id] = otmlData.creatures[id] or {}

    if displacementType == 'Outfit Displacement' then
      otmlData.creatures[id]["outfit-displacement"] = otmlData.creatures[id]["outfit-displacement"] or {}
      for direction, coords in pairs(displacement) do
        otmlData.creatures[id]["outfit-displacement"][direction] = string.format("%d %d", coords[1], coords[2])
      end
      otmlData.creatures[id]["outfit-displacement"].opacity = outfitOpacityValue

    elseif displacementType == 'Name Displacement' then
      otmlData.creatures[id]["name-displacement"] = otmlData.creatures[id]["name-displacement"] or {}
      for direction, coords in pairs(displacement) do
        otmlData.creatures[id]["name-displacement"][direction] = string.format("%d %d", coords[1], coords[2])
      end

    elseif displacementType == 'Target Displacement' then
      otmlData.creatures[id]["target-displacement"] = otmlData.creatures[id]["target-displacement"] or {}
      for direction, coords in pairs(displacement) do
        otmlData.creatures[id]["target-displacement"][direction] = string.format("%d %d", coords[1], coords[2])
      end
    end

  elseif selectedOption == 'Item' then
    otmlData.items[id] = otmlData.items[id] or {}
    otmlData.items[id]["item-displacement"] = otmlData.items[id]["item-displacement"] or {}
    otmlData.items[id]["item-displacement"].x = tonumber(offsetWindow:recursiveGetChildById('offsetX'):getText()) or 0
    otmlData.items[id]["item-displacement"].y = tonumber(offsetWindow:recursiveGetChildById('offsetY'):getText()) or 0
    otmlData.items[id]["item-displacement"].opacity = itemEffectOpacityValue

  elseif selectedOption == 'Effect' then
    otmlData.effects[id] = otmlData.effects[id] or {}
    otmlData.effects[id]["effect-displacement"] = otmlData.effects[id]["effect-displacement"] or {}
    otmlData.effects[id]["effect-displacement"].x = tonumber(offsetWindow:recursiveGetChildById('offsetX'):getText()) or 0
    otmlData.effects[id]["effect-displacement"].y = tonumber(offsetWindow:recursiveGetChildById('offsetY'):getText()) or 0
    otmlData.effects[id]["effect-displacement"].opacity = itemEffectOpacityValue
  end

  saveOtmlFile()
  OffsetManager.reloadOtmlFile()

  if selectedDirection then
    OffsetManager.toggleDirection(selectedDirection)
  end
end


function OffsetManager.deleteOffset()
  local id = tonumber(offsetWindow:getChildById('idInput'):getText())
  local subId = tonumber(offsetWindow:getChildById('subIdInput') and offsetWindow:getChildById('subIdInput'):getText())
  local isSubOutfitChecked = offsetWindow:recursiveGetChildById('subOutfitCheckBox'):isChecked()

  if not id or id <= 0 then
    displayErrorBox("Erro", "Por favor, insira um ID válido para deletar.")
    return
  end

  local selectedOption = offsetWindow:getChildById('offsetComboBox'):getText()
  local displacementType = offsetWindow:getChildById('displacementTypeComboBox'):getText()

  if isSubOutfitChecked and subId and subId > 0 then
    local subDisplacements = otmlData.creatures[id]
      and otmlData.creatures[id]["subOutfitDisplacements"]
      and otmlData.creatures[id]["subOutfitDisplacements"][subId]

    if subDisplacements then
      if displacementType == "Name Displacement" then
        otmlData.creatures[id]["subOutfitDisplacements"][subId]["name-displacement"] = nil
        displayInfoBox("Reset", "SubOutfit name-displacement removido com sucesso!")
      else
        otmlData.creatures[id]["subOutfitDisplacements"][subId] = {
          opacity = 1.0,
          North = "0 0",
          East = "0 0",
          South = "0 0",
          West = "0 0"
        }
        displayInfoBox("Reset", "SubOutfit displacement redefinido com sucesso!")
      end
    else
      displayErrorBox("Erro", "Nenhum subOutfit displacement encontrado para o ID e SubID fornecidos.")
    end

  elseif selectedOption == 'Outfit' then
    if displacementType == 'Outfit Displacement' then
      if otmlData.creatures[id] then
        otmlData.creatures[id]["outfit-displacement"] = {
          opacity = 1.0,
          North = "0 0",
          East = "0 0",
          South = "0 0",
          West = "0 0"
        }
        displayInfoBox("Reset", "Outfit displacement redefinido com sucesso!")
      else
        displayErrorBox("Erro", "Nenhum outfit displacement encontrado para o ID fornecido.")
      end
    elseif displacementType == 'Name Displacement' then
      if otmlData.creatures[id] then
        otmlData.creatures[id]["name-displacement"] = {
          North = "0 0",
          East = "0 0",
          South = "0 0",
          West = "0 0"
        }
        displayInfoBox("Reset", "Name displacement redefinido com sucesso!")
      else
        displayErrorBox("Erro", "Nenhum name displacement encontrado para o ID fornecido.")
      end
    elseif displacementType == 'Target Displacement' then
      if otmlData.creatures[id] then
        otmlData.creatures[id]["target-displacement"] = {
          North = "0 0",
          East = "0 0",
          South = "0 0",
          West = "0 0"
        }
        displayInfoBox("Reset", "Target displacement redefinido com sucesso!")
      else
        displayErrorBox("Erro", "Nenhum target displacement encontrado para o ID fornecido.")
      end
    end

  elseif selectedOption == 'Item' then
    if otmlData.items[id] then
      otmlData.items[id]["item-displacement"] = {
        opacity = 1.0,
        x = 0,
        y = 0
      }
      displayInfoBox("Reset", "Item displacement redefinido com sucesso!")
    else
      displayErrorBox("Erro", "Nenhum item displacement encontrado para o ID fornecido.")
    end

  elseif selectedOption == 'Effect' then
    if otmlData.effects[id] then
      otmlData.effects[id]["effect-displacement"] = {
        opacity = 1.0,
        x = 0,
        y = 0
      }
      displayInfoBox("Reset", "Effect displacement redefinido com sucesso!")
    else
      displayErrorBox("Erro", "Nenhum effect displacement encontrado para o ID fornecido.")
    end

  else
    displayErrorBox("Erro", "Opção selecionada inválida.")
    return
  end

  saveOtmlFile()
  OffsetManager.reloadOtmlFile()
end


function saveOtmlFile()
  local otmlPath = resolveOtmlPath()
  local directoryPath = otmlPath:match("(.+)/[^/]+$")
  if not g_resources.directoryExists(directoryPath) then
    g_resources.makeDir(directoryPath)
  end

  local fileContents = generateOtmlString(otmlData)
  local file, err = io.open(otmlPath, "w+")
  if file then
    file:write(fileContents)
    file:close()
  else
  end
end


function resolveOtmlPath()
  return directory .. filename
end


function tableToString(tbl, indent)
  indent = indent or 0
  if type(tbl) ~= "table" then
    return tostring(tbl)
  end
  local result = {}
  local padding = string.rep("  ", indent)
  for key, value in pairs(tbl) do
    if type(value) == "table" then
      table.insert(result, padding .. tostring(key) .. ": " .. tableToString(value, indent + 1))
    else
      table.insert(result, padding .. tostring(key) .. ": " .. tostring(value))
    end
  end
  return "{\n" .. table.concat(result, ",\n") .. "\n" .. string.rep("  ", indent - 1) .. "}"
end


function loadOtmlFile()
  local fileContents = g_resources.readFileContents('/things/860/Tibia.otml')
  if fileContents then
    local existingData = parseOtml(fileContents)
    
    for category, entries in pairs(existingData) do
      for id, entry in pairs(entries) do
        for key, values in pairs(entry) do
          if type(values) == "table" then
            if key == "subOutfitDisplacements" then
              for subId, subValues in pairs(values) do
                if type(subValues) == "table" then
                  if subValues.opacity then
                  end
                  for direction, coords in pairs(subValues) do
                    if direction ~= "opacity" then
                    end
                  end
                end
              end
            else
              local parts = {}
              for subKey, subValue in pairs(values) do
                table.insert(parts, string.format("%s: %s", subKey, tostring(subValue)))
              end
            end
          end
        end
      end
    end

    otmlData = mergeOtmlData(otmlData, existingData)
  else
    otmlData = {creatures = {}, items = {}, effects = {}}
  end
end

function mergeOtmlData(newData, existingData)
  for category, data in pairs(existingData) do
    newData[category] = newData[category] or {}
    for id, values in pairs(data) do
      newData[category][id] = newData[category][id] or {}
      for key, displacement in pairs(values) do
        if key == "subOutfitDisplacements" then
          newData[category][id][key] = newData[category][id][key] or {}
          for subId, subDisplacement in pairs(displacement) do
            if not newData[category][subId] then
              newData[category][id][key][subId] = subDisplacement
            else
            end
          end
        elseif key == "item-displacement" or key == "effect-displacement" then
          -- Mescla lógica de items e effects
          newData[category][id][key] = newData[category][id][key] or {}
          for attr, value in pairs(displacement) do
            if value ~= nil then
              newData[category][id][key][attr] = value
            end
          end
        else
          -- Mescla outros deslocamentos ou propriedades
          newData[category][id][key] = displacement
        end
      end
    end
  end
  return newData
end



function parseOtml(contents)
  local data = { creatures = {}, items = {}, effects = {} }
  local currentCategory, currentId, currentDisplacementType, currentSubId

  for line in contents:gmatch("[^\r\n]+") do
    line = line:match("^%s*(.-)%s*$") -- Trim whitespaces

    if line:find("creatures:") then
      currentCategory = "creatures"
      currentId, currentDisplacementType, currentSubId = nil, nil, nil

    elseif line:find("items:") then
      currentCategory = "items"
      currentId, currentDisplacementType, currentSubId = nil, nil, nil

    elseif line:find("effects:") then
      currentCategory = "effects"
      currentId, currentDisplacementType, currentSubId = nil, nil, nil

    elseif line:match("^%d+:$") then
      local newId = tonumber(line:match("^(%d+):"))
      if currentDisplacementType == "subOutfitDisplacements" and currentSubId == nil then
        currentSubId = newId
        data[currentCategory][currentId][currentDisplacementType][currentSubId] = {}
      elseif currentDisplacementType == "subOutfitDisplacements" then
        currentDisplacementType, currentSubId = nil, nil
        currentId = newId
        data[currentCategory][currentId] = data[currentCategory][currentId] or {}
      else
        currentId = newId
        data[currentCategory][currentId] = data[currentCategory][currentId] or {}
      end

    elseif line:match("subOutfitDisplacements:") then
      currentDisplacementType = "subOutfitDisplacements"
      data[currentCategory][currentId][currentDisplacementType] = data[currentCategory][currentId][currentDisplacementType] or {}

    elseif currentDisplacementType == "subOutfitDisplacements" and currentSubId then
      local target = data[currentCategory][currentId][currentDisplacementType][currentSubId]
      local nameDisplacement = {}

      for key, value in line:gmatch("([%w%-]+):%s*([%-?%d]+%s*[%-?%d]*)") do
        if key == "opacity" then
          target.opacity = tonumber(value)
        elseif key:match("^%u") then
          target[key] = value
        end
      end

      if line:find("name%-displacement:") then
        for dir, val in line:match("name%-displacement:%s*(.*)"):gmatch("([%a]+):%s*([%-?%d]+%s*[%-?%d]+)") do
          nameDisplacement[dir] = val
        end
        target["name-displacement"] = nameDisplacement
      end

    elseif currentCategory == "items" or currentCategory == "effects" then
      local key, inlineValues = line:match("(%w+%-displacement):%s*(.+)")
      if key and inlineValues then
        data[currentCategory][currentId][key] = {}
        for attr, value in inlineValues:gmatch("(%w+):%s*([%-?%d%.]+)") do
          data[currentCategory][currentId][key][attr] = tonumber(value) or value
        end
      end

    elseif line:find("outfit%-displacement:") or line:find("target%-displacement:") then
      local displacementKey = line:match("(%w+%-displacement):")
      local target = data[currentCategory][currentId]
      target[displacementKey] = target[displacementKey] or {}

      for direction, coords in line:gmatch("(%w+):%s*([%-?%d]+%s+[%-?%d]+)") do
        target[displacementKey][direction] = coords
      end

      local opacity = line:match("opacity:%s*(%-?%d+%.?%d*)")
      if opacity then
        target[displacementKey].opacity = tonumber(opacity)
      end

    elseif line:find("name%-displacement:") then
      local target = data[currentCategory][currentId]
      target["name-displacement"] = {}

      for direction, coords in line:match("name%-displacement:%s*(.*)"):gmatch("(%w+):%s*([%-?%d]+%s*[%-?%d]+)") do
        target["name-displacement"][direction] = coords
      end
    end
  end

  return data
end


function generateOtmlString(data)
  local contents = {}

  local function addLine(line)
    table.insert(contents, line)
  end

  local function sortKeys(tbl)
    local keys = {}
    for key in pairs(tbl) do
      table.insert(keys, key)
    end
    table.sort(keys)
    return keys
  end

  local order = {
    ["target-displacement"] = 1,
    ["name-displacement"] = 2,
    ["outfit-displacement"] = 3,
    ["subOutfitDisplacements"] = 4,
  }

  for category, entries in pairs(data) do
    addLine(category .. ":")
    local sortedIDs = sortKeys(entries)
    for _, id in ipairs(sortedIDs) do
      addLine("  " .. id .. ":")
      local entry = entries[id]

      local keys = sortKeys(entry)
      table.sort(keys, function(a, b)
        return (order[a] or 999) < (order[b] or 999)
      end)

      for _, key in ipairs(keys) do
        local values = entry[key]
        if key == "subOutfitDisplacements" then
          addLine("    " .. key .. ":")
          local subSortedIDs = sortKeys(values)
          for _, subId in ipairs(subSortedIDs) do
            addLine("      " .. subId .. ":")
            local subValues = values[subId]

            -- Main offsets
            local parts = {}
            if subValues.opacity then
              table.insert(parts, string.format("opacity: %.1f", subValues.opacity))
            end
            for direction, coords in pairs(subValues) do
              if direction ~= "opacity" and direction ~= "name-displacement" then
                table.insert(parts, string.format("%s: %s", direction, coords))
              end
            end
            if #parts > 0 then
              addLine("        " .. table.concat(parts, ", "))
            end

            -- Name-displacement block
            if subValues["name-displacement"] then
              local nameParts = {}
              for direction, coords in pairs(subValues["name-displacement"]) do
                table.insert(nameParts, string.format("%s: %s", direction, coords))
              end
              if #nameParts > 0 then
                addLine("        name-displacement: " .. table.concat(nameParts, ", "))
              end
            end
          end
        elseif category == "items" or category == "effects" then
          local parts = {}
          for attr, value in pairs(values) do
            table.insert(parts, string.format("%s: %s", attr, tostring(value)))
          end
          addLine(string.format("    %s: %s", key, table.concat(parts, ", ")))
        else
          local parts = {}
          if type(values) == "table" then
            if values.opacity then
              table.insert(parts, string.format("opacity: %.1f", values.opacity))
            end
            for direction, coords in pairs(values) do
              if direction ~= "opacity" then
                table.insert(parts, string.format("%s: %s", direction, coords))
              end
            end
            if #parts > 0 then
              addLine("    " .. key .. ": " .. table.concat(parts, ", "))
            end
          else
            addLine("    " .. key .. ": " .. tostring(values))
          end
        end
      end
    end
  end

  return table.concat(contents, "\n")
end


function backupOtmlFile()
  local originalPath = resolveOtmlPath()
  local backupPath = directory .. "Tibia_backup.otml"

  local backupContents = generateOtmlString(otmlData)

  local backupFile, err = io.open(backupPath, "w+")
  if backupFile then
    backupFile:write(backupContents)
    backupFile:close()
  else
  end
end

function OffsetManager.resetOffset()
  offsetWindow:recursiveGetChildById('offsetX'):setText('0')
  offsetWindow:recursiveGetChildById('offsetY'):setText('0')

  local opacityOutfitPanel = offsetWindow:getChildById('OpacityOutfit')
  local opacityFieldOutfit = opacityOutfitPanel and opacityOutfitPanel:getChildById('opacityInput')
  
  local opacityPanel = offsetWindow:getChildById('OpacityPanel')
  local opacityFieldPanel = opacityPanel and opacityPanel:getChildById('opacityInput')

  if opacityFieldOutfit then
    opacityFieldOutfit:setText('1.0')
  end

  if opacityFieldPanel then
    opacityFieldPanel:setText('1.0')
  end

  outfitWidget:hide()
  itemWidget:hide()

  offsets["up"].offsetX = 0
  offsets["up"].offsetY = 0
  offsets["right"].offsetX = 0
  offsets["right"].offsetY = 0
  offsets["down"].offsetX = 0
  offsets["down"].offsetY = 0
  offsets["left"].offsetX = 0
  offsets["left"].offsetY = 0

  offsetWindow:recursiveGetChildById('idInput'):setText('')
end
