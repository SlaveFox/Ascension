g_tooltip = {}
local toolTipLabel, currentHoveredWidget, itemTooltipWidget = nil

local minimunWidth = 230

local width = 0
local height = 0
local longestString = 0

local function moveToolTip(first)
	if not first and (not toolTipLabel:isVisible() or toolTipLabel:getOpacity() < 0.1) then
		return
	end

	local pos = g_window.getMousePosition()
	local windowSize = g_window.getSize()
	local labelSize = toolTipLabel:getSize()
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

	toolTipLabel:setPosition(pos)
end

local function onWidgetHoverChange(widget, hovered)
	if hovered then
	  if widget:getClassName() == "UIItem" then
		if widget:getItemId() > 0 then
		local itemId = widget.itemId or 0
		local itemNameText = widget.itemName
		local notName = widget.NotName or false
		local itemWidget = widget:getItem()
		  g_tooltip.display(widget.tooltip, itemId, itemNameText, notName)
		  currentHoveredWidget = widget
		end
		return
	  end
	  if widget.tooltip and not g_mouse.isPressed() then
		g_tooltip.display(widget.tooltip, nil, nil, nil, nil, nil)
		currentHoveredWidget = widget
	  end
	else
	  if widget == currentHoveredWidget then
		g_tooltip.hide()
		if destroyItemToolTip then
		  destroyItemToolTip()
		end
		currentHoveredWidget = nil
		if itemNameLabel then
		  itemNameLabel:destroy()
		  itemNameLabel = nil
		end
	  end
	end
end
  
local function onWidgetStyleApply(widget, styleName, styleNode)
	if styleNode.tooltip then
		widget.tooltip = styleNode.tooltip
	end
end

function g_tooltip.init()
	connect(UIWidget, {
		onStyleApply = onWidgetStyleApply,
		onHoverChange = onWidgetHoverChange
	})

	addEvent(function ()
		toolTipLabel = g_ui.createWidget("UILabel", rootWidget)

		g_ui.importStyle("ui_styles/itemTooltip")
		toolTipLabel:setId("toolTip")
		toolTipLabel:setImageSource('ui_styles/tooltip')
		toolTipLabel:setImageBorder(5)
		toolTipLabel:setTextAlign(AlignCenter)
		toolTipLabel:hide()
	end)
end

function g_tooltip.terminate()
	disconnect(UIWidget, {
		onStyleApply = onWidgetStyleApply,
		onHoverChange = onWidgetHoverChange
	})

	currentHoveredWidget = nil
	toolTipLabel:destroy()
	toolTipLabel = nil
	g_tooltip = nil
end

function destroyTooltip()
	if itemTooltipWidget then
		itemTooltipWidget:destroy()
		itemTooltipWidget = nil
	end
end

function addEmpty(newHeight)
  local empty = g_ui.createWidget("TooltipEmpty", itemTooltipWidget.labels)
  empty:setHeight(newHeight)
  height = height + newHeight
end

function addSeparator()
	local sep = g_ui.createWidget("TooltipSeparator", itemTooltipWidget.labels)
	height = height + sep:getHeight() + sep:getMarginTop() + sep:getMarginBottom()
end

local function applyEpicShader(itemWidget, text)
  local it = itemWidget
  if not it then
    return
  end
  local firstLine = text:match("([^\r\n]+)") or ""
  local baseName = firstLine:match("^(.-)%s*%(") or firstLine
  local suffix = baseName:match("(%+%d+)$")
  if suffix then
    local n = tonumber(suffix:sub(2))
    if n and n >= 1 and n <= 12 then
      it:setItemShader(suffix)
      return
    end
  end
  it:setItemShader(nil)
end

function g_tooltip.display(text, itemId, itemNameText, NotName)
  if text == nil or text:len() == 0 then return end
  if not toolTipLabel then return end
  if itemTooltipWidget then
      itemTooltipWidget:destroy()
      itemTooltipWidget = nil
  end

  -- Detectar +n no nome e definir cor
local firstLine = text:match("([^\r\n]+)")
local upgradeLevel = tonumber(firstLine and firstLine:match("%+(%d+)$")) or 0
local color = "#FFFFFF"

  if upgradeLevel >= 12 then
    color = "#FFD700" -- dourado
  elseif upgradeLevel >= 9 then
    color = "#FF8C00" -- laranja
  elseif upgradeLevel >= 6 then
    color = "#DA70D6" -- roxo
  elseif upgradeLevel >= 4 then
    color = "#00BFFF" -- azul
  elseif upgradeLevel >= 2 then
    color = "#00FF00" -- verde
  end

  -- Aplicar texto e cor no tooltip principal
  toolTipLabel:setText(text)
  toolTipLabel:setColor(color)
  toolTipLabel:show()
  toolTipLabel:raise()
  toolTipLabel:enable()
  toolTipLabel:setFont("baby-14")

  itemTooltipWidget = g_ui.createWidget("ItemTooltipPanel", toolTipLabel)
  if itemId then
    local w = itemTooltipWidget.itemWidget
    w:setItemId(itemId)
    applyEpicShader(w, text)
  end

  if NotName then
    addSeparator()
  end

  toolTipLabel:setImageSource('ui_styles/tooltip')
  g_effects.fadeIn(toolTipLabel, 100)

  addEvent(function()
    toolTipLabel:resizeToText()
    toolTipLabel:resize(toolTipLabel:getWidth() + 25, toolTipLabel:getHeight() + 25)
    moveToolTip(true)
  end, 50)

  connect(rootWidget, { onMouseMove = moveToolTip })
end


function g_tooltip.hide()
	g_effects.fadeOut(toolTipLabel, 100)
	disconnect(rootWidget, {
		onMouseMove = moveToolTip
	})
end

function UIWidget:setTooltipTable(text, itemId, itemName, NotName)
  self.itemId = itemId
  self.tooltip = text
  self.itemName = itemName
  self.NotName = NotName
end

function UIWidget:setTooltip(text)
	self.tooltip = text
end

function UIWidget:removeTooltip()
	self.tooltip = nil
end

function UIWidget:getTooltip()
	return self.tooltip
end

g_tooltip.init()
connect(g_app, {
	onTerminate = g_tooltip.terminate
})
