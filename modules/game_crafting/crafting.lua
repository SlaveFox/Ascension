local CODE = 122

local window = nil
local windowBtn = nil
local categories = nil
local craftPanel = nil
local itemsList = nil
local selectedCategory = nil
local selectedCraftId = nil
local Crafts = { weapons = {}, equipment = {}, potions = {}, upgrades = {}, shields = {}, others = {} }
local vocations = { "All" }

local function uiReady()
  return window and categories and itemsList and craftPanel
end

function init()
  connect(g_game, { onGameStart = create, onGameEnd = destroy })
  ProtocolGame.registerExtendedOpcode(CODE, onExtendedOpcode)
  if g_game.isOnline() then create() end
end

function terminate()
  disconnect(g_game, { onGameStart = create, onGameEnd = destroy })
  ProtocolGame.unregisterExtendedOpcode(CODE, onExtendedOpcode)
  destroy()
end

function create()
  if window then return end
  windowBtn = modules.client_topmenu.addRightGameToggleButton("crafting", tr("Crafting"), "/images/topbuttons/modulemanager", toggle)
  windowBtn:setOn(false)
  buttonCraft = modules.client_topmenu.addLeftButton("buttonCraft", "Craft", "/data/images/topbuttons/craft", toggle)
  buttonCraft:setOn(false)
  window = g_ui.displayUI("crafting")
  window:hide()
  categories = window:getChildById("categories")
  craftPanel = window:getChildById("craftPanel")
  itemsList = window:getChildById("itemsList")
  local vocDrop = window:recursiveGetChildById("vocations")
  if vocDrop:getOptionsCount() == 0 then
    vocDrop.onOptionChange = onVocationChange
    for i = 1, #vocations do
      vocDrop:addOption(vocations[i], i)
    end
    vocDrop:setCurrentIndex(1)
  end
  vocDrop.menuHeight = 125
  vocDrop.menuScroll = false
  local protocolGame = g_game.getProtocolGame()
  if protocolGame then
    protocolGame:sendExtendedOpcode(CODE, json.encode({ action = "fetch" }))
  end
end

function destroy()
  if windowBtn then
    windowBtn:destroy()
    windowBtn = nil
  end
  if window then
    categories = nil
    craftPanel = nil
    itemsList = nil
    selectedCategory = nil
    selectedCraftId = nil
    Crafts = { weapons = {}, equipment = {}, potions = {}, upgrades = {}, shields = {}, others = {} }
    window:destroy()
    window = nil
  end
end

function onExtendedOpcode(protocol, code, buffer)
  local ok, json_data = pcall(function() return json.decode(buffer) end)
  if not ok or type(json_data) ~= "table" then
    g_logger.error("[Crafting] JSON error: " .. tostring(buffer))
    return false
  end

  local action = json_data.action
  local data   = json_data.data or {}

  -- Ensure category bucket exists when a category is provided
  if data.category and not Crafts[data.category] then
    Crafts[data.category] = {}
  end

  if action == "fetch" then
    -- Fail-safe: ignore if payload malformed
    if not data.category or type(data.crafts) ~= "table" then return end

    -- Append new crafts to the category bucket
    local bucket = Crafts[data.category]
    for i = 1, #data.crafts do
      bucket[#bucket + 1] = data.crafts[i]
    end

    -- If nothing selected yet, default once
    if not selectedCategory then
      selectedCategory = "weapons"
      if uiReady() then
        local catBtn = categories:getChildById(selectedCategory .. "Cat")
        if catBtn then catBtn:setOn(true) end
      end
    end

    -- Only touch UI if it’s ready and we’re looking at this category
    if uiReady() and selectedCategory == data.category then
      itemsList:destroyChildren()
      local list = Crafts[selectedCategory] or {}
      for i = 1, #list do
        local craft = list[i]
        local w = g_ui.createWidget("ItemListItem")
        w:setId(i)
        w:getChildById("item"):setItemId(craft.item and craft.item.id or 0)
        w:getChildById("name"):setText(craft.name or "?")
        w:getChildById("level"):setText("Level " .. tostring(craft.level or 0))
        itemsList:addChild(w)
        if i == 1 then w:focus() end
      end
      selectItem(1)
    end

  elseif action == "materials" then
    -- Update only data (safe even without UI); guard all indexes
    if not data.category or not data.from or type(data.materials) ~= "table" then return end
    local list = Crafts[data.category] or {}

    for i = 1, #data.materials do
      local matRow = data.materials[i]
      local craftIndex = (data.from or 1) + i - 1
      local craft     = list[craftIndex]
      if craft and type(craft.materials) == "table" and type(matRow) == "table" then
        for x = 1, #matRow do
          local mats = craft.materials[x]
          if mats then mats.player = matRow[x] end
        end
      end
    end

    -- If first page of materials and UI is open on this category, refresh the selected
    if data.from == 1 and uiReady() and selectedCategory == data.category then
      selectItem(selectedCraftId)
    end

  elseif action == "show" then
    if uiReady() then
      show()
      selectItem(selectedCraftId)
    end

  elseif action == "crafted" then
    onItemCrafted()
  end
end


function onItemCrafted()
  if selectedCategory and selectedCraftId then
    local craft = Crafts[selectedCategory][selectedCraftId]
    if craft then
      for i = 1, #craft.materials do
        local materialWidget = craftPanel:getChildById("craftLine" .. i)
        materialWidget:setImageSource("/images/crafting/craft_line" .. i .. "on")
        scheduleEvent(function() materialWidget:setImageSource("/images/crafting/craft_line" .. (i == 2 and 5 or i)) end, 850)
      end
      local button = craftPanel:getChildById("craftButton")
      button:disable()
      scheduleEvent(function() button:enable() end, 860)
    end
  end
end

function onSearch()
  scheduleEvent(function()
    local searchInput = window:recursiveGetChildById("searchInput")
    local text = searchInput:getText():lower()
    if text:len() >= 1 then
      local children = itemsList:getChildCount()
      for i = children, 1, -1 do
        local child = itemsList:getChildByIndex(i)
        local name = child:getChildById("name"):getText():lower()
        if name:find(text) then
          child:show()
          child:focus()
          selectItem(i)
        else
          child:hide()
        end
      end
    else
      local children = itemsList:getChildCount()
      local vocDrop = window:recursiveGetChildById("vocations")
      local vocId = vocDrop:getCurrentOption().data
      for i = children, 1, -1 do
        local child = itemsList:getChildByIndex(i)
        local craftId = tonumber(child:getId())
        local craft = Crafts[selectedCategory][craftId]
        if vocId == 1 then
          child:show()
          child:focus()
          selectItem(i)
        else
          if type(craft.vocation) == "table" then
            if table.contains(craft.vocation, vocId) then
              child:show()
              child:focus()
              selectItem(i)
            else
              child:hide()
            end
          else
            if craft.vocation ~= vocId then
              child:hide()
            else
              child:show()
              child:focus()
              selectItem(i)
            end
          end
        end
      end
    end
  end, 25)
end

function onVocationChange(widget, name, id)
  local searchInput = window:recursiveGetChildById("searchInput")
  local text = searchInput:getText():lower()
  if text:len() >= 1 then
    onSearch()
    return
  end
  local description = craftPanel:recursiveGetChildById("description")
  description:setText("")
  for i = 1, 6 do
    local materialWidget = craftPanel:getChildById("material" .. i)
    materialWidget:setItem(nil)
    craftPanel:getChildById("count" .. i):setText("")
  end
  local outcome = craftPanel:getChildById("craftOutcome")
  outcome:setItem(nil)
  craftPanel:recursiveGetChildById("totalCost"):setText("")
  local childCount = itemsList:getChildCount()
  for i = 1, childCount do
    local child = itemsList:getChildByIndex(i)
    local craftId = tonumber(child:getId())
    local craft = Crafts[selectedCategory][craftId]
    if id == 1 then
      child:show()
      if i == 1 then
        child:focus()
        selectItem(i)
      end
    else
      if type(craft.vocation) == "table" then
        if table.contains(craft.vocation, id) then
          child:show()
          if i == 1 then
            child:focus()
            selectItem(i)
          end
        else
          child:hide()
        end
      else
        if craft.vocation ~= id then
          child:hide()
        else
          child:show()
          if i == 1 then
            child:focus()
            selectItem(i)
          end
        end
      end
    end
  end
end

function selectCategory(category)
  if not category then return end
  if not Crafts[category] then Crafts[category] = {} end

  if selectedCategory and uiReady() then
    local oldCatBtn = categories:getChildById(selectedCategory .. "Cat")
    if oldCatBtn then oldCatBtn:setOn(false) end
  end

  selectedCategory = category

  if not uiReady() then return end

  local descriptionWidget = craftPanel:recursiveGetChildById("description")
  if descriptionWidget then descriptionWidget:setText("") end

  local newCatBtn = categories:getChildById(category .. "Cat")
  if newCatBtn then newCatBtn:setOn(true) end

  itemsList:destroyChildren()
  selectedCraftId = nil

  for i = 1, 6 do
    local materialWidget = craftPanel:getChildById("material" .. i)
    if materialWidget then materialWidget:setItem(nil) end
    local countWidget = craftPanel:getChildById("count" .. i)
    if countWidget then countWidget:setText("") end
  end

  local outcome = craftPanel:getChildById("craftOutcome")
  if outcome then outcome:setItem(nil) end
  local totalCost = craftPanel:recursiveGetChildById("totalCost")
  if totalCost then totalCost:setText("") end

  local list = Crafts[selectedCategory] or {}
  for i = 1, #list do
    local craft = list[i]
    local w = g_ui.createWidget("ItemListItem")
    w:setId(i)
    w:getChildById("item"):setItemId(craft.item and craft.item.id or 0)
    w:getChildById("name"):setText(craft.name or "?")
    w:getChildById("level"):setText("Level " .. tostring(craft.level or 0))
    itemsList:addChild(w)
    if i == 1 then
      w:focus()
      selectItem(1)
    end
  end
end

function selectItem(id)
  if not uiReady() then return end
  local craftId = tonumber(id)
  if not craftId then return end

  local list = Crafts[selectedCategory] or {}
  local craft = list[craftId]
  if not craft then return end

  selectedCraftId = craftId

  local descriptionWidget = craftPanel:recursiveGetChildById("description")
  if descriptionWidget then
    descriptionWidget:setText("\nProcesso De Craft:\n" .. (craft.name or "") .. "\n")
  end

  for i = 1, 6 do
    local materialWidget = craftPanel:getChildById("material" .. i)
    if materialWidget then materialWidget:setItem(nil) end
    local cnt = craftPanel:getChildById("count" .. i)
    if cnt then cnt:setText("") end
  end

  if type(craft.materials) == "table" then
    for i = 1, #craft.materials do
      local material = craft.materials[i]
      if type(material) == "table" then
        local materialWidget = craftPanel:getChildById("material" .. i)
        if materialWidget then
          materialWidget:setItemId(material.id or 0)
          materialWidget:setItemCount(material.count or 0)
          materialWidget:setTooltip(material.tooltip or "")
        end
        local countWidget = craftPanel:getChildById("count" .. i)
        if countWidget then
          local playerCount = material.player or 0
          local need        = material.count or 0
          countWidget:setText(playerCount .. "\n" .. need)
          countWidget:setColor(playerCount >= need and "#FFFFFF" or "#FF0000")
        end
      end
    end
  end

  local outcome = craftPanel:getChildById("craftOutcome")
  if outcome then
    if craft.item and craft.item.id then outcome:setItemId(craft.item.id) end
    if craft.count then outcome:setItemCount(craft.count) end
    if craft.description then
      outcome:setTooltip(craft.description)
      outcome:setTooltipTable((craft.name or "") .. "\n" .. (craft.description or ""), nil)
    else
      outcome:setTooltip("")
    end
  end

  local totalCost = craftPanel:recursiveGetChildById("totalCost")
  if totalCost and craft.cost then
    totalCost:setText(comma_value(tostring(craft.cost)))
  end
end

function craftItem()
  if selectedCategory and selectedCraftId then
    local protocolGame = g_game.getProtocolGame()
    if protocolGame then
      protocolGame:sendExtendedOpcode(CODE, json.encode({ action = "craft", data = { category = selectedCategory, craftId = selectedCraftId } }))
    end
  end
end

function toggle()
  if not window then return end
  if windowBtn:isOn() then hide() else show() end
end

function show()
  if not window then return end
  windowBtn:setOn(true)
  window:show()
  window:raise()
  window:focus()
end

function hide()
  if not window then return end
  windowBtn:setOn(false)
  window:hide()
  -- modules.game_interface.focusfaz()
end

function comma_value(amount)
  local formatted = amount
  while true do
    formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1.%2")
    if (k == 0) then break end
  end
  return formatted
end
