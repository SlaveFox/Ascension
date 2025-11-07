local context = G.botContext
if type(context.UI) ~= "table" then
  context.UI = {}
end
local UI = context.UI

-- Importar widget pool se disponível
local widgetPool = nil
if modules.corelib and modules.corelib.widgetpool then
  widgetPool = require('modules.corelib.ui.widgetpool')
end

UI.createWidget = function(name, parent)
  if parent == nil then      
    parent = context.panel
  end
  
  -- Usar pool se disponível
  if widgetPool then
    return getWidgetFromPool(name, parent)
  else
    local widget = g_ui.createWidget(name, parent)
    widget.botWidget = true
    return widget
  end
end

UI.createMiniWindow = function(name, parent)
  if parent == nil then      
    parent = modules.game_interface.getRightPanel()
  end
  
  local widget
  if widgetPool then
    widget = getWidgetFromPool(name, parent)
  else
    widget = g_ui.createWidget(name, parent)
  end
  
  widget:setup()
  widget.botWidget = true
  return widget
end

UI.createWindow = function(name)
  local widget
  if widgetPool then
    widget = getWidgetFromPool(name, g_ui.getRootWidget())
  else
    widget = g_ui.createWidget(name, g_ui.getRootWidget())
  end
  
  widget.botWidget = true  
  widget:show()
  widget:raise()
  widget:focus()
  return widget
end

-- Função para retornar widget ao pool
UI.destroyWidget = function(widget)
  if widgetPool and widget.botWidget then
    returnWidgetToPool(widget)
  else
    widget:destroy()
  end
end