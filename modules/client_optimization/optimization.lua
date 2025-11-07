-- =========================================================
-- Client Optimization Module
-- Sistema global de otimização para o cliente
-- =========================================================

local ClientOptimization = {}
ClientOptimization.__index = ClientOptimization

-- Configurações de otimização
local optimizationConfig = {
  enableMemoryMonitoring = true,
  enableEventThrottling = true,
  enableResourceCache = true,
  enableLazyLoading = true,
  memoryCleanupInterval = 60000, -- 1 minuto
  maxMemoryUsage = 80, -- 80%
  throttleDelay = 16, -- ~60 FPS
}

-- Cache global de recursos
local globalResourceCache = {}
local globalWidgetCache = {}
local globalEventCache = {}

-- Métricas de performance
local performanceMetrics = {
  memoryCleanups = 0,
  throttledEvents = 0,
  cachedResources = 0,
  lazyLoadedInterfaces = 0
}

-- =========================================================
-- Sistema de Cache Global
-- =========================================================

function ClientOptimization.cacheResource(key, data)
  if not optimizationConfig.enableResourceCache then
    return data
  end
  
  globalResourceCache[key] = {
    data = data,
    timestamp = g_clock.millis(),
    accessCount = 0
  }
  
  performanceMetrics.cachedResources = performanceMetrics.cachedResources + 1
  return data
end

function ClientOptimization.getCachedResource(key)
  if not optimizationConfig.enableResourceCache then
    return nil
  end
  
  local cached = globalResourceCache[key]
  if cached then
    cached.accessCount = cached.accessCount + 1
    cached.lastAccess = g_clock.millis()
    return cached.data
  end
  return nil
end

function ClientOptimization.cacheWidget(widgetId, widget)
  globalWidgetCache[widgetId] = {
    widget = widget,
    timestamp = g_clock.millis(),
    accessCount = 0
  }
end

function ClientOptimization.getCachedWidget(widgetId)
  local cached = globalWidgetCache[widgetId]
  if cached and not cached.widget:isDestroyed() then
    cached.accessCount = cached.accessCount + 1
    cached.lastAccess = g_clock.millis()
    return cached.widget
  end
  return nil
end

-- =========================================================
-- Sistema de Throttling Global
-- =========================================================

function ClientOptimization.throttleEvent(eventId, callback, delay)
  if not optimizationConfig.enableEventThrottling then
    return scheduleEvent(callback, delay or optimizationConfig.throttleDelay)
  end
  
  delay = delay or optimizationConfig.throttleDelay
  
  if globalEventCache[eventId] then
    removeEvent(globalEventCache[eventId])
  end
  
  globalEventCache[eventId] = scheduleEvent(function()
    callback()
    globalEventCache[eventId] = nil
    performanceMetrics.throttledEvents = performanceMetrics.throttledEvents + 1
  end, delay)
  
  return globalEventCache[eventId]
end

function ClientOptimization.debounceEvent(eventId, callback, delay)
  delay = delay or 300
  
  if globalEventCache[eventId] then
    removeEvent(globalEventCache[eventId])
  end
  
  globalEventCache[eventId] = scheduleEvent(function()
    callback()
    globalEventCache[eventId] = nil
  end, delay)
  
  return globalEventCache[eventId]
end

-- =========================================================
-- Sistema de Lazy Loading Global
-- =========================================================

local lazyLoadedInterfaces = {}

function ClientOptimization.loadInterfaceLazy(interfaceName)
  if not optimizationConfig.enableLazyLoading then
    return g_ui.displayUI(interfaceName)
  end
  
  if not lazyLoadedInterfaces[interfaceName] then
    startTimer("lazy_load_" .. interfaceName)
    lazyLoadedInterfaces[interfaceName] = g_ui.displayUI(interfaceName)
    endTimer("lazy_load_" .. interfaceName)
    performanceMetrics.lazyLoadedInterfaces = performanceMetrics.lazyLoadedInterfaces + 1
  end
  
  return lazyLoadedInterfaces[interfaceName]
end

function ClientOptimization.unloadInterface(interfaceName)
  if lazyLoadedInterfaces[interfaceName] then
    lazyLoadedInterfaces[interfaceName]:destroy()
    lazyLoadedInterfaces[interfaceName] = nil
  end
end

-- =========================================================
-- Sistema de Limpeza de Memória
-- =========================================================

function ClientOptimization.performMemoryCleanup()
  if not optimizationConfig.enableMemoryMonitoring then
    return false
  end
  
  local memInfo = g_app.getMemoryInfo and g_app:getMemoryInfo()
  if not memInfo then
    return false
  end
  
  local memoryUsage = (memInfo.used / memInfo.total) * 100
  
  if memoryUsage > optimizationConfig.maxMemoryUsage then
    print("Client Optimization: Memory cleanup triggered - Usage: " .. string.format("%.1f", memoryUsage) .. "%")
    
    -- Limpar cache de recursos antigos
    ClientOptimization.cleanupResourceCache()
    
    -- Limpar cache de widgets órfãos
    ClientOptimization.cleanupWidgetCache()
    
    -- Limpar eventos órfãos
    ClientOptimization.cleanupEventCache()
    
    -- Forçar garbage collection
    collectgarbage("collect")
    
    performanceMetrics.memoryCleanups = performanceMetrics.memoryCleanups + 1
    return true
  end
  
  return false
end

function ClientOptimization.cleanupResourceCache()
  local now = g_clock.millis()
  local maxAge = 300000 -- 5 minutos
  
  for key, cached in pairs(globalResourceCache) do
    if now - cached.timestamp > maxAge then
      globalResourceCache[key] = nil
    end
  end
end

function ClientOptimization.cleanupWidgetCache()
  local now = g_clock.millis()
  local maxAge = 300000 -- 5 minutos
  
  for widgetId, cached in pairs(globalWidgetCache) do
    if cached.widget:isDestroyed() or (now - cached.timestamp > maxAge) then
      globalWidgetCache[widgetId] = nil
    end
  end
end

function ClientOptimization.cleanupEventCache()
  for eventId, event in pairs(globalEventCache) do
    if not event or event:isExpired() then
      globalEventCache[eventId] = nil
    end
  end
end

-- =========================================================
-- Monitoramento Automático
-- =========================================================

local cleanupEvent = nil

function ClientOptimization.startMonitoring()
  if cleanupEvent then return end
  
  cleanupEvent = scheduleEvent(function()
    ClientOptimization.performMemoryCleanup()
    ClientOptimization.startMonitoring()
  end, optimizationConfig.memoryCleanupInterval)
end

function ClientOptimization.stopMonitoring()
  if cleanupEvent then
    removeEvent(cleanupEvent)
    cleanupEvent = nil
  end
end

-- =========================================================
-- API Global
-- =========================================================

-- Tornar funções disponíveis globalmente
G.ClientOptimization = ClientOptimization

-- Funções de conveniência globais
function cacheResource(key, data)
  return ClientOptimization.cacheResource(key, data)
end

function getCachedResource(key)
  return ClientOptimization.getCachedResource(key)
end

function cacheWidget(widgetId, widget)
  return ClientOptimization.cacheWidget(widgetId, widget)
end

function getCachedWidget(widgetId)
  return ClientOptimization.getCachedWidget(widgetId)
end

function throttleEvent(eventId, callback, delay)
  return ClientOptimization.throttleEvent(eventId, callback, delay)
end

function debounceEvent(eventId, callback, delay)
  return ClientOptimization.debounceEvent(eventId, callback, delay)
end

function loadInterfaceLazy(interfaceName)
  return ClientOptimization.loadInterfaceLazy(interfaceName)
end

function unloadInterface(interfaceName)
  return ClientOptimization.unloadInterface(interfaceName)
end

-- =========================================================
-- Inicialização
-- =========================================================

function init()
  print("Client Optimization: Initializing performance optimizations...")
  
  -- Iniciar monitoramento automático
  ClientOptimization.startMonitoring()
  
  -- Configurar limpeza automática na saída
  connect(g_app, {
    onExit = function()
      ClientOptimization.stopMonitoring()
      print("Client Optimization: Performance metrics:")
      print("  Memory cleanups: " .. performanceMetrics.memoryCleanups)
      print("  Throttled events: " .. performanceMetrics.throttledEvents)
      print("  Cached resources: " .. performanceMetrics.cachedResources)
      print("  Lazy loaded interfaces: " .. performanceMetrics.lazyLoadedInterfaces)
    end
  })
  
  print("Client Optimization: Performance optimizations enabled")
end

function terminate()
  ClientOptimization.stopMonitoring()
end

return ClientOptimization

