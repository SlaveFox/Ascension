-- modules/game_debuffhud/debuffhud.lua
-- Debuff HUD: flutuante; com borda dourada ao mover

debuffhud = {}

-- =========[ Estado / Constantes ]=========
local lastTimers, stagedTimers = {}, nil       -- [bit] = ms restante
local timersTickerEv, lastTimersLastTick = nil, nil

-- Variáveis globais para otimização
local globalTimer = nil
local pendingUpdates = {}
local lastUpdateTime = 0
local UPDATE_THROTTLE = 16 -- ms entre atualizações (60fps)

local TICK_MS        = 50  -- Restaurado para melhor responsividade

-- Cache otimizado para debuffhud
local debuffCache = {}
local lastDebuffUpdate = 0
local DEBUFF_UPDATE_THROTTLE = 16 -- ~60 FPS
local LIST_TOP       = 0

local customWnd, phantomBefore = nil, true
local window, didSetup = nil, false
local movingMode, dragging = false, false
local running = {}            -- anima??ees por widget
local dragOverlay = nil       -- overlay de arraste

local TOP_TWEAK_NORMAL = 4
local TOP_MARGIN_MOVE  = 2
local _phantomBackup   = nil

-- =========[ ?cones por PlayerStates ]=========
local STATE_ICONS = {}
STATE_ICONS[PlayerStates.Poison]     = { tip = tr('You are poisoned'),                              path = '/images/game/states/poisoned',            id = 'condition_poisoned' }
STATE_ICONS[PlayerStates.Burn]       = { tip = tr('You are burning'),                               path = '/images/game/states/burning',             id = 'condition_burning' }
STATE_ICONS[PlayerStates.Energy]     = { tip = tr('You are electrified'),                           path = '/images/game/states/electrified',         id = 'condition_electrified' }
STATE_ICONS[PlayerStates.Drunk]      = { tip = tr('You are drunk'),                                 path = '/images/game/states/drunk',               id = 'condition_drunk' }
STATE_ICONS[PlayerStates.ManaShield] = { tip = tr('You are protected by a magic shield'),           path = '/images/game/states/magic_shield',        id = 'condition_magic_shield' }
STATE_ICONS[PlayerStates.Paralyze]   = { tip = tr('You are paralysed'),                             path = '/images/game/states/slowed',              id = 'condition_slowed' }
STATE_ICONS[PlayerStates.Haste]      = { tip = tr('You are hasted'),                                path = '/images/game/states/haste',               id = 'condition_haste' }
STATE_ICONS[PlayerStates.Swords]     = { tip = tr('You may not logout during a fight'),             path = '/images/game/states/logout_block',        id = 'condition_logout_block' }
STATE_ICONS[PlayerStates.Drowning]   = { tip = tr('You are drowning'),                              path = '/images/game/states/drowning',            id = 'condition_drowning' }
STATE_ICONS[PlayerStates.Freezing]   = { tip = tr('You are freezing'),                              path = '/images/game/states/freezing',            id = 'condition_freezing' }
STATE_ICONS[PlayerStates.Dazzled]    = { tip = tr('You are dazzled'),                               path = '/images/game/states/dazzled',             id = 'condition_dazzled' }
STATE_ICONS[PlayerStates.Cursed]     = { tip = tr('You are cursed'),                                path = '/images/game/states/cursed',              id = 'condition_cursed' }
STATE_ICONS[PlayerStates.PartyBuff]  = { tip = tr('You are strengthened'),                          path = '/images/game/states/strengthened',        id = 'condition_strengthened' }
STATE_ICONS[PlayerStates.PzBlock]    = { tip = tr('You may not logout or enter a protection zone'), path = '/images/game/states/protection_zone_block', id = 'condition_protection_zone_block' }
STATE_ICONS[PlayerStates.Pz]         = { tip = tr('You are within a protection zone'),              path = '/images/game/states/protection_zone',     id = 'condition_protection_zone' }
STATE_ICONS[PlayerStates.Bleeding]   = { tip = tr('You are bleeding'),                              path = '/images/game/states/bleeding',            id = 'condition_bleeding' }
STATE_ICONS[PlayerStates.Hungry]     = { tip = tr('You are hungry'),                                path = '/images/game/states/hungry',              id = 'condition_hungry' }
STATE_ICONS[PlayerStates.Invisible]  = { tip = tr('You are invisible'),                             path = '/images/game/states/invisible',           id = 'condition_invisible' }

-- Aliases
local PS  = PlayerStates
local PZ  = PS.Pz
local PZB = PS.PzBlock

-- =========[ Helpers gerais ]=========
local function charKeyPrefix()
  local name = (g_game and g_game.getCharacterName and g_game.getCharacterName()) or 'global'
  if name == '' then name = 'global' end
  return 'debuffhud/' .. name .. '/'
end

local function currentPrefix()
  local name = (g_game and g_game.getCharacterName and g_game.getCharacterName()) or ''
  if not name or name == '' then name = 'global' end
  return 'debuffhud/' .. name .. '/'
end

local function hasSavedPosFor(prefix)
  prefix = tostring(prefix or currentPrefix())
  local px = tonumber(g_settings.getValue(prefix .. 'posx'))
  local py = tonumber(g_settings.getValue(prefix .. 'posy'))
  return (px ~= nil and py ~= nil), px, py
end

local function hasSavedPosGlobal() return hasSavedPosFor('debuffhud/global/') end
local function hasSavedPosChar()
  local name = (g_game and g_game.getCharacterName and g_game.getCharacterName()) or ''
  if not name or name == '' then return false end
  return hasSavedPosFor('debuffhud/' .. name .. '/')
end

local function savePosition(w)
  if not (w and w.getPosition and not w:isDestroyed()) then return end
  local p = w:getPosition()
  if type(p) == 'table' and type(p.x) == 'number' and type(p.y) == 'number' then
    local base = currentPrefix()
    g_settings.setValue(base .. 'posx', p.x)
    g_settings.setValue(base .. 'posy', p.y)
    if g_settings.save then pcall(function() g_settings.save() end)
    elseif g_settings.sync then pcall(function() g_settings.sync() end) end
  end
end

-- Pr?-login: aplica GLOBAL se existir; n?o grava caso n?o exista
local function restorePosGlobalIfExists(w)
  if not w or w:isDestroyed() then return end
  local okG, gx, gy = hasSavedPosGlobal()
  local function doRestore()
    if not w or w:isDestroyed() then return end
    if w.breakAnchors then w:breakAnchors() end
    if okG then w:setPosition({ x = gx, y = gy }) end
  end
  -- Otimiza��o: reduzir n�mero de scheduleEvents
  scheduleEvent(doRestore, 100)
end

-- P?s-login: prefere CHAR; se n?o houver, migra do GLOBAL para CHAR; sen?o n?o altera
local function restorePosCharWithFallback(w)
  if not w or w:isDestroyed() then return end
  local okC, cx, cy = hasSavedPosChar()
  local okG, gx, gy = hasSavedPosGlobal()
  local function doRestore()
    if not w or w:isDestroyed() then return end
    if w.breakAnchors then w:breakAnchors() end
    if okC then
      w:setPosition({ x = cx, y = cy })
    elseif okG then
      w:setPosition({ x = gx, y = gy })
      savePosition(w) -- grava no prefixo do CHAR
    end
  end
  -- Otimiza��o: reduzir n�mero de scheduleEvents
  scheduleEvent(doRestore, 100)
end

-- =========[ Config persistente por char ]=========
local function cfgKey(k) return charKeyPrefix() .. 'cfg/' .. k end
local DEFAULTS = {
  enabled     = true,
  bgColor     = '#00000000',
  maskOpacity = 0.65,        -- 0..1
  maskColor   = '#808080',   -- #RRGGBB
  itemSize    = 26,          -- 12..64
  spacing     = 4,           -- 0..24
}

local function asBool(v, default)
  if v == nil then return default and true or false end
  local t = type(v)
  if t == 'boolean' then return v end
  if t == 'number'  then return v ~= 0 end
  if t == 'string'  then
    local s = v:lower()
    if s == 'true' or s == '1' or s == 'on' or s == 'yes'  then return true  end
    if s == 'false'or s == '0' or s == 'off'or s == 'no'   then return false end
  end
  return v and true or false
end
local function sanitizeColorRGB(s)
  if type(s) ~= 'string' then return DEFAULTS.maskColor end
  return s:match('^#%x%x%x%x%x%x$') or DEFAULTS.maskColor
end
local function sanitizeColor(s)
  if type(s) ~= 'string' then return DEFAULTS.bgColor end
  return s:match('^#%x%x%x%x%x%x%x%x$') or s:match('^#%x%x%x%x%x%x$') or DEFAULTS.bgColor
end
local function cfgGet(k)  local v = g_settings.getValue(cfgKey(k)); if v == nil then return DEFAULTS[k] end; return v end
local function cfgSet(k,v) g_settings.setValue(cfgKey(k), v) end
local function cfgNum(k)  local v = tonumber(cfgGet(k)) or tonumber(DEFAULTS[k]) or 0; return v end
function debuffhud.isEnabled()
  return asBool(cfgGet('enabled'), DEFAULTS.enabled)
end

-- =========[ UI helpers ]=========
local function getContents()
  if not window or window:isDestroyed() then return nil end
  return window:recursiveGetChildById('contentsPanel') or window
end

local function getList()
  if not window or window:isDestroyed() then return nil end
  local contents = getContents()
  if not contents or contents:isDestroyed() then return nil end
  local list = contents:recursiveGetChildById('itemsList') or contents:recursiveGetChildById('infoPanel')
  if not (list and not list:isDestroyed()) then
    local ok, created = pcall(function() return g_ui.createWidget('ScrollablePanel', contents) end)
    list = ok and created or g_ui.createWidget('UIWidget', contents)
    list:setId('itemsList')
    list:addAnchor(AnchorTop, 'parent', AnchorTop)
    list:addAnchor(AnchorLeft, 'parent', AnchorLeft)
    list:addAnchor(AnchorRight, 'parent', AnchorRight)
    list:addAnchor(AnchorBottom, 'parent', AnchorBottom)
    if list.setLayout and not list:getLayout() then
      pcall(function() list:setLayout(UIVBoxLayout.create()) end)
    end
  end
  local lay = list.getLayout and list:getLayout() or nil
  if lay and lay.setSpacing then lay:setSpacing(math.max(0, math.min(24, cfgNum('spacing')))) end
  return list
end

local function positionListForMode(list)
  if not list then return end
  pcall(function() list:removeAnchors() end)
  list:addAnchor(AnchorTop, 'parent', AnchorTop)
  list:addAnchor(AnchorHorizontalCenter, 'parent', AnchorHorizontalCenter)
  list:setMarginTop((movingMode and TOP_MARGIN_MOVE or 0) + TOP_TWEAK_NORMAL + LIST_TOP)
end

local function ensureWindow()
  local parent = rootWidget
  if not window or window:isDestroyed() then
    local ok, wnd = pcall(function() return g_ui.loadUI('debuffhud', parent) end)
    window, didSetup = (ok and wnd) or nil, false
    if window and not window._posHooked then
      window._posHooked = true
      window.onPositionChange = function(_) savePosition(window) end
    end
    -- Configurar como phantom por padr?o para n?o interferir com outros sistemas
    if window and window.setPhantom then window:setPhantom(true) end
  end
  if window and not didSetup and type(window.setup) == 'function' then
    window:setup(); didSetup = true
  end
  local tb = window and window:recursiveGetChildById('titlebar')
  if tb then tb:hide(); pcall(function() tb:setHeight(0) end) end
  if window and not window._preloginPosDone then
    restorePosGlobalIfExists(window)
    window._preloginPosDone = true
  end
  local list = getList()
  positionListForMode(list)
  return window
end

-- =======[ Fundo (cor + alpha) apenas contentsPanel ]=======
local function applyBackground()
  local contents = getContents()
  if not contents or contents:isDestroyed() then return end
  local hex = sanitizeColor(cfgGet('bgColor') or DEFAULTS.bgColor)
  if contents.setBackgroundColor then contents:setBackgroundColor(hex) end
end

-- =========[ Overlay para drag ]=========
local function ensureDragOverlay()
  if not window or window:isDestroyed() then return nil end
  local ov = window:recursiveGetChildById('dragOverlay')
  if ov and not ov:isDestroyed() then return ov end
  ov = g_ui.createWidget('UIWidget', window)
  ov:setId('dragOverlay')
  ov:addAnchor(AnchorTop, 'parent', AnchorTop)
  ov:addAnchor(AnchorLeft, 'parent', AnchorLeft)
  ov:addAnchor(AnchorRight,'parent', AnchorRight)
  ov:addAnchor(AnchorBottom,'parent', AnchorBottom)
  if ov.setBackgroundColor then ov:setBackgroundColor('#00000000') end
  if ov.setPhantom then ov:setPhantom(false) end
  ov:raise()
  dragOverlay = ov
  return ov
end

local function destroyDragOverlay()
  local ov = window and window:recursiveGetChildById('dragOverlay')
  if ov and not ov:isDestroyed() then ov:destroy() end
  dragOverlay = nil
end

-- For?a pass-through (phantom=true) em todos os filhos do window durante o mover
local function setChildrenPassThrough(enabled)
  if not window or window:isDestroyed() then return end
  if enabled then
    _phantomBackup = {}
    local function mark(w)
      if not (w and w.getId and w.setPhantom and w.getPhantom) then return end
      if w:getId() == 'dragOverlay' then return end
      _phantomBackup[w] = w:getPhantom()
      w:setPhantom(true)
    end
    local function recurse(root)
      local kids = root.getChildren and root:getChildren() or {}
      for _, ch in ipairs(kids) do mark(ch); recurse(ch) end
    end
    recurse(window)
    if window.setPhantom then window:setPhantom(false) end
    local ov = window:recursiveGetChildById('dragOverlay'); if ov and ov.setPhantom then ov:setPhantom(false) end
  else
    if _phantomBackup then
      for w, prev in pairs(_phantomBackup) do
        if w and not w:isDestroyed() and w.setPhantom then w:setPhantom(prev) end
      end
    end
    _phantomBackup = nil
  end
end

-- =========[ Constantes din?micas ]=========
local function ITEM_H()       return math.max(12, math.min(64, cfgNum('itemSize'))) end
local function ITEM_SPACING() return math.max(0,  math.min(24, cfgNum('spacing'))) end

-- =========[ Borda dourada (visual) ]=========
local function setMoveBorderEnabled(enabled)
  if not window or window:isDestroyed() then return end
  local parent = window
  local function mk(id, side)
    local w = parent:recursiveGetChildById(id)
    if w and not w:isDestroyed() then return w end
    w = g_ui.createWidget('UIWidget', parent)
    w:setId(id)
    w:setBackgroundColor('#FFD700CC')
    w:raise()
    -- Garantir que as bordas sejam phantom para n?o interferir com cliques
    if w.setPhantom then w:setPhantom(true) end
    if side == 'top' then
      w:addAnchor(AnchorTop, 'parent', AnchorTop)
      w:addAnchor(AnchorLeft, 'parent', AnchorLeft)
      w:addAnchor(AnchorRight,'parent', AnchorRight)
      w:setHeight(2)
    elseif side == 'bottom' then
      w:addAnchor(AnchorBottom, 'parent', AnchorBottom)
      w:addAnchor(AnchorLeft,   'parent', AnchorLeft)
      w:addAnchor(AnchorRight,  'parent', AnchorRight)
      w:setHeight(2)
    elseif side == 'left' then
      w:addAnchor(AnchorTop,    'parent', AnchorTop)
      w:addAnchor(AnchorBottom, 'parent', AnchorBottom)
      w:addAnchor(AnchorLeft,   'parent', AnchorLeft)
      w:setWidth(2)
    else
      w:addAnchor(AnchorTop,    'parent', AnchorTop)
      w:addAnchor(AnchorBottom, 'parent', AnchorBottom)
      w:addAnchor(AnchorRight,  'parent', AnchorRight)
      w:setWidth(2)
    end
    return w
  end
  local ids = { 'goldBorderTop','goldBorderBottom','goldBorderLeft','goldBorderRight' }
  if enabled then
    mk(ids[1], 'top'); mk(ids[2], 'bottom'); mk(ids[3], 'left'); mk(ids[4], 'right')
  else
    for _, id in ipairs(ids) do
      local w = parent:recursiveGetChildById(id)
      if w and not w:isDestroyed() then w:destroy() end
    end
  end
end

-- =========[ C?lculo de altura ]=========
local function visibleChildCount(list)
  local n = 0
  for _, ch in ipairs(list:getChildren() or {}) do
    if ch and not ch:isDestroyed() and (not ch.isVisible or ch:isVisible()) then n = n + 1 end
  end
  return n
end

local function updateWindowHeight()
  if not window or window:isDestroyed() then return end
  local list = getList(); if not list then return end
  local count = visibleChildCount(list)

  local px        = ITEM_H()
  local spacing   = ITEM_SPACING()
  local topPad    = (movingMode and TOP_MARGIN_MOVE or 0) + TOP_TWEAK_NORMAL + LIST_TOP
  local bottomPad = 4
  local minH      = 30

  local contentH = (count > 0) and (count * px + (count - 1) * spacing) or 0
  local desiredH = math.max(minH, topPad + contentH + bottomPad)

  if window.setHeight then window:setHeight(desiredH) end
end

-- =========[ Drag (usando pos do evento; sem grabMouse) ]=========
local function attachDrag(handle, target)
  if not (handle and target) then return end
  local pressOffset = nil

  handle.onMousePress = function(_, pos, button)
    if button ~= MouseLeftButton then return false end
    dragging = true
    local tp = target.getPosition and target:getPosition() or { x = 0, y = 0 }
    pressOffset = { x = pos.x - tp.x, y = pos.y - tp.y }
    target:raise()
    return true
  end

  handle.onMouseMove = function(_, pos)
    if not dragging or not pressOffset then return false end
    local nx, ny = pos.x - pressOffset.x, pos.y - pressOffset.y
    if target.setPosition then pcall(function() target:setPosition({ x = nx, y = ny }) end) end
    return true
  end

  handle.onMouseRelease = function(_, _, button)
    if button and button ~= MouseLeftButton then return false end
    if not dragging then return false end
    dragging = false
    pressOffset = nil
    savePosition(target)
    return true
  end

  handle.onKeyDown = function(_, keyCode)
    if keyCode == 27 or keyCode == 13 or keyCode == KeyEnter or keyCode == KeyReturn then debuffhud.lock(); return true end
    return false
  end
end

local function detachDrag(handle)
  if not handle then return end
  handle.onMousePress, handle.onMouseMove, handle.onMouseRelease, handle.onKeyDown = nil, nil, nil, nil
  dragging = false
end

-- =========[ Ticker de timers ]=========
local syncStates -- fwd
-- Fun��o otimizada para parar timer centralizado
local function stopTimersTicker() 
  if timersTickerEv then removeEvent(timersTickerEv) end
  if globalTimer then removeEvent(globalTimer) end
  timersTickerEv = nil
  globalTimer = nil
  lastTimersLastTick = nil
  pendingUpdates = {}
end

-- Função otimizada para pumpTimers com throttling
local function pumpTimers()
  if not window or window:isDestroyed() or not next(lastTimers) then 
    stopTimersTicker()
    return 
  end
  
  local now = g_clock.millis()
  local prev = lastTimersLastTick or now
  local dt = math.max(0, now - prev)
  lastTimersLastTick = now
  
  local changed = false
  for bit, ms in pairs(lastTimers) do
    local newMs = (tonumber(ms) or 0) - dt
    if newMs <= 0 then 
      lastTimers[bit] = nil
      changed = true 
    else 
      lastTimers[bit] = newMs 
    end
  end
  
  -- Usar throttling para atualizações de estado
  if changed then
    local now = g_clock.millis()
    if now - lastDebuffUpdate >= DEBUFF_UPDATE_THROTTLE then
      local p = g_game.getLocalPlayer()
      local states = p and p.getStates and p:getStates() or 0
      syncStates(states)
      lastDebuffUpdate = now
    end
  end
  
  timersTickerEv = scheduleEvent(pumpTimers, TICK_MS)
end

-- Fun��o otimizada para garantir timer �nico
local function ensureTimersTicker()
  if timersTickerEv then return end
  lastTimersLastTick = g_clock.millis()
  lastUpdateTime = g_clock.millis()
  timersTickerEv = scheduleEvent(pumpTimers, TICK_MS)
end

-- =========[ Anima??es utilit?rias ]=========
local function stopAnim(w) local ev = running[w]; if ev then removeEvent(ev) end; running[w] = nil end

local function ensureGreyMask(item)
  local mask = item:recursiveGetChildById('greyMask')
  if mask and not mask:isDestroyed() then
    if mask.setOpacity then mask:setOpacity(cfgNum('maskOpacity')) end
    return mask
  end
  mask = g_ui.createWidget('UIWidget', item)
  mask:setId('greyMask')
  mask:setWidth(item:getWidth()); mask:setHeight(0)
  mask:addAnchor(AnchorTop,'parent',AnchorTop)
  mask:addAnchor(AnchorLeft,'parent',AnchorLeft)
  mask:setBackgroundColor(sanitizeColorRGB(cfgGet('maskColor') or DEFAULTS.maskColor))
  if mask.setOpacity then mask:setOpacity(cfgNum('maskOpacity')) end
  mask:raise()
  return mask
end

local function ensureTimerLabel(item)
  local lbl = item:recursiveGetChildById('timerLabel')
  if lbl and not lbl:isDestroyed() then return lbl end
  lbl = g_ui.createWidget('Label', item)
  lbl:setId('timerLabel')
  lbl:addAnchor(AnchorBottom, 'parent', AnchorBottom)
  lbl:addAnchor(AnchorHorizontalCenter, 'parent', AnchorHorizontalCenter)
  pcall(function() lbl:setTextAlign(AlignCenter) end)
  lbl:setText('')
  lbl:raise()
  return lbl
end

-- Fun��o otimizada para anima��o de timer com throttling
local function startTimerAnim(item, msLeft)
  stopAnim(item)
  if not item or item:isDestroyed() then return end
  
  local mask = ensureGreyMask(item)
  local lbl = ensureTimerLabel(item)
  local totalMs = math.max(1, tonumber(msLeft) or 1)
  local start = g_clock.millis()
  local lastAnimUpdate = 0
  local ANIM_THROTTLE = 100 -- ms entre atualiza��es de anima��o (reduzido para melhor performance)
  
  local function step()
    if not window or window:isDestroyed() or not item or item:isDestroyed() then 
      stopAnim(item)
      return 
    end
    
    local now = g_clock.millis()
    local elapsed = now - start
    local remaining = math.max(0, totalMs - elapsed)
    local pct = math.min(1, elapsed / totalMs)
    
    if mask and not mask:isDestroyed() then
      mask:setWidth(item:getWidth())
      mask:setHeight(math.floor((item.getHeight and item:getHeight() or ITEM_H()) * pct))
    end
    
    if lbl and not lbl:isDestroyed() then
      local secsLeft = math.ceil(remaining / 1000)
      lbl:setText(secsLeft > 0 and tostring(secsLeft) or '0')
      lbl:raise()
    end
    
    if pct < 1 then
      running[item] = scheduleEvent(step, ANIM_THROTTLE)
    else
      running[item] = nil
      if mask and not mask:isDestroyed() then 
        mask:setHeight(item.getHeight and item:getHeight() or ITEM_H()) 
      end
    end
  end
  
  running[item] = scheduleEvent(step, ANIM_THROTTLE)
end

local function destroyItem(w)
  if not (w and not w:isDestroyed()) then return end
  g_effects.fadeOut(w, 180)
  scheduleEvent(function() if w and not w:isDestroyed() then w:destroy() end; updateWindowHeight() end, 190)
end

local function clearAll()
  stopTimersTicker()
  for w, ev in pairs(running) do if ev then removeEvent(ev) end end
  running = {}
  if not (window and not window:isDestroyed()) then return end
  local list = getList(); if not list then updateWindowHeight(); return end
  for i = #(list:getChildren() or {}), 1, -1 do
    local ch = (list:getChildren() or {})[i]
    if ch and not ch:isDestroyed() then ch:destroy() end
  end
  updateWindowHeight()
end

-- =========[ Render de Estados ]=========
local function spawnStateIcon(list, def)
  -- Verificar se j� existe um widget com esse ID
  for _, child in ipairs(list:getChildren() or {}) do
    if child and not child:isDestroyed() and child:getId() == def.id then
      return child -- Retornar o widget existente
    end
  end
  
  local item = g_ui.createWidget('UIWidget', list)
  item:setId(def.id)
  item:setSize(ITEM_H() .. ' ' .. ITEM_H())
  local base = g_ui.createWidget('UIWidget', item)
  base:setId('baseImage')
  base:addAnchor(AnchorTop,'parent',AnchorTop)
  base:addAnchor(AnchorLeft,'parent',AnchorLeft)
  base:addAnchor(AnchorRight,'parent',AnchorRight)
  base:addAnchor(AnchorBottom,'parent',AnchorBottom)
  base:setImageSource(def.path)
  local lbl = ensureTimerLabel(item); if lbl then lbl:setText('') end
  if item.setTooltip and def.tip then item:setTooltip(def.tip) end
  if base.setTooltip and def.tip then base:setTooltip(def.tip) end
  item:show()
  g_effects.fadeIn(item, 100)
  return item
end

local function spawnCooldownItem(list, durationSec, def)
  if not list or list:isDestroyed() then return nil end
  
  -- Verificar se j� existe um widget com esse ID
  for _, child in ipairs(list:getChildren() or {}) do
    if child and not child:isDestroyed() and child:getId() == def.id then
      return child -- Retornar o widget existente
    end
  end
  
  local item
  local ok, created = pcall(function() return g_ui.createWidget('CooldownItem', list) end)
  if ok and created then
    item = created
  else
    item = g_ui.createWidget('UIWidget', list)
    local base = g_ui.createWidget('UIWidget', item)
    base:setId('baseImage')
    base:addAnchor(AnchorTop,'parent',AnchorTop)
    base:addAnchor(AnchorLeft,'parent',AnchorLeft)
    base:addAnchor(AnchorRight,'parent',AnchorRight)
    base:addAnchor(AnchorBottom,'parent',AnchorBottom)
    local mask = g_ui.createWidget('UIWidget', item)
    mask:setId('greyMask')
    mask:addAnchor(AnchorTop,'parent',AnchorTop)
    mask:addAnchor(AnchorLeft,'parent',AnchorLeft)
    mask:setHeight(0)
    if mask.setOpacity then mask:setOpacity(cfgNum('maskOpacity')) end
    mask:raise()
  end
  item:setSize(ITEM_H() .. ' ' .. ITEM_H())
  local baseImg = item:recursiveGetChildById('baseImage')
  if baseImg then baseImg:setImageSource(def.path) end
  local tip = def.tip or def.id
  if item.setTooltip then item:setTooltip(tip) end
  if baseImg and baseImg.setTooltip then baseImg:setTooltip(tip) end
  local maskW = item:recursiveGetChildById('greyMask')
  if maskW and not maskW:isDestroyed() then
    if maskW.setBackgroundColor then maskW:setBackgroundColor(sanitizeColorRGB(cfgGet('maskColor') or DEFAULTS.maskColor)) end
    if maskW.setOpacity then maskW:setOpacity(cfgNum('maskOpacity')) end
    maskW:setWidth(item:getWidth())
    if maskW:getHeight() > item:getHeight() then maskW:setHeight(item:getHeight()) end
  end
  ensureTimerLabel(item)
  item:setId(def.id)
  item:show()
  g_effects.fadeIn(item, 100)
  updateWindowHeight()
  startTimerAnim(item, math.max(1, math.floor((durationSec or 0) * 1000)))
  return item
end

function syncStates(now)
  if not window or window:isDestroyed() then return end
  local list = getList(); if not list then return end
  local timers = lastTimers

  -- Primeiro, coletar todos os estados ativos
  local activeStates = {}
  for stateBit, def in pairs(STATE_ICONS) do
    local ms = timers[stateBit]
    local bitOn = bit32.band(now or 0, stateBit) ~= 0
    local ativo = bitOn or (ms and ms > 0)
    
    if ativo then
      activeStates[stateBit] = {
        def = def,
        hasTimer = ms and ms > 0,
        timerMs = ms
      }
    end
  end

  -- Remover widgets que n�o est�o mais ativos
  local children = list:getChildren() or {}
  for i = #children, 1, -1 do
    local ch = children[i]
    if ch and not ch:isDestroyed() then
      local found = false
      for stateBit, data in pairs(activeStates) do
        if ch:getId() == data.def.id then
          found = true
          break
        end
      end
      if not found then
        destroyItem(ch)
      end
    end
  end

  -- Criar/atualizar widgets para estados ativos
  for stateBit, data in pairs(activeStates) do
    -- Procurar widget existente de forma mais robusta
    local w = nil
    for _, child in ipairs(list:getChildren() or {}) do
      if child and not child:isDestroyed() and child:getId() == data.def.id then
        w = child
        break
      end
    end
    
    if not w then
      -- Criar novo widget
      if data.hasTimer then
        spawnCooldownItem(list, data.timerMs / 1000, data.def)
      else
        spawnStateIcon(list, data.def)
      end
    else
      -- Verificar se precisa converter para cooldown
      local hasMask = w:recursiveGetChildById('greyMask') ~= nil
      if data.hasTimer and not hasMask then
        destroyItem(w)
        spawnCooldownItem(list, data.timerMs / 1000, data.def)
      elseif not data.hasTimer and hasMask then
        destroyItem(w)
        spawnStateIcon(list, data.def)
      end
    end
  end

  -- Ordenar widgets por bit para estabilidade visual
  local visible = {}
  for stateBit, data in pairs(activeStates) do
    table.insert(visible, { bit = stateBit, id = data.def.id })
  end
  table.sort(visible, function(a,b) return a.bit < b.bit end)
  
  -- Aplicar ordem
  for i, v in ipairs(visible) do
    local w = list:recursiveGetChildById(v.id)
    if w and not w:isDestroyed() then
      w:raise()
    end
  end

  updateWindowHeight()
end

-- =========[ Fun��o de sincroniza��o for�ada ]=========
function debuffhud.forceSync()
  if not debuffhud.isEnabled() then return end
  local p = g_game.getLocalPlayer()
  if p and p.getStates then
    syncStates(p:getStates() or 0)
  end
end

-- =========[ API P?blica ]=========
function debuffhud.init()
  connect(g_game, {
    onGameStart = function()
      if not debuffhud.isEnabled() then return end
      ensureWindow()
      if window and window.open then window:open() end
      if window and window.setPhantom then window:setPhantom(true) end
      restorePosCharWithFallback(window)
      local p = g_game.getLocalPlayer()
      if p and p.getStates then syncStates(p:getStates() or 0) else clearAll() end
      debuffhud.applyStyle()
    end,
    onGameEnd = function() clearAll() end,
  })

  connect(LocalPlayer, {
    onStateTimersBegin = function()
      if not debuffhud.isEnabled() then return end
      stagedTimers = {}
    end,
    onStateTimersAdd = function(_, bit, ms)
      if not debuffhud.isEnabled() then return end
      if stagedTimers then stagedTimers[bit] = ms end
    end,
    onStateTimersEnd = function()
      if not debuffhud.isEnabled() then return end
      if stagedTimers and next(stagedTimers) then lastTimers = stagedTimers end
      stagedTimers = nil
      local p = g_game.getLocalPlayer()
      local statesNow = p and p.getStates and p:getStates() or 0
      if bit32.band(statesNow, PZ) ~= 0 then lastTimers[PZB] = nil end
      ensureTimersTicker()
      -- Atualizar imediatamente quando timers mudam
      syncStates(statesNow or 0)
    end,
    onStatesChange = function(_, now, old)
      if not debuffhud.isEnabled() then return end
      if old ~= nil then
        local bitsCleared = bit32.band(old, bit32.bnot(now))
        if bitsCleared ~= 0 then
          for i = 0, 31 do
            local mask = bit32.lshift(1, i)
            if bit32.band(bitsCleared, mask) ~= 0 then lastTimers[mask] = nil end
          end
        end
      end
      if bit32.band(now or 0, PZ) ~= 0 then lastTimers[PZB] = nil end
      -- Atualizar imediatamente quando estados mudam
      syncStates(now or 0)
    end,
  })
end

function debuffhud.terminate()
  clearAll()
  if window and not window:isDestroyed() then window:destroy() end
  window = nil
end

function debuffhud.toggle()
  if not window or window:isDestroyed() then debuffhud.show(); return end
  if window.isOpen and window:isOpen() then debuffhud.hide() else debuffhud.show() end
end

function debuffhud.show()
  if not debuffhud.isEnabled() then return end
  ensureWindow(); if not window then return end
  movingMode = false
  setChildrenPassThrough(false)
  if window.setPhantom then window:setPhantom(true) end

  local handle = window:recursiveGetChildById('dragOverlay') or getContents() or window
  if handle then detachDrag(handle) end
  destroyDragOverlay()
  setMoveBorderEnabled(false)

  if window.open then window:open() else window:show() end
  window:raise(); window:focus()

  clearAll()
  local list = getList(); if not list then return end
  local p = g_game.getLocalPlayer()
  syncStates(p and p:getStates() or 0)
  debuffhud.applyStyle()
end

function debuffhud.hide()
  clearAll()
  if window and not window:isDestroyed() then
    if window.close then window:close() else window:hide() end
  end
end

-- Modo mover (drag + borda dourada)
function debuffhud.move()
  if not debuffhud.isEnabled() then return end
  ensureWindow(); if not window then return end
  movingMode = true
  if window.open then window:open() else window:show() end
  window:raise(); window:focus()

  local handle = ensureDragOverlay() or window
  setChildrenPassThrough(true)
  attachDrag(handle, window)
  setMoveBorderEnabled(true)

  debuffhud.applyStyle()
  debuffhud.customize()
end

function debuffhud.lock()
  if not window or window:isDestroyed() then return end
  savePosition(window)

  local handle = window:recursiveGetChildById('dragOverlay') or window
  detachDrag(handle)
  destroyDragOverlay()
  setMoveBorderEnabled(false)
  setChildrenPassThrough(false)

  movingMode = false
  if window.setPhantom then window:setPhantom(true) end
  debuffhud.show()
  local p = g_game.getLocalPlayer()
  if p and p.getStates then syncStates(p:getStates() or 0) end
end

-- =========[ Aplica??o de estilo + setters ]=========
local function setContainerWidthForItem(px)
  if not window or window:isDestroyed() then return end
  local contents = getContents()
  if contents and contents.setWidth then contents:setWidth(px) end
  if window.setWidth and window.getWidth then
    local desired = math.max(window:getWidth() or 0, px + 8)
    window:setWidth(desired)
  end
end

function debuffhud.applyStyle()
  if not window or window:isDestroyed() then return end
  local px = ITEM_H()
  setContainerWidthForItem(px)
  local list = getList()
  if list then
    local lay = list.getLayout and list:getLayout() or nil
    if lay and lay.setSpacing then lay:setSpacing(ITEM_SPACING()) end
    for _, ch in ipairs(list:getChildren() or {}) do
      if ch and not ch:isDestroyed() then
        ch:setSize(ITEM_H() .. ' ' .. ITEM_H())
        local mask = ch:recursiveGetChildById('greyMask')
        if mask and not mask:isDestroyed() then
          if mask.setOpacity         then mask:setOpacity(cfgNum('maskOpacity')) end
          if mask.setBackgroundColor then mask:setBackgroundColor(sanitizeColorRGB(cfgGet('maskColor') or DEFAULTS.maskColor)) end
          mask:setWidth(ch:getWidth())
          if mask:getHeight() > ch:getHeight() then mask:setHeight(ch:getHeight()) end
        end
      end
    end
  end
  applyBackground() -- somente contentsPanel
  positionListForMode(list)
  updateWindowHeight()
end

-- Preserva alpha existente se hex vier como #RRGGBB
function debuffhud.setBgColor(hex)
  local newHex = sanitizeColor(hex)
  if #newHex == 7 then
    local prev = sanitizeColor(cfgGet('bgColor') or DEFAULTS.bgColor)
    local a = (#prev == 9) and prev:sub(8,9) or '00'
    newHex = string.format('#%s%s', newHex:sub(2,7), a)
  end
  cfgSet('bgColor', newHex)
  debuffhud.applyStyle()
end

function debuffhud.setMaskColor(hex) cfgSet('maskColor', sanitizeColorRGB(hex)); debuffhud.applyStyle() end
function debuffhud.setMaskOpacity(op) op = tonumber(op) or DEFAULTS.maskOpacity; op = math.max(0, math.min(1, op)); cfgSet('maskOpacity', op); debuffhud.applyStyle() end
function debuffhud.setItemSize(px)   px = tonumber(px) or DEFAULTS.itemSize; px = math.max(12, math.min(64, px)); cfgSet('itemSize', px); debuffhud.applyStyle() end
function debuffhud.setSpacing(px)    px = tonumber(px) or DEFAULTS.spacing;  px = math.max(0,  math.min(24, px)); cfgSet('spacing',  px); debuffhud.applyStyle() end

-- === Customizer (parte relevante) ===
function debuffhud.customize()
  ensureWindow()
  if customWnd and not customWnd:isDestroyed() then customWnd:raise(); customWnd:focus(); return end
  local parent = rootWidget
  local ok, wnd = pcall(function() return g_ui.createWidget('DebuffHudCustomizer', parent) end)
  if not ok or not wnd then return end
  customWnd = wnd

  if window and not window:isDestroyed() and window.getPhantom then phantomBefore = window:getPhantom() end

  local moveToggle     = customWnd:recursiveGetChildById('moveToggle')
  local resetBtn       = customWnd:recursiveGetChildById('resetBtn')
  local closeBtn       = customWnd:recursiveGetChildById('closeBtn')
  local bgScr          = customWnd:recursiveGetChildById('bgOpacityScroll')
  local maskScr        = customWnd:recursiveGetChildById('maskOpacityScroll')
  local bgLbl          = customWnd:recursiveGetChildById('bgOpacityLabel')
  local maskLbl        = customWnd:recursiveGetChildById('maskOpacityLabel')
  local maskModeToggle = customWnd:recursiveGetChildById('paletteMaskToggle')
  local colorPanel     = customWnd:recursiveGetChildById('colorBoxPanel')
  local size26Toggle   = customWnd:recursiveGetChildById('size26Toggle')
  local size32Toggle   = customWnd:recursiveGetChildById('size32Toggle')
  local size64Toggle   = customWnd:recursiveGetChildById('size64Toggle')

  if bgScr and bgLbl then
    local hex = cfgGet('bgColor') or DEFAULTS.bgColor
    local a = tonumber(hex:sub(#hex-1, #hex), 16) or 0
    local pct = math.floor(a * 100 / 255 + 0.5)
    bgScr:setValue(pct); bgLbl:setText(string.format("Opacidade do Fundo: %d%%", pct))
  end
  if maskScr and maskLbl then
    local m = tonumber(cfgGet('maskOpacity') or DEFAULTS.maskOpacity) or DEFAULTS.maskOpacity
    local pct = math.floor(m * 100 + 0.5)
    maskScr:setValue(pct); maskLbl:setText(string.format("Opacidade da M?scara: %d%%", pct))
  end

  local function setSizePresetChecked(px)
    if size26Toggle then size26Toggle:setChecked(px == 26) end
    if size32Toggle then size32Toggle:setChecked(px == 32) end
    if size64Toggle then size64Toggle:setChecked(px == 64) end
  end

  local function applyItemSize(px)
    px = tonumber(px) or DEFAULTS.itemSize
    px = math.max(12, math.min(64, px))
    debuffhud.setItemSize(px)
    setSizePresetChecked(px)
  end

  do
    local cur = tonumber(cfgGet('itemSize') or DEFAULTS.itemSize) or DEFAULTS.itemSize
    setSizePresetChecked((cur == 26 or cur == 32 or cur == 64) and cur or 26)
  end

  if size26Toggle then
    size26Toggle.onCheckChange = function(_, chk)
      if chk then
        if size32Toggle then size32Toggle:setChecked(false) end
        if size64Toggle then size64Toggle:setChecked(false) end
        applyItemSize(26)
      elseif (not (size32Toggle and size32Toggle:isChecked())) and (not (size64Toggle and size64Toggle:isChecked())) then
        size26Toggle:setChecked(true)
      end
    end
  end
  if size32Toggle then
    size32Toggle.onCheckChange = function(_, chk)
      if chk then
        if size26Toggle then size26Toggle:setChecked(false) end
        if size64Toggle then size64Toggle:setChecked(false) end
        applyItemSize(32)
      elseif (not (size26Toggle and size26Toggle:isChecked())) and (not (size64Toggle and size64Toggle:isChecked())) then
        size32Toggle:setChecked(true)
      end
    end
  end
  if size64Toggle then
    size64Toggle.onCheckChange = function(_, chk)
      if chk then
        if size26Toggle then size26Toggle:setChecked(false) end
        if size32Toggle then size32Toggle:setChecked(false) end
        applyItemSize(64)
      elseif (not (size26Toggle and size26Toggle:isChecked())) and (not (size32Toggle and size32Toggle:isChecked())) then
        size64Toggle:setChecked(true)
      end
    end
  end

  local function getRGBFromOutfitColor(oc)
    if not oc then return 0,0,0 end
    if type(oc) == 'userdata' then
      local r = (oc.r and oc:r()) or (oc.getRed and oc:getRed())
      local g = (oc.g and oc:g()) or (oc.getGreen and oc:getGreen())
      local b = (oc.b and oc:b()) or (oc.getBlue and oc:getBlue())
      if r and g and b then return r,g,b end
    elseif type(oc) == 'table' then
      return oc.r or oc[1] or 0, oc.g or oc[2] or 0, oc.b or oc[3] or 0
    end
    return 0,0,0
  end

  if colorPanel and not colorPanel:isDestroyed() then
    for j = 0, 6 do
      for i = 0, 18 do
        local okBox, colorBox = pcall(function() return g_ui.createWidget('ColorBox', colorPanel) end)
        if okBox and colorBox then
          local oc = getOutfitColor(j * 19 + i)
          if colorBox.setImageColor then colorBox:setImageColor(oc) end
          colorBox.onClick = function()
            local r, g, b = getRGBFromOutfitColor(oc)
            local targetIsBg = not (maskModeToggle and maskModeToggle.isChecked and maskModeToggle:isChecked())
            if targetIsBg then
              local pct = (bgScr and bgScr.getValue and (tonumber(bgScr:getValue()) or 60)) or 60
              local a = math.floor(pct * 255 / 100 + 0.5)
              cfgSet('bgColor', string.format('#%02X%02X%02X%02X', r, g, b, a))
              debuffhud.applyStyle()
            else
              debuffhud.setMaskColor(string.format('#%02X%02X%02X', r, g, b))
            end
          end
        end
      end
    end
  end

  if bgScr then
    bgScr.onValueChange = function(_, value)
      local pct = tonumber(value) or 0
      local r,g,b = 0,0,0
      local hexNow = sanitizeColor(cfgGet('bgColor') or DEFAULTS.bgColor)
      if #hexNow >= 7 then
        r = tonumber(hexNow:sub(2,3),16) or 0
        g = tonumber(hexNow:sub(4,5),16) or 0
        b = tonumber(hexNow:sub(6,7),16) or 0
      end
      local a = math.floor(pct * 255 / 100 + 0.5)
      cfgSet('bgColor', string.format('#%02X%02X%02X%02X', r,g,b,a))
      if bgLbl then bgLbl:setText(string.format("Opacidade do Fundo: %d%%", pct)) end
      debuffhud.applyStyle()
    end
  end

  if maskScr then
    maskScr.onValueChange = function(_, value)
      local v = (tonumber(value) or 0) / 100
      debuffhud.setMaskOpacity(v)
      if maskLbl then maskLbl:setText(string.format("Opacidade da M?scara: %d%%", math.floor(v*100 + 0.5))) end
    end
  end

  local function setMovEnabled(enabled)
    if not window or window:isDestroyed() then return end
    setMoveBorderEnabled(enabled)
    if enabled then
      -- Temporariamente desabilitar phantom para permitir drag
      if window.setPhantom then window:setPhantom(false) end
      local h = ensureDragOverlay() or window
      attachDrag(h, window)
      movingMode = true
    else
      local h = window:recursiveGetChildById('dragOverlay') or window
      detachDrag(h)
      destroyDragOverlay()
      -- Restaurar phantom quando n?o estiver movendo
      if window.setPhantom then window:setPhantom(true) end
      savePosition(window)
      movingMode = false
    end
  end

  if moveToggle then
    local initiallyEnabled = window and window.getPhantom and (not window:getPhantom()) or false
    moveToggle:setChecked(initiallyEnabled)
    setMovEnabled(initiallyEnabled)
    moveToggle.onCheckChange = function(_, checked)
      setMovEnabled(checked and true or false)
      if not checked then
        debuffhud.applyStyle()
        updateWindowHeight()
      end
    end
  end

  if resetBtn then
    resetBtn.onClick = function()
      debuffhud.setBgColor(DEFAULTS.bgColor)
      debuffhud.setMaskOpacity(DEFAULTS.maskOpacity)
      debuffhud.setItemSize(DEFAULTS.itemSize)
      debuffhud.setSpacing(DEFAULTS.spacing)
      debuffhud.setMaskColor(DEFAULTS.maskColor)
      debuffhud.applyStyle()
      updateWindowHeight()
    end
  end

  local function cleanupCustomizer()
    savePosition(window)
    -- Restaurar phantom ao fechar customizador
    if window and not window:isDestroyed() and window.setPhantom then window:setPhantom(true) end
    setMoveBorderEnabled(false)
    movingMode = false
    if customWnd and not customWnd:isDestroyed() then customWnd:destroy() end
    customWnd = nil
  end
  if closeBtn then closeBtn.onClick = function() cleanupCustomizer() end end
  connect(g_game, { onGameEnd = function() cleanupCustomizer() end })
end

function debuffhud.setEnabled(on)
  on = asBool(on, DEFAULTS.enabled)
  cfgSet('enabled', on)

  if on then
    ensureWindow()
    debuffhud.show()
    debuffhud.applyStyle()
  else
    -- para e some
    movingMode = false
    if customWnd and not customWnd:isDestroyed() then customWnd:destroy() end
    destroyDragOverlay()
    setMoveBorderEnabled(false)
    setChildrenPassThrough(false)
    stopTimersTicker()
    clearAll()
    debuffhud.hide()
  end
end

function debuffhud.debugDuplicates()
  if not window or window:isDestroyed() then
    print("DebuffHud: Window not available")
    return
  end
  
  local list = getList()
  if not list then
    print("DebuffHud: List not available")
    return
  end
  
  local children = list:getChildren() or {}
  local ids = {}
  local duplicates = {}
  
  print("DebuffHud: Checking for duplicates...")
  print("Total children:", #children)
  
  for i, child in ipairs(children) do
    if child and not child:isDestroyed() then
      local id = child:getId()
      if ids[id] then
        table.insert(duplicates, id)
        print("Duplicate found:", id, "at positions", ids[id], "and", i)
      else
        ids[id] = i
      end
    end
  end
  
  if #duplicates == 0 then
    print("DebuffHud: No duplicates found")
  else
    print("DebuffHud: Found", #duplicates, "duplicate(s)")
  end
end

_G.debuffhud = debuffhud
