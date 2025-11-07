-- Widget Pool para otimização de performance
-- Reutiliza widgets em vez de criar/destruir constantemente

local WidgetPool = {}
WidgetPool.__index = WidgetPool

-- Pool global para widgets comuns
local globalPool = {}

function WidgetPool.new()
  local self = setmetatable({}, WidgetPool)
  self.pools = {}
  self.maxPoolSize = 10 -- Máximo de widgets por tipo
  return self
end

-- Obter widget do pool ou criar novo
function WidgetPool:getWidget(widgetType, parent)
  local pool = self.pools[widgetType]
  if not pool then
    pool = {}
    self.pools[widgetType] = pool
  end
  
  local widget = table.remove(pool)
  if widget then
    -- Reutilizar widget existente
    if parent then
      widget:setParent(parent)
    end
    widget:show()
    return widget
  else
    -- Criar novo widget
    return g_ui.createWidget(widgetType, parent)
  end
end

-- Retornar widget para o pool
function WidgetPool:returnWidget(widget)
  if not widget or widget:isDestroyed() then
    return
  end
  
  local widgetType = widget:getStyleName()
  local pool = self.pools[widgetType]
  if not pool then
    pool = {}
    self.pools[widgetType] = pool
  end
  
  -- Limitar tamanho do pool
  if #pool < self.maxPoolSize then
    widget:hide()
    widget:setParent(nil)
    table.insert(pool, widget)
  else
    widget:destroy()
  end
end

-- Limpar pool específico
function WidgetPool:clearPool(widgetType)
  local pool = self.pools[widgetType]
  if pool then
    for _, widget in ipairs(pool) do
      widget:destroy()
    end
    self.pools[widgetType] = {}
  end
end

-- Limpar todos os pools
function WidgetPool:clearAll()
  for widgetType, pool in pairs(self.pools) do
    for _, widget in ipairs(pool) do
      widget:destroy()
    end
  end
  self.pools = {}
end

-- Pool global singleton
local globalWidgetPool = WidgetPool.new()

-- Funções globais para facilitar uso
function getWidgetFromPool(widgetType, parent)
  return globalWidgetPool:getWidget(widgetType, parent)
end

function returnWidgetToPool(widget)
  globalWidgetPool:returnWidget(widget)
end

function clearWidgetPool(widgetType)
  if widgetType then
    globalWidgetPool:clearPool(widgetType)
  else
    globalWidgetPool:clearAll()
  end
end

-- Auto-limpeza periódica para evitar acúmulo
local cleanupEvent
local function scheduleCleanup()
  if cleanupEvent then
    removeEvent(cleanupEvent)
  end
  
  cleanupEvent = scheduleEvent(function()
    -- Limpar pools que não foram usados recentemente
    for widgetType, pool in pairs(globalWidgetPool.pools) do
      if #pool > 5 then
        -- Manter apenas 5 widgets por tipo
        for i = 6, #pool do
          pool[i]:destroy()
          pool[i] = nil
        end
      end
    end
    
    scheduleCleanup()
  end, 30000) -- Limpeza a cada 30 segundos
end

-- Iniciar limpeza automática
scheduleCleanup()

return WidgetPool
