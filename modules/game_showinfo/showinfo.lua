-- ShowInfo - Raposo Standard (refactor/clean)
-- Recursos: tint BG/XP, mover janela (borda), SFX on/off (Button/Checkbox), previews, persistência por char

local GameServerOpcode = 180
local M, previewRows = {}, {}
_G.ShowInfo = M

-- === Estado/UI ===================================================
local wnd, didSetup = nil, false
local customWnd, customDragHandle, phantomBefore = nil, nil, true
local paletteActive = 'bg' -- 'bg' | 'xp'
local sfxOn = nil          -- cache do SFX

-- === Helpers de config ==========================================
local function trim(s) return s and s:match('^%s*(.-)%s*$') or '' end

local function charKeyPrefix()
  local name = (g_game and g_game.getCharacterName and g_game.getCharacterName()) or 'global'
  if name == '' then name = 'global' end
  return 'showinfo/' .. name .. '/'
end

local function cfgKey(k)       return charKeyPrefix() .. 'cfg/' .. k end
local function cfgKeyGlobal(k) return 'showinfo/global/cfg/' .. k end

local DEFAULTS = {
  enabled           = true,
  tintBgColor       = '#FFD700DD',
  tintBgOpacityPct  = 87,
  tintBgEnabled     = true,
  tintXpColor       = '#FFD700DD',
  tintXpOpacityPct  = 87,
  tintXpIconEnabled = false,
  sfxEnabled        = true,
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

local function getCfg(k, fallback)
  local v = g_settings.getValue(cfgKey(k))
  if v == nil then
    v = fallback
    if v == nil then v = DEFAULTS[k] end
  end
  return v
end

local function setCfg(k, v) g_settings.setValue(cfgKey(k), v) end
local function getCfgBool(k) return asBool(getCfg(k), DEFAULTS[k]) end

-- API: Enabled
function M.isEnabled() return asBool(getCfg('enabled'), DEFAULTS.enabled) end

-- === Util numérico ==============================================
local function clamp255(x)
  x = tonumber(x) or 0
  if x <= 1 then x = x * 255 end
  if x < 0 then x = 0 elseif x > 255 then x = 255 end
  return math.floor(x + 0.5)
end

-- === TINT (cor/alpha) ============================================
local function parseHexRGBA(hex)
  hex = tostring(hex or '')
  if hex:match('^#%x%x%x%x%x%x%x%x$') then
    return tonumber(hex:sub(2,3),16), tonumber(hex:sub(4,5),16), tonumber(hex:sub(6,7),16), tonumber(hex:sub(8,9),16)
  elseif hex:match('^#%x%x%x%x%x%x$') then
    return tonumber(hex:sub(2,3),16), tonumber(hex:sub(4,5),16), tonumber(hex:sub(6,7),16), 255
  end
  return 255,215,0,221
end

local function fmtHexRGBA(r,g,b,a)
  r, g, b, a = clamp255(r), clamp255(g), clamp255(b), clamp255(a == nil and 255 or a)
  return string.format('#%02X%02X%02X%02X', r,g,b,a)
end

local function getTintHex(kind)
  return (kind == 'xp') and getCfg('tintXpColor', DEFAULTS.tintXpColor) or getCfg('tintBgColor', DEFAULTS.tintBgColor)
end

local function getTintOpacityPct(kind)
  local k = (kind == 'xp') and 'tintXpOpacityPct' or 'tintBgOpacityPct'
  return tonumber(getCfg(k, DEFAULTS[k])) or DEFAULTS[k]
end

local function setTintRGB(kind, r, g, b)
  local a = math.floor(getTintOpacityPct(kind) * 255 / 100 + 0.5)
  setCfg(kind == 'xp' and 'tintXpColor' or 'tintBgColor', fmtHexRGBA(r,g,b,a))
end

local function setTintOpacityPct(kind, pct)
  pct = math.max(0, math.min(100, tonumber(pct) or 100))
  local r,g,b = parseHexRGBA(getTintHex(kind))
  local a     = math.floor(pct * 255 / 100 + 0.5)
  if kind == 'xp' then
    setCfg('tintXpColor', fmtHexRGBA(r,g,b,a)); setCfg('tintXpOpacityPct', pct)
  else
    setCfg('tintBgColor', fmtHexRGBA(r,g,b,a)); setCfg('tintBgOpacityPct', pct)
  end
end

local function applyImageTint(widget, hex, useOpacity)
  if not widget or not hex then return end
  local r,g,b,a = parseHexRGBA(hex)
  local rgbHex  = string.format('#%02X%02X%02X', r,g,b)
  local rgbaHex = string.format('#%02X%02X%02X%02X', r,g,b,a)
  if widget.setImageColor then
    local ok = pcall(function() widget:setImageColor(rgbaHex) end)
    if not ok then pcall(function() widget:setImageColor(rgbHex) end) end
  end
  if useOpacity and widget.setOpacity then widget:setOpacity(math.max(0, math.min(1, a / 255))) end
end

local function clearImageTint(widget, resetOpacity)
  if not widget then return end
  if widget.setImageColor then pcall(function() widget:setImageColor('#FFFFFFFF') end) end
  if resetOpacity and widget.setOpacity then widget:setOpacity(1) end
end

-- === Posição janela =============================================
local function currentPrefix()
  local name = (g_game and g_game.getCharacterName and g_game.getCharacterName()) or ''
  if not name or name == '' then name = 'global' end
  return 'showinfo/' .. name .. '/'
end

local function hasSavedPosFor(prefix)
  prefix = tostring(prefix or currentPrefix())
  local px = tonumber(g_settings.getValue(prefix .. 'posx'))
  local py = tonumber(g_settings.getValue(prefix .. 'posy'))
  return (px ~= nil and py ~= nil), px, py
end

local function hasSavedPosChar()
  local name = (g_game and g_game.getCharacterName and g_game.getCharacterName()) or ''
  if not name or name == '' then return false end
  return hasSavedPosFor('showinfo/' .. name .. '/')
end

local function hasSavedPosGlobal()
  return hasSavedPosFor('showinfo/global/')
end

local function savePos(w)
  if not w or w:isDestroyed() then return end
  local p = w:getPosition()
  if p and type(p.x) == 'number' and type(p.y) == 'number' then
    local base = currentPrefix()
    g_settings.setValue(base .. 'posx', p.x)
    g_settings.setValue(base .. 'posy', p.y)
    if g_settings.save then pcall(function() g_settings.save() end)
    elseif g_settings.sync then pcall(function() g_settings.sync() end) end
  end
end

-- Pré-login: aplica GLOBAL se existir; não grava caso não exista
local function restorePosGlobalIfExists(w)
  if not w or w:isDestroyed() then return end
  local okG, gx, gy = hasSavedPosGlobal()
  local function doRestore()
    if not w or w:isDestroyed() then return end
    if w.breakAnchors then w:breakAnchors() end
    if okG then w:setPosition({ x = gx, y = gy }) end
  end
  scheduleEvent(doRestore, 1)
  scheduleEvent(doRestore, 300)
end

-- Pós-login: prefere CHAR; se não houver, migra do GLOBAL para CHAR; senão não altera
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
      savePos(w) -- grava no prefixo do CHAR
    end
  end
  scheduleEvent(doRestore, 1)
  scheduleEvent(doRestore, 300)
end

-- === Exclusividade BG/XP ========================================
local function enforceExclusiveFlags(prefer)
  local bg, xp = getCfgBool('tintBgEnabled'), getCfgBool('tintXpIconEnabled')
  if bg and xp then
    local pick = prefer or 'bg'
    if pick == 'xp' then setCfg('tintBgEnabled', false) else setCfg('tintXpIconEnabled', false) end
    return pick
  end
  if not bg and not xp then
    local pick = prefer or 'bg'
    if pick == 'xp' then setCfg('tintXpIconEnabled', true) else setCfg('tintBgEnabled', true) end
    return pick
  end
  return bg and 'bg' or 'xp'
end

-- === Janela/Base ===============================================
local function ensureWindow()
  if not M.isEnabled() then return nil end
  local parent = (modules.game_interface and modules.game_interface.getRootPanel and modules.game_interface:getRootPanel()) or rootWidget

  local createdNow = false
  if not wnd or wnd:isDestroyed() then
    local ok, w = pcall(function() return g_ui.loadUI('showinfo', parent) end)
    if ok and w then
      wnd, didSetup = w, false
      createdNow = true
      if wnd.breakAnchors then pcall(function() wnd:breakAnchors() end) end
      -- Configurar como phantom por padrão para não interferir com outros sistemas
      if wnd.setPhantom then wnd:setPhantom(true) end
    end
    if wnd and not wnd._posHooked then
      wnd._posHooked = true
      wnd.onPositionChange = function(_) savePos(wnd) end
    end
  end

  if wnd and not didSetup and type(wnd.setup) == 'function' then
    wnd:setup(); didSetup = true
  end
  if not wnd then return nil end

  M.applyStyle()
  if createdNow then restorePosGlobalIfExists(wnd) end
  return wnd
end

local function getInfoPanel() return wnd and (wnd:recursiveGetChildById('infoPanel') or wnd) or nil end

-- === Movimento (drag + borda) ===================================
local dragging, dragOffset = false, {x=0,y=0}

local function attachDrag(handle, target)
  if not (handle and target) then return end
  handle.onMousePress = function(_, pos, button)
    if button ~= MouseLeftButton then return false end
    dragging = true
    local p = target:getPosition()
    dragOffset.x, dragOffset.y = pos.x - p.x, pos.y - p.y
    return true
  end
  handle.onMouseMove = function(_, pos)
    if not dragging then return false end
    target:setPosition({x=pos.x - dragOffset.x, y=pos.y - dragOffset.y})
    return true
  end
  handle.onMouseRelease = function()
    if not dragging then return false end
    dragging = false
    savePos(target)
    return true
  end
end

local function detachDrag(handle)
  if not handle then return end
  handle.onMousePress, handle.onMouseMove, handle.onMouseRelease = nil,nil,nil
  dragging = false
end

local function setMoveBorderEnabled(enabled)
  if not wnd or wnd:isDestroyed() then return end
  local parent = wnd:recursiveGetChildById('contentsPanel') or wnd
  if not parent then return end
  local function mk(id, side)
    local w = parent:recursiveGetChildById(id)
    if w and not w:isDestroyed() then return w end
    w = g_ui.createWidget('UIWidget', parent)
    w:setId(id)
    w:setBackgroundColor('#FFD700CC')
    w:raise()
    -- Garantir que as bordas sejam phantom para não interferir com cliques
    if w.setPhantom then w:setPhantom(true) end
    if side == 'top' then
      w:addAnchor(AnchorTop,'parent',AnchorTop); w:addAnchor(AnchorLeft,'parent',AnchorLeft); w:addAnchor(AnchorRight,'parent',AnchorRight); w:setHeight(2)
    elseif side == 'bottom' then
      w:addAnchor(AnchorBottom,'parent',AnchorBottom); w:addAnchor(AnchorLeft,'parent',AnchorLeft); w:addAnchor(AnchorRight,'parent',AnchorRight); w:setHeight(2)
    elseif side == 'left' then
      w:addAnchor(AnchorTop,'parent',AnchorTop); w:addAnchor(AnchorBottom,'parent',AnchorBottom); w:addAnchor(AnchorLeft,'parent',AnchorLeft); w:setWidth(2)
    else
      w:addAnchor(AnchorTop,'parent',AnchorTop); w:addAnchor(AnchorBottom,'parent',AnchorBottom); w:addAnchor(AnchorRight,'parent',AnchorRight); w:setWidth(2)
    end
    return w
  end
  local ids = {'goldBorderTop','goldBorderBottom','goldBorderLeft','goldBorderRight'}
  if enabled then
    mk(ids[1],'top'); mk(ids[2],'bottom'); mk(ids[3],'left'); mk(ids[4],'right')
  else
    for _, id in ipairs(ids) do
      local w = parent:recursiveGetChildById(id)
      if w and not w:isDestroyed() then w:destroy() end
    end
  end
end

-- === Pintura por linha ==========================================
local function tintRow(row)
  if not row or row:isDestroyed() then return end
  local bgOn, xpOn = getCfgBool('tintBgEnabled'), getCfgBool('tintXpIconEnabled')

  if bgOn then applyImageTint(row, getTintHex('bg'), false) else clearImageTint(row, false) end

  local icon = row:recursiveGetChildById('iconImage')
  if icon then
    if xpOn then
      applyImageTint(icon, getTintHex('xp'), true)
      local pct = getTintOpacityPct('xp')
      if icon.setOpacity then icon:setOpacity(math.max(0, math.min(1, pct/100))) end
    else
      clearImageTint(icon, true)
    end
  end
end

local function retintAllRows()
  local p = getInfoPanel(); if not p then return end
  for _, ch in ipairs(p:getChildren() or {}) do
    if ch and not ch:isDestroyed() then tintRow(ch) end
  end
end

-- === Estilo (UI label/slider) ===================================
function M.applyStyle()
  retintAllRows()
  local lbl = customWnd and customWnd:recursiveGetChildById('bgOpacityLabel')
  if lbl then lbl:setText(string.format('Opacidade do Tint (%s): %d%%', paletteActive:upper(), getTintOpacityPct(paletteActive))) end
end

-- === Previews ====================================================
local function destroyPreviewRows()
  local p = getInfoPanel(); if not p then return end
  for _, w in ipairs(previewRows) do if w and not w:isDestroyed() then w:destroy() end end
  previewRows = {}
end

local function trySetItemIdSafe(itemWidget, ids)
  if not itemWidget then return end
  for _, id in ipairs(ids or {}) do
    local ok = pcall(function() itemWidget:setItemId(id) end)
    if ok then return end
  end
end

local function createPreviewRows()
  destroyPreviewRows()
  local p = getInfoPanel(); if not p then return end

  local expRow = g_ui.createWidget('ExpWidgetInfo', p)
  expRow.isPreview = true
  local lbl = expRow.labelExp or expRow:recursiveGetChildById('labelExp'); if lbl then lbl:setText('+12345 experience') end
  tintRow(expRow); table.insert(previewRows, expRow)

  local itemRow = g_ui.createWidget('ItemWidgetInfo', p)
  itemRow.isPreview = true
  local iw = itemRow.itemWidget or itemRow:recursiveGetChildById('itemWidget')
  local nameLbl = itemRow.itemName or itemRow:recursiveGetChildById('itemName')
  if nameLbl then nameLbl:setText('1x Example Item') end
  if iw then trySetItemIdSafe(iw, {2148,2160,3031}) end
  tintRow(itemRow); table.insert(previewRows, itemRow)

  for i = #previewRows, 1, -1 do
    local w = previewRows[i]
    if w and p.lowerChild then p:lowerChild(w) end
  end
end

-- === SFX =========================================================
local function stopAllSoundNow()
  if not g_sounds then return end
  if g_sounds.stopAll then pcall(function() g_sounds.stopAll() end) end
  if g_sounds.getChannel then
    for i = 0, 15 do
      local ch = g_sounds.getChannel(i)
      if ch then
        pcall(function() if ch.clearQueue then ch:clearQueue() end end)
        pcall(function() ch:stop() end)
      end
    end
  end
end

local function getSfxFlagFromSettings()
  local v = g_settings.getValue(cfgKey('sfxEnabled'))
  if v == nil then v = g_settings.getValue(cfgKeyGlobal('sfxEnabled')) end
  if v == nil then v = DEFAULTS.sfxEnabled end
  return asBool(v, DEFAULTS.sfxEnabled)
end

function M.isSfxEnabled() if sfxOn == nil then sfxOn = getSfxFlagFromSettings() end; return sfxOn end

function M.setSfxEnabled(on)
  on = asBool(on, DEFAULTS.sfxEnabled); sfxOn = on
  setCfg('sfxEnabled', on); g_settings.setValue(cfgKeyGlobal('sfxEnabled'), on)
  if not on then stopAllSoundNow() end
end

local function playUISound(filename)
  if not M.isSfxEnabled() then return nil end
  if not g_sounds or not g_sounds.getChannel then return nil end
  local ch = g_sounds.getChannel(2); if not ch then return nil end
  pcall(function() if ch.setGain   then ch:setGain(1)   end end)
  pcall(function() if ch.setVolume then ch:setVolume(1) end end)
  local candidates = { '/sounds/'..filename, '/music/'..filename, '/'..filename }
  for _, p in ipairs(candidates) do
    if g_resources.fileExists(p) then
      if not M.isSfxEnabled() then return nil end
      pcall(function() if ch.clearQueue then ch:clearQueue() end; ch:stop() end)
      ch:enqueue(p, 1)
      return ch
    end
  end
  return nil
end

local function restoreChannelLevels()
  if not g_sounds or not g_sounds.getChannel then return end
  for i = 0, 15 do
    local ch = g_sounds.getChannel(i)
    if ch then
      pcall(function() if ch.setGain   then ch:setGain(1)   end end)
      pcall(function() if ch.setVolume then ch:setVolume(1) end end)
    end
  end
end

-- === Customizador ===============================================
function M.customize()
  ensureWindow(); if not wnd then return end
  if customWnd and not customWnd:isDestroyed() then customWnd:raise(); customWnd:focus(); return end

  local ok, w = pcall(function() return g_ui.createWidget('ShowInfoCustomizer', rootWidget) end)
  if not ok or not w then return end
  customWnd = w
  if wnd.getPhantom then phantomBefore = wnd:getPhantom() end

  local moveToggle       = customWnd:recursiveGetChildById('moveToggle')
  local opScroll         = customWnd:recursiveGetChildById('bgOpacityScroll')
  local opLabel          = customWnd:recursiveGetChildById('bgOpacityLabel')
  local colorPanel       = customWnd:recursiveGetChildById('colorBoxPanel')
  local resetBtn         = customWnd:recursiveGetChildById('resetBtn')
  local closeBtn         = customWnd:recursiveGetChildById('closeBtn')
  local paletteBgToggle  = customWnd:recursiveGetChildById('paletteBgToggle')
  local paletteXpToggle  = customWnd:recursiveGetChildById('paletteXpToggle')
  local soundButton      = customWnd:recursiveGetChildById('soundButton')
  local legacySoundToggle= customWnd:recursiveGetChildById('soundToggle')
  local contentsHandle   = wnd:recursiveGetChildById('contentsPanel') or wnd
  local syncing          = false

  local function setMovEnabled(enabled)
    if not wnd or wnd:isDestroyed() then return end
    setMoveBorderEnabled(enabled)
    if enabled then
      -- Temporariamente desabilitar phantom para permitir drag
      if wnd.setPhantom then wnd:setPhantom(false) end
      attachDrag(contentsHandle, wnd); customDragHandle = contentsHandle
    else
      if customDragHandle then detachDrag(customDragHandle); customDragHandle = nil end
      -- Restaurar phantom quando não estiver movendo
      if wnd.setPhantom then wnd:setPhantom(true) end
      savePos(wnd)
    end
  end

  if moveToggle then
    moveToggle:setChecked(wnd.getPhantom and (not wnd:getPhantom()) or false)
    setMovEnabled(moveToggle:isChecked())
    moveToggle.onCheckChange = function(_, checked) setMovEnabled(checked and true or false) end
  end

  local function refreshSoundButton()
    if soundButton then soundButton:setText(M.isSfxEnabled() and 'Disable Sound' or 'Enable Sound') end
  end
  if soundButton then
    refreshSoundButton()
    soundButton.onClick = function() M.setSfxEnabled(not M.isSfxEnabled()); refreshSoundButton() end
  elseif legacySoundToggle then
    syncing = true; legacySoundToggle:setChecked(M.isSfxEnabled()); syncing = false
    legacySoundToggle.onCheckChange = function(_, checked) if not syncing then M.setSfxEnabled(checked) end end
  end

  local function setExclusive(kind, fromUser)
    syncing = true
    if kind == 'xp' then
      setCfg('tintBgEnabled', false); setCfg('tintXpIconEnabled', true)
      if paletteBgToggle then paletteBgToggle:setChecked(false) end
      if paletteXpToggle then paletteXpToggle:setChecked(true)  end
      paletteActive = 'xp'
    else
      setCfg('tintBgEnabled', true); setCfg('tintXpIconEnabled', false)
      if paletteBgToggle then paletteBgToggle:setChecked(true)  end
      if paletteXpToggle then paletteXpToggle:setChecked(false) end
      paletteActive = 'bg'
    end
    if opScroll then opScroll:setValue(getTintOpacityPct(paletteActive)) end
    syncing = false
    if opLabel then opLabel:setText(string.format('Opacidade do Tint (%s): %d%%', paletteActive:upper(), getTintOpacityPct(paletteActive))) end
    if not fromUser then M.applyStyle() end
  end

  setExclusive(enforceExclusiveFlags(paletteActive), false)

  if paletteBgToggle then
    paletteBgToggle.onCheckChange = function(_, checked)
      if checked then setExclusive('bg', true) else if not getCfgBool('tintXpIconEnabled') then setExclusive('bg', true) end end
      M.applyStyle()
    end
  end
  if paletteXpToggle then
    paletteXpToggle.onCheckChange = function(_, checked)
      if checked then setExclusive('xp', true) else if not getCfgBool('tintBgEnabled') then setExclusive('xp', true) end end
      M.applyStyle()
    end
  end

  if opScroll then
    opScroll:setValue(getTintOpacityPct(paletteActive))
    opScroll.onValueChange = function(_, value)
      setTintOpacityPct(paletteActive, value)
      if opLabel then opLabel:setText(string.format('Opacidade do Tint (%s): %d%%', paletteActive:upper(), tonumber(value) or 0)) end
      M.applyStyle()
    end
    createPreviewRows()
  end

  local function getRGBFromOutfitColorSafe(oc)
    if not oc then return 255,215,0 end
    local t = type(oc)
    if t == 'userdata' then
      local r = (oc.r and type(oc.r) == 'function' and oc:r()) or (oc.getRed and oc:getRed()) or (oc.red and type(oc.red) == 'function' and oc:red())
      local g = (oc.g and type(oc.g) == 'function' and oc:g()) or (oc.getGreen and oc:getGreen()) or (oc.green and type(oc.green) == 'function' and oc:green())
      local b = (oc.b and type(oc.b) == 'function' and oc:b()) or (oc.getBlue and oc:getBlue()) or (oc.blue and type(oc.blue) == 'function' and oc:blue())
      return r or 255, g or 215, b or 0
    elseif t == 'table' then
      return oc.r or oc[1] or oc.x or 255, oc.g or oc[2] or oc.y or 215, oc.b or oc[3] or oc.z or 0
    end
    return 255,215,0
  end

  if colorPanel and not colorPanel:isDestroyed() then
    for j = 0, 6 do
      for i = 0, 18 do
        local okBox, box = pcall(function() return g_ui.createWidget('ColorBox', colorPanel) end)
        if okBox and box then
          local oc = getOutfitColor(j*19 + i)
          if box.setImageColor then box:setImageColor(oc) end
          box.onClick = function() local r,g,b = getRGBFromOutfitColorSafe(oc); setTintRGB(paletteActive, r,g,b); M.applyStyle() end
        end
      end
    end
  end

  if resetBtn then
    resetBtn.onClick = function()
      setCfg('tintBgColor', DEFAULTS.tintBgColor); setCfg('tintXpColor', DEFAULTS.tintXpColor)
      setCfg('tintBgOpacityPct', DEFAULTS.tintBgOpacityPct); setCfg('tintXpOpacityPct', DEFAULTS.tintXpOpacityPct)
      setExclusive('bg', false); M.applyStyle()
    end
  end

  local function cleanup()
    destroyPreviewRows()
    if customDragHandle then detachDrag(customDragHandle); customDragHandle = nil end
    setMoveBorderEnabled(false)
    -- Restaurar phantom ao fechar customizador
    if wnd and wnd.setPhantom then wnd:setPhantom(true) end
    if customWnd and not customWnd:isDestroyed() then customWnd:destroy() end
    customWnd = nil
  end

  if closeBtn then closeBtn.onClick = cleanup end
  connect(g_game, { onGameEnd = cleanup })
end

-- === Protocolo ===============================================
local function createWidgetSafe(templateName, parent)
  local ok, widget = pcall(function() return g_ui.createWidget(templateName, parent) end)
  if ok and widget then return widget, nil end
  local pnl = g_ui.createWidget('UIWidget', parent); pnl:setHeight(24)
  local lbl = g_ui.createWidget('UILabel', pnl); lbl:addAnchor(AnchorLeft,'parent',AnchorLeft); lbl:addAnchor(AnchorVerticalCenter,'parent',AnchorVerticalCenter)
  return pnl, lbl
end

local function onReceiveServerInfo(_, _, payload)
  if not M.isEnabled() then return end
  if not wnd or not wnd:isVisible() then return end
  local parts, infoPanel = payload:split('@'), getInfoPanel(); if not infoPanel then return end
  local messageType = trim(parts[1] or '')

  if messageType == 'SendExperience' then
    local exp = math.floor(tonumber(parts[2]) or 0)
    local row, fallback = createWidgetSafe('ExpWidgetInfo', infoPanel); row.index = infoPanel:getChildIndex(row)
    if fallback then
      fallback:setText('+'..exp..' experience')
    else
      local lbl = row.labelExp or row:recursiveGetChildById('labelExp')
      if lbl and lbl.setColoredText and getNewHighlightedText then
        local h = getNewHighlightedText('Experience {+'..exp..'#DC9C50}', 'white', '#ffffff')
        if #h > 2 then lbl:setColoredText(h) else lbl:setText('+'..exp..' experience') end
      else
        (lbl or g_ui.createWidget('UILabel', row)):setText('+'..exp..' experience')
      end
    end
    tintRow(row)
    scheduleEvent(function() g_effects.fadeOut(row, 400) end, 2200)
    row.event = scheduleEvent(function() if row and not row:isDestroyed() then row:destroy() end end, 2800 + row.index * 100)

  elseif messageType == 'SendItemLoot' then
    local items, i = {}, 2
    while (i + 2) <= #parts do
      local clientId = tonumber(parts[i]); local itemName = trim(parts[i + 1]); local qty = math.floor(tonumber(parts[i + 2]) or 0)
      if clientId and clientId > 0 and itemName ~= '' and itemName ~= 'nil' and qty > 0 then items[#items+1] = { id=clientId, name=itemName, qty=qty } end
      i = i + 3
    end
    for _, it in ipairs(items) do
      local ch = playUISound('coins.ogg'); if ch then scheduleEvent(function() ch:stop() end, 800) end
      local row, fallback = createWidgetSafe('ItemWidgetInfo', infoPanel); row.index = infoPanel:getChildIndex(row)
      if fallback then
        fallback:setText(('%dx %s'):format(it.qty, it.name))
      else
        local iw = row.itemWidget or row:recursiveGetChildById('itemWidget'); if iw and it.id then iw:setItemId(it.id) end
        local lbl = row.itemName or row:recursiveGetChildById('itemName'); if lbl then lbl:setText(('%dx %s'):format(it.qty, it.name)) end
      end
      tintRow(row)
      scheduleEvent(function() g_effects.fadeOut(row, 400) end, 2200)
      row.event = scheduleEvent(function() if row and not row:isDestroyed() then row:destroy() end end, 2800 + row.index * 100)
    end
  end
end

-- === Core enable/disable =======================================
local initialized, connected = false, false

local function onGameStartHandler()
  ensureWindow()
  if wnd then
    restorePosCharWithFallback(wnd) -- aplica por CHAR, migra do GLOBAL se necessário
    wnd:show()
    M.applyStyle()
  end
end

local function onGameEndHandler()
  if customWnd and not customWnd:isDestroyed() then customWnd:destroy() end
  if g_settings.save then pcall(function() g_settings.save() end)
  elseif g_settings.sync then pcall(function() g_settings.sync() end) end
end

local function enableCore()
  if initialized then return end
  ensureWindow(); paletteActive = enforceExclusiveFlags(paletteActive)
  restoreChannelLevels()
  ProtocolGame.registerExtendedOpcode(GameServerOpcode, onReceiveServerInfo)
  connect(g_game, { onGameStart = onGameStartHandler, onGameEnd = onGameEndHandler })
  connected, initialized = true, true
end

local function disableCore()
  pcall(function() ProtocolGame.unregisterExtendedOpcode(GameServerOpcode) end)
  if connected then
    pcall(function() disconnect(g_game, 'onGameStart', onGameStartHandler) end)
    pcall(function() disconnect(g_game, 'onGameEnd', onGameEndHandler) end)
    connected = false
  end
  destroyPreviewRows()
  if customWnd and not customWnd:isDestroyed() then customWnd:destroy() end
  if wnd then wnd:hide() end
  stopAllSoundNow()
  if g_settings.save then pcall(function() g_settings.save() end)
  elseif g_settings.sync then pcall(function() g_settings.sync() end) end
  initialized = false
end

function M.setEnabled(on)
  on = asBool(on, DEFAULTS.enabled); setCfg('enabled', on)
  if on then
    sfxOn = getSfxFlagFromSettings()
    enableCore(); if wnd then wnd:show() end
  else
    disableCore()
  end
end

-- === API pública janela ========================================
function M.toggle(show) if not wnd then return end; if show then wnd:show() else wnd:hide() end end
function M.show() ensureWindow(); if not wnd then return end; wnd:show(); wnd:raise(); wnd:focus() end
function M.hide() if wnd then wnd:hide() end end

-- === Ciclo de vida =============================================
local function migrateOldTint()
  local old  = g_settings.getValue(cfgKey('tintColor'))
  local oldP = g_settings.getValue(cfgKey('tintOpacityPct'))
  if old and not g_settings.getValue(cfgKey('tintBgColor')) then g_settings.setValue(cfgKey('tintBgColor'), old) end
  if old and not g_settings.getValue(cfgKey('tintXpColor')) then g_settings.setValue(cfgKey('tintXpColor'), old) end
  if oldP and not g_settings.getValue(cfgKey('tintBgOpacityPct')) then g_settings.setValue(cfgKey('tintBgOpacityPct'), oldP) end
  if oldP and not g_settings.getValue(cfgKey('tintXpOpacityPct')) then g_settings.setValue(cfgKey('tintXpOpacityPct'), oldP) end
end

function init()
  migrateOldTint()
  do
    local perChar = g_settings.getValue(cfgKey('sfxEnabled'))
    local globalV = g_settings.getValue(cfgKeyGlobal('sfxEnabled'))
    if perChar == nil and globalV ~= nil then g_settings.setValue(cfgKey('sfxEnabled'), globalV) end
  end
  sfxOn = getSfxFlagFromSettings()
  if M.isEnabled() then enableCore() end
end

function terminate() disableCore() end
