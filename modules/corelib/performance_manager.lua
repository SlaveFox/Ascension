-- =========================================================
-- Performance Manager - Sistema unificado de otimização
-- =========================================================

local PerformanceManager = {}
PerformanceManager.__index = PerformanceManager

-- Cache de eventos com throttling
local eventCache = {}
local throttledEvents = {}
local THROTTLE_DELAY = 16 -- ~60 FPS

-- Cache de recursos com LRU
local resourceCache = {}
local MAX_CACHE_SIZE = 100
local cacheAccessOrder = {}

-- Métricas de performance
local performanceMetrics = {}
local slowOperationThreshold = 100 -- ms

-- =========================================================
-- Sistema de Eventos Otimizado
-- =========================================================

function PerformanceManager.throttleEvent(eventId, callback, delay)
  delay = delay or THROTTLE_DELAY
  
  if throttledEvents[eventId] then
    removeEvent(throttledEvents[eventId])
  end
  
  throttledEvents[eventId] = scheduleEvent(function()
    callback()
    throttledEvents[eventId] = nil
  end, delay)
end

function PerformanceManager.debounceEvent(eventId, callback, delay)
  delay = delay or 300
  
  if throttledEvents[eventId] then
    removeEvent(throttledEvents[eventId])
  end
  
  throttledEvents[eventId] = scheduleEvent(function()
    callback()
    throttledEvents[eventId] = nil
  end, delay)
end

function PerformanceManager.cancelEvent(eventId)
  if throttledEvents[eventId] then
    removeEvent(throttledEvents[eventId])
    throttledEvents[eventId] = nil
  end
end

-- =========================================================
-- Cache de Recursos LRU
-- =========================================================

function PerformanceManager.getCachedResource(key)
  local item = resourceCache[key]
  if item then
    -- Mover para o final da lista de acesso
    for i, k in ipairs(cacheAccessOrder) do
      if k == key then
        table.remove(cacheAccessOrder, i)
        break
      end
    end
    table.insert(cacheAccessOrder, key)
    item.lastAccess = g_clock.millis()
    return item.data
  end
  return nil
end

function PerformanceManager.setCachedResource(key, data)
  -- Verificar se precisa remover itens antigos
  if #cacheAccessOrder >= MAX_CACHE_SIZE then
    PerformanceManager.evictOldestResource()
  end
  
  resourceCache[key] = {
    data = data,
    lastAccess = g_clock.millis()
  }
  
  -- Adicionar à lista de acesso
  table.insert(cacheAccessOrder, key)
end

function PerformanceManager.evictOldestResource()
  if #cacheAccessOrder > 0 then
    local oldestKey = table.remove(cacheAccessOrder, 1)
    resourceCache[oldestKey] = nil
  end
end

function PerformanceManager.clearResourceCache()
  resourceCache = {}
  cacheAccessOrder = {}
end

-- =========================================================
-- Monitoramento de Performance
-- =========================================================

function PerformanceManager.startTimer(operationName)
  performanceMetrics[operationName] = g_clock.millis()
end

function PerformanceManager.endTimer(operationName)
  local startTime = performanceMetrics[operationName]
  if startTime then
    local duration = g_clock.millis() - startTime
    performanceMetrics[operationName] = nil
    
    if duration > slowOperationThreshold then
      print("Slow operation: " .. operationName .. " took " .. duration .. "ms")
    end
    
    return duration
  end
  return 0
end

function PerformanceManager.getMetrics()
  return performanceMetrics
end

-- =========================================================
-- Otimização de Memória
-- =========================================================

function PerformanceManager.performMemoryCleanup()
  local memInfo = g_app.getMemoryInfo and g_app:getMemoryInfo()
  if not memInfo then
    return false
  end
  
  local memoryUsage = (memInfo.used / memInfo.total) * 100
  
  if memoryUsage > 80 then
    print("Memory cleanup triggered - Usage: " .. string.format("%.1f", memoryUsage) .. "%")
    
    -- Limpar widgets órfãos
    PerformanceManager.cleanupOrphanedWidgets()
    
    -- Limpar cache de recursos
    PerformanceManager.clearResourceCache()
    
    -- Limpar eventos órfãos
    PerformanceManager.cleanupOrphanedEvents()
    
    -- Forçar garbage collection
    collectgarbage("collect")
    
    return true
  end
  
  return false
end

function PerformanceManager.cleanupOrphanedWidgets()
  local rootWidget = g_ui.getRootWidget()
  if not rootWidget then return end
  
  local orphanedCount = 0
  for _, child in ipairs(rootWidget:getChildren()) do
    if child.orphaned and child:isOrphaned() then
      child:destroy()
      orphanedCount = orphanedCount + 1
    end
  end
  
  if orphanedCount > 0 then
    print("Cleaned " .. orphanedCount .. " orphaned widgets")
  end
end

function PerformanceManager.cleanupOrphanedEvents()
  local cleanedCount = 0
  for eventId, event in pairs(throttledEvents) do
    if not event or event:isExpired() then
      throttledEvents[eventId] = nil
      cleanedCount = cleanedCount + 1
    end
  end
  
  if cleanedCount > 0 then
    print("Cleaned " .. cleanedCount .. " orphaned events")
  end
end

-- =========================================================
-- Sistema de Lazy Loading
-- =========================================================

local lazyLoadedInterfaces = {}

function PerformanceManager.loadInterfaceLazy(interfaceName)
  if not lazyLoadedInterfaces[interfaceName] then
    PerformanceManager.startTimer("loadInterface_" .. interfaceName)
    lazyLoadedInterfaces[interfaceName] = g_ui.displayUI(interfaceName)
    PerformanceManager.endTimer("loadInterface_" .. interfaceName)
  end
  return lazyLoadedInterfaces[interfaceName]
end

function PerformanceManager.unloadInterface(interfaceName)
  if lazyLoadedInterfaces[interfaceName] then
    lazyLoadedInterfaces[interfaceName]:destroy()
    lazyLoadedInterfaces[interfaceName] = nil
  end
end

-- =========================================================
-- Otimização de Animações
-- =========================================================

local animationThrottle = {}
local ANIMATION_THROTTLE_MS = 16 -- ~60 FPS

function PerformanceManager.throttledAnimation(widget, updateFunc)
  local lastUpdate = animationThrottle[widget] or 0
  local now = g_clock.millis()
  
  if now - lastUpdate >= ANIMATION_THROTTLE_MS then
    updateFunc()
    animationThrottle[widget] = now
  end
end

function PerformanceManager.cleanupAnimationThrottle()
  animationThrottle = {}
end

-- =========================================================
-- Inicialização e Monitoramento Automático
-- =========================================================

local cleanupEvent = nil

function PerformanceManager.startMonitoring()
  if cleanupEvent then return end
  
  cleanupEvent = scheduleEvent(function()
    PerformanceManager.performMemoryCleanup()
    PerformanceManager.cleanupAnimationThrottle()
    PerformanceManager.startMonitoring()
  end, 60000) -- 1 minuto
end

function PerformanceManager.stopMonitoring()
  if cleanupEvent then
    removeEvent(cleanupEvent)
    cleanupEvent = nil
  end
end

-- =========================================================
-- API Global
-- =========================================================

-- Tornar funções disponíveis globalmente
G.PerformanceManager = PerformanceManager

-- Funções de conveniência
function throttleEvent(eventId, callback, delay)
  return PerformanceManager.throttleEvent(eventId, callback, delay)
end

function debounceEvent(eventId, callback, delay)
  return PerformanceManager.debounceEvent(eventId, callback, delay)
end

function getCachedResource(key)
  return PerformanceManager.getCachedResource(key)
end

function setCachedResource(key, data)
  return PerformanceManager.setCachedResource(key, data)
end

function startTimer(operationName)
  return PerformanceManager.startTimer(operationName)
end

function endTimer(operationName)
  return PerformanceManager.endTimer(operationName)
end

function loadInterfaceLazy(interfaceName)
  return PerformanceManager.loadInterfaceLazy(interfaceName)
end

function throttledAnimation(widget, updateFunc)
  return PerformanceManager.throttledAnimation(widget, updateFunc)
end

-- Inicializar monitoramento automático
addEvent(function()
  PerformanceManager.startMonitoring()
end)

return PerformanceManager

