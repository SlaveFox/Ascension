tradeWindow = nil

function init()
  g_ui.importStyle('tradewindow')

  connect(g_game, { onOwnTrade = onGameOwnTrade,
                    onCounterTrade = onGameCounterTrade,
                    onCloseTrade = onGameCloseTrade,
                    onGameEnd = onGameCloseTrade })
end

function terminate()
  disconnect(g_game, { onOwnTrade = onGameOwnTrade,
                       onCounterTrade = onGameCounterTrade,
                       onCloseTrade = onGameCloseTrade,
                       onGameEnd = onGameCloseTrade })

  if tradeWindow then
    tradeWindow:destroy()
  end
end

function createTrade()
  tradeWindow = g_ui.createWidget('TradeWindow', modules.game_interface.getRightPanel())
  tradeWindow.onClose = function()
    g_game.rejectTrade()
    tradeWindow:hide()
  end
  tradeWindow:setup()
end

local function applyEpicShader(itemWidget)
  local it = itemWidget:getItem()
  if not it then
    return
  end
  local firstLine = it:getTooltip():match("([^\r\n]+)") or ""
  local baseName = firstLine:match("^(.-)%s*%(") or firstLine
  local suffix = baseName:match("(%+%d+)$")
  if suffix then
    local n = tonumber(suffix:sub(2))
    if n and n >= 1 and n <= 12 then
      it:setShader(suffix)
      return
    end
  end
  it:setShader(nil)
end

function fillTrade(name, items, counter)
  if not tradeWindow then
    createTrade()
  end

  local tradeItemWidget = tradeWindow:getChildById('tradeItem')
  tradeItemWidget:setItemId(items[1]:getId())

  local tradeContainer
  local label
  local countLabel
  if counter then
    tradeContainer = tradeWindow:recursiveGetChildById('counterTradeContainer')
    label = tradeWindow:recursiveGetChildById('counterTradeLabel')
    countLabel = tradeWindow:recursiveGetChildById('counterTradeCountLabel')
    tradeWindow:recursiveGetChildById('acceptButton'):enable()
  else
    tradeContainer = tradeWindow:recursiveGetChildById('ownTradeContainer')
    label = tradeWindow:recursiveGetChildById('ownTradeLabel')
    countLabel = tradeWindow:recursiveGetChildById('ownTradeCountLabel')
  end
  label:setText(name)
  countLabel:setText(tr("Items") .. ": " .. #items)
  

  for index,item in ipairs(items) do
    local itemWidget = g_ui.createWidget('Item', tradeContainer)
    itemWidget:setItem(item)
    itemWidget:setVirtual(true)
    itemWidget:setMargin(0)
    itemWidget:setMargin(0)
    applyEpicShader(itemWidget)
    itemWidget.onClick = function()
      g_game.inspectTrade(counter, index-1)
    end
  end
end

function onGameOwnTrade(name, items)
  fillTrade(name, items, false)
end

function onGameCounterTrade(name, items)
  fillTrade(name, items, true)
end

function onGameCloseTrade()
  if tradeWindow then
    tradeWindow:destroy()
    tradeWindow = nil
  end
end
