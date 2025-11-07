-- Sistema de limpeza automática de memória
-- Monitora e limpa recursos não utilizados periodicamente

local MemoryManager = {}
MemoryManager.__index = MemoryManager

local memoryManager = {}
memoryManager.lastCleanup = 0
memoryManager.cleanupInterval = 60000 -- 1 minuto
memoryManager.maxMemoryUsage = 80 -- 80% de uso de memória

function MemoryManager.new()
  local self = setmetatable({}, MemoryManager)
  self.cleanupCallbacks = {}
  self.isRunning = false
  return self
end

-- Adicionar callback de limpeza
function MemoryManager:addCleanupCallback(callback, priority)
  priority = priority or 5
  table.insert(self.cleanupCallbacks, {callback = callback, priority = priority})
  table.sort(self.cleanupCallbacks, function(a, b) return a.priority < b.priority end)
end

-- Executar limpeza de memória
function MemoryManager:performCleanup()
  local memInfo = g_app.getMemoryInfo and g_app:getMemoryInfo()
  if not memInfo then
    return false
  end
  
  local memoryUsage = (memInfo.used / memInfo.total) * 100
  
  -- Só limpar se uso de memória estiver alto
  if memoryUsage > self.maxMemoryUsage then
    print("Memory cleanup triggered - Usage: " .. string.format("%.1f", memoryUsage) .. "%")
    
    -- Executar callbacks de limpeza
    for _, callbackData in ipairs(self.cleanupCallbacks) do
      local success, result = pcall(callbackData.callback)
      if not success then
        print("Memory cleanup callback error: " .. tostring(result))
      end
    end
    
    -- Forçar garbage collection
    collectgarbage("collect")
    
    return true
  end
  
  return false
end

-- Iniciar monitoramento automático
function MemoryManager:startMonitoring()
  if self.isRunning then
    return
  end
  
  self.isRunning = true
  self:scheduleNextCleanup()
end

-- Parar monitoramento
function MemoryManager:stopMonitoring()
  self.isRunning = false
  if self.cleanupEvent then
    removeEvent(self.cleanupEvent)
    self.cleanupEvent = nil
  end
end

-- Agendar próxima limpeza
function MemoryManager:scheduleNextCleanup()
  if not self.isRunning then
    return
  end
  
  self.cleanupEvent = scheduleEvent(function()
    self:performCleanup()
    self:scheduleNextCleanup()
  end, self.cleanupInterval)
end

-- Singleton global
local globalMemoryManager = MemoryManager.new()

-- Callbacks de limpeza específicos
function globalMemoryManager:addDefaultCleanupCallbacks()
  -- Limpar widgets órfãos
  self:addCleanupCallback(function()
    local rootWidget = g_ui.getRootWidget()
    if rootWidget then
      local orphanedWidgets = 0
      for _, child in ipairs(rootWidget:getChildren()) do
        if child.orphaned and child:isOrphaned() then
          child:destroy()
          orphanedWidgets = orphanedWidgets + 1
        end
      end
      if orphanedWidgets > 0 then
        print("Cleaned " .. orphanedWidgets .. " orphaned widgets")
      end
    end
  end, 1)
  
  -- Limpar cache de imagens
  self:addCleanupCallback(function()
    if g_textures and g_textures.cleanupCache then
      g_textures:cleanupCache()
    end
  end, 2)
  
  -- Limpar eventos órfãos
  self:addCleanupCallback(function()
    -- Esta é uma limpeza mais agressiva
    collectgarbage("collect")
  end, 3)
  
  -- Limpar tabelas globais grandes
  self:addCleanupCallback(function()
    if G and G.botContext and G.botContext._scheduler then
      local scheduler = G.botContext._scheduler
      local now = g_clock.millis()
      local cleaned = 0
      
      for i = #scheduler, 1, -1 do
        if scheduler[i].execution < now - 30000 then -- Mais de 30s atrás
          table.remove(scheduler, i)
          cleaned = cleaned + 1
        end
      end
      
      if cleaned > 0 then
        print("Cleaned " .. cleaned .. " old scheduled events")
      end
    end
  end, 4)
end

-- Funções globais para facilitar uso
function startMemoryMonitoring()
  globalMemoryManager:addDefaultCleanupCallbacks()
  globalMemoryManager:startMonitoring()
end

function stopMemoryMonitoring()
  globalMemoryManager:stopMonitoring()
end

function forceMemoryCleanup()
  return globalMemoryManager:performCleanup()
end

function addMemoryCleanupCallback(callback, priority)
  globalMemoryManager:addCleanupCallback(callback, priority)
end

-- Iniciar automaticamente
addEvent(function()
  startMemoryMonitoring()
end, 5000) -- Iniciar após 5 segundos

return MemoryManager
