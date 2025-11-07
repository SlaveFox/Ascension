-- chunkname: @/modules/game_goal/goal.lua

local goalWindow
local gameGoalOpcode = 46
local tooltipWidget, dateUpdateEvent

function init()
  connect(g_game, {
    onGameStart = hide,
    onGameEnd = hide
  })

  goalWindow = g_ui.displayUI("goal")

  ProtocolGame.registerExtendedOpcode(gameGoalOpcode, onReceiveGoal)
  goalWindow:hide()
end

function terminate()
  disconnect(g_game, {
    onGameStart = hide,
    onGameEnd = hide
  })
  ProtocolGame.unregisterExtendedOpcode(gameGoalOpcode)
  hide()
end

function toggle()
  if goalWindow:isVisible() then
    hide()
  else
    sendOpcode({ type = "openGoal" })
  end
end

function hide()
  goalWindow:hide()
  closeTooltip()
  removeDateEvent()
  if modules.game_interface.focus then
    modules.game_interface.focus()
  end
end

function sendOpcode(params)
  g_game.getProtocolGame():sendExtendedOpcode(gameGoalOpcode, json.encode(params))
end

local function tooltipMouse(first, tooltipWidget)
  if not first and (not tooltipWidget:isVisible() or tooltipWidget:getOpacity() < 0.1) then
    return
  end

  local pos = g_window.getMousePosition()
  local windowSize = g_window.getSize()
  local labelSize = tooltipWidget:getSize()

  pos.x = pos.x + 1
  pos.y = pos.y + 1

  if windowSize.width - (pos.x + labelSize.width) < 10 then
    pos.x = pos.x - labelSize.width - 3
  else
    pos.x = pos.x + 10
  end

  if windowSize.height - (pos.y + labelSize.height) < 10 then
    pos.y = pos.y - labelSize.height - 3
  else
    pos.y = pos.y + 10
  end

  tooltipWidget:setPosition(pos)
end

function onReceiveGoal(protocol, opcode, payload)
  local ok, jsonData = pcall(function() return json.decode(payload) end)
  if not ok or not jsonData then return end

  if jsonData.type == "update" then
    goalWindow:show()
    goalWindow:focus()

    local goalMeta             = jsonData.goalData.meta
    local playerMeta           = jsonData.goalData.playerMeta
    local currentAmount        = jsonData.goalData.currentValue
    local playerSpentValue     = jsonData.goalData.playerSpentValue
    local isGlobalRewardCollected = tonumber(jsonData.goalData.globalRewardIsCollected)
    local globalProgressBar    = goalWindow.globalProgressContainer.progress
    local playerProgressBar    = goalWindow.playerProgressContainer.progress
    local globalRewardChest    = goalWindow.globalRewardContainer.chest
    local playerContainerList  = goalWindow.playerRewardList

    globalProgressBar.bar:setTooltip(jsonData.goalData.globalDescription)
    playerProgressBar.bar:setTooltip("Acumule Pontos gastos no nosso shop para resgatar suas recompensas pessoais.")
    goalWindow:setText(jsonData.goalData.title)
    updateGoalEndDate(jsonData.goalData.endDate)
    updateProgressBar(goalMeta,   currentAmount,    globalProgressBar, "images/progressbar", true)
    updateProgressBar(playerMeta, playerSpentValue, playerProgressBar, "images/playerbar")
    goalWindow.globalRewardContainer.labelComplete:setVisible(isGlobalRewardCollected > 0)

    function globalRewardChest:onHoverChange(isHovered)
      showGlobalRewardTooltip(isHovered, jsonData.goalData.globalDescription, jsonData.goalData.globalRewardData, currentAmount, goalMeta, isGlobalRewardCollected > 0)
    end

    playerContainerList:destroyChildren()

    for _, playerData in ipairs(jsonData.goalData.playerRewardData) do
      local rewardWidget = g_ui.createWidget("PlayerRewardGoal", playerContainerList)

      rewardWidget.circle.labelComplete:setVisible(playerData.rewardIsCollected)

      function rewardWidget.circle.chest:onHoverChange(isHovered)
        showPlayerRewardTooltip(isHovered, playerData, playerSpentValue, playerData.goalAmount, playerData.rewardIsCollected)
      end

      function rewardWidget.buttonRewardGoal.onClick()
        modules.game_goal.sendOpcode({
          type  = "collectPlayerReward",
          index = playerData.indexGoal
        })
      end
    end
  end
end

local function formatCurrency(value)
  local formatted = string.format("%.2f", math.ceil(value)):gsub("%.", ",")
  repeat
    formatted, changes = formatted:gsub("^(-?%d+)(%d%d%d)", "%1.%2")
  until changes == 0
  return formatted
end

function updateProgressBar(targetAmount, currentAmount, progressBar, progressBarImage, isGlobal)
  if currentAmount < 0 then currentAmount = 0 end
  currentAmount = math.min(currentAmount, targetAmount)

  local formattedTarget  = formatCurrency(targetAmount)
  local formattedCurrent = formatCurrency(currentAmount)

  progressBar.bar:setText(formattedCurrent .. " / " .. formattedTarget)
  progressBar.bar:setImageSource(progressBarImage)

  local progressPercent = math.floor(currentAmount / targetAmount * 100)
  local barHeight = 19
  local barTotalWidth = progressBar:getWidth()

  if isGlobal then
    progressBar.bar:setText(progressPercent .. "% / 100%")
  end

  local progressBarWidth = math.max(1, math.floor(barTotalWidth * (progressPercent / 100)))
  local clipRect = { x = 0, y = 0, width = progressBarWidth, height = barHeight }

  progressBar.bar:setImageClip(clipRect)
  progressBar.bar:setImageRect(clipRect)
end

function closeTooltip()
  if tooltipWidget then
    tooltipWidget:destroy()
    tooltipWidget = nil
  end
end

function showGlobalRewardTooltip(isHovered, description, rewardData, currentAmount, goalMeta, isCollected)
  if isHovered then
    tooltipWidget = g_ui.createWidget("GoalGlobalRewardTooltip", rootWidget)

    tooltipMouse(true, tooltipWidget)
    tooltipWidget.description:setText(description)
    updateProgressBar(goalMeta, currentAmount, tooltipWidget.progress, "images/miniprogressGlobal", true)

    if rewardData.items then
      for _, item in ipairs(rewardData.items) do
        local itemWidget = g_ui.createWidget("ItemGoalTooltip", tooltipWidget.itemList)
        itemWidget:setItemId(item.itemId)
        itemWidget.itemCount:setText(item.itemCount)
        itemWidget.labelComplete:setVisible(isCollected)
      end
    end

    if rewardData.outfits then
      for _, outfit in ipairs(rewardData.outfits) do
        local outfitWidget = g_ui.createWidget("CreatureGoal", tooltipWidget.itemList)
        outfitWidget:setOutfit({ type = outfit.outfitId })
        outfitWidget.labelComplete:setVisible(isCollected)
      end
    end

    local itemCount = tooltipWidget.itemList:getChildCount()
    tooltipWidget.itemList:resize(itemCount * 40, 35)
  else
    closeTooltip()
  end
end

function showPlayerRewardTooltip(isHovered, rewardData, currentAmount, goalMeta, isCollected)
  if isHovered then
    tooltipWidget = g_ui.createWidget("GoalGlobalRewardTooltip", rootWidget)

    tooltipWidget:setHeight(180)
    tooltipMouse(true, tooltipWidget)
    tooltipWidget:setText(rewardData.rewardName)
    tooltipWidget.description:setText("Esta recompensa será reivindicada após você atingir o valor total em Pontos gastos no shop.")
    tooltipWidget.description:setHeight(60)
    updateProgressBar(goalMeta, currentAmount, tooltipWidget.progress, "images/miniprogressPlayer")

    if rewardData.items then
      for _, item in ipairs(rewardData.items) do
        local itemWidget = g_ui.createWidget("ItemGoalTooltip", tooltipWidget.itemList)
        itemWidget:setItemId(item.itemId)
        itemWidget.itemCount:setText(item.itemCount)
        itemWidget.labelComplete:setVisible(isCollected)
      end
    end

    if rewardData.outfits then
      for _, outfit in ipairs(rewardData.outfits) do
        local outfitWidget = g_ui.createWidget("CreatureGoal", tooltipWidget.itemList)
        outfitWidget:setOutfit({ type = outfit.outfitId })
        outfitWidget.labelComplete:setVisible(isCollected)
      end
    end

    local itemCount = tooltipWidget.itemList:getChildCount()
    tooltipWidget.itemList:resize(itemCount * 40, 35)
  else
    closeTooltip()
  end
end

function getTimeRemaining(endDate)
  local currentTime = os.time()
  local year, month, day = endDate:match("(%d+)-(%d+)-(%d+)")
  year, month, day = tonumber(year), tonumber(month), tonumber(day)
  if not year or not month or not day then
    return "Data inválida. Use o formato AAAA-MM-DD."
  end

  local endTimestamp = os.time({ hour = 23, min = 59, sec = 59, year = year, month = month, day = day })
  local remainingTime = endTimestamp - currentTime
  if remainingTime <= 0 then return "O goal já foi finalizado." end

  local days = math.floor(remainingTime / 86400)
  remainingTime = remainingTime % 86400
  local hours = math.floor(remainingTime / 3600)
  remainingTime = remainingTime % 3600
  local minutes = math.floor(remainingTime / 60)
  local seconds = remainingTime % 60

  return string.format("Ends in: %d:%02d:%02d:%02d", days, hours, minutes, seconds)
end

function getColorForGoalDeadline(endDate)
  local currentTime = os.time()
  local year, month, day = endDate:match("(%d+)-(%d+)-(%d+)")
  year, month, day = tonumber(year), tonumber(month), tonumber(day)
  if not year or not month or not day then return "#FFFFFF" end

  local endTimestamp = os.time({ hour = 23, min = 59, sec = 59, year = year, month = month, day = day })
  local diff = endTimestamp - currentTime

  if diff > 604800 then
    return "#00FF00"
  elseif diff > 259200 then
    return "#FFFF00"
  elseif diff > 0 then
    return "#FF0000"
  else
    return "#808080"
  end
end

function removeDateEvent()
  if dateUpdateEvent then
    removeEvent(dateUpdateEvent)
    dateUpdateEvent = nil
  end
end

function updateGoalEndDate(endDate)
  removeDateEvent()
  goalWindow.labelDate:setText(getTimeRemaining(endDate))
  goalWindow.labelDate:setColor(getColorForGoalDeadline(endDate))

  dateUpdateEvent = cycleEvent(function()
    goalWindow.labelDate:setText(getTimeRemaining(endDate))
    goalWindow.labelDate:setColor(getColorForGoalDeadline(endDate))
  end, 1000)
end
