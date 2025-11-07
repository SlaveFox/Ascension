-- PvP Module ? Raposo Standard (server-driven modes + invites + fixes)
-- Otimizado e com confirmação usando confirmArenaWindow

--------------------------------------------------------------------------------
-- Namespace / Estado (público)
--------------------------------------------------------------------------------
pvp = rawget(_G, 'pvp') or {}
_G.pvp = pvp

-- Config de rede
pvp.OPCODE          = 231
pvp._usingProtoHook = false

-- Estado base
pvp.state     = pvp.state or { pvpType = '1x1' }
pvp.history   = pvp.history or {}
pvp._updating = false

-- Espera/"Buscando" por slot
pvp._waiting = pvp._waiting or { timers = {}, state = {} }

-- MODOS controlados pelo servidor
pvp._modes         = pvp._modes or nil   -- [{value,text,enabled}]
pvp._modesBuilt    = false
pvp._canSelectMode = true                -- servidor pode setar false (convidados)

-- Convites
pvp._inviteQueue    = pvp._inviteQueue or {}
pvp._inviteMap      = pvp._inviteMap or {}
pvp._activeInviteId = nil
pvp._askDlg         = nil

-- Dedupe de payload / estado servidor
pvp._lastModesSig   = pvp._lastModesSig or nil
pvp._rxBusy         = false
pvp._hasServerLobby = pvp._hasServerLobby or false

-- Slots (estado lógico) ? apenas name + lookType (int)
pvp.slots = pvp.slots or {
  slotA1 = { name = '', lookType = nil },
  slotA2 = { name = '', lookType = nil },
  slotB1 = { name = '', lookType = nil },
  slotB2 = { name = '', lookType = nil },
}

-- Refs de UI
pvp._uiRefs = pvp._uiRefs or {}
pvp._debouncers = pvp._debouncers or {}
pvp._localPlayerLookType = nil  -- LookType do jogador local (vindo do servidor)

-- Cache para melhor performance
pvp._cache = pvp._cache or {
  playerName = nil,
  isLeader = nil,
  isPartner = nil,
  lastUpdate = 0
}

-- Sistema de fila de matchmaking
pvp._queue = pvp._queue or {
  inQueue = false,
  queue = nil,
  mode = nil,
  startTime = 0,
  timer = nil,
  window = nil
}

--------------------------------------------------------------------------------
-- Locais (privados do módulo)
--------------------------------------------------------------------------------
local window, historyWin, rankingWin, playerInfoWin = nil, nil, nil, nil

-- Constantes de UI/Layout
local HOTKEY = 'Ctrl+Shift+P'
local HIST_ROW_H, HIST_ROW_SP, HIST_MIN_W = 48, 4, 560
local RANK_ROW_H, RANK_ROW_SP, RANK_MIN_W = 44, 4, 560
local ROW_HEIGHT, ROW_SPACING = 30, 6
local COLOR_SELECTED, COLOR_NORMAL = '#E7D59A', '#666666'
local WAVE_FRAMES = { '?..', '.?.', '..?', '.?.' }
local WAVE_MS     = 350

-- Espelhamento permitido p/ 1x1 (meu slot ? slot do oponente)
local MIRROR = { slotA1='slotB2', slotA2='slotB1', slotB1='slotA2', slotB2='slotA1' }
local FALLBACK_MODES = {
  { value='1x1',     text='1x1',      enabled=true  },
  { value='2x2',     text='2x2',      enabled=true  },
  { value='lure1x1', text='Lure 1x1', enabled=true  },
  { value='lure2x2', text='Lure 2x2', enabled=true  },
}

--------------------------------------------------------------------------------
-- Declarações antecipadas
--------------------------------------------------------------------------------
local ensureWindow, applyModeSlotRules, refreshWaiting, buildPvpTypeRowsFrom
local updateModeDependentControls, applySlotToUi, applyBetState

--------------------------------------------------------------------------------
-- Utils otimizados
--------------------------------------------------------------------------------
local function strtrim(s) return (s or ''):gsub('^%s+',''):gsub('%s+$','') end
local function _norm(s)   return (s or ''):lower():gsub('^%s+',''):gsub('%s+$','') end
-- Função toast silenciosa (removido print para otimização)
local function toast(msg) 
  -- Notificações podem ser adicionadas aqui se necessário
  -- Por enquanto, mantém silencioso para melhor performance
end

-- Cache para evitar recálculos desnecessários
local CACHE_TTL = 1000 -- 1 segundo
local function getCachedPlayerName()
  local now = os.time() * 1000
  if not pvp._cache.playerName or (now - pvp._cache.lastUpdate) > CACHE_TTL then
    pvp._cache.playerName = (g_game.getCharacterName and g_game.getCharacterName()) or 'Player'
    pvp._cache.lastUpdate = now
  end
  return pvp._cache.playerName
end

-- Debounce util otimizado (per id)
local function debounceCall(id, ms, fn)
  if not id or not fn then return end
  local pending = pvp._debouncers[id]
  if pending and removeEvent then removeEvent(pending) end
  local function run() pvp._debouncers[id] = nil; fn() end
  if scheduleEvent then
    pvp._debouncers[id] = scheduleEvent(run, tonumber(ms) or 120)
  else
    run()
  end
end

-- Formatação otimizada
local function fmtThousandsBR(n)
  local s = tostring(math.floor(tonumber(n) or 0))
  local r = s:reverse():gsub('(%d%d%d)', '%1.'):reverse()
  return (r:sub(1,1)=='.' and r:sub(2) or r)
end

local function fmtWhen(ts)
  local t = os.date('*t', ts or os.time())
  return string.format('%02d/%02d %02d:%02d', t.day, t.month, t.hour, t.min)
end

local function fmtDuration(sec)
  sec = math.floor(tonumber(sec) or 0)
  local m = math.floor(sec/60); local s = sec%60
  return string.format('%dm%02ds', m, s)
end

-- Cache para modos
local modeCache = {}
local function modeNice(m)
  if not modeCache[m] then
    modeCache[m] = (m=='1x1' and '1x1')
        or (m=='2x2' and '2x2')
        or (m=='lure1x1' and 'Lure 1x1')
        or (m=='lure2x2' and 'Lure 2x2')
        or (m or '?')
  end
  return modeCache[m]
end

local function queueNice(q) return (q=='ranked' and 'Ranked') or 'Casual' end

local function getComboText(cb)
  if not cb then return 'Todos' end
  if cb.getCurrentOption and cb:getCurrentOption() and cb:getCurrentOption().text then
    return cb:getCurrentOption().text
  end
  if cb.getText then return cb:getText() end
  return 'Todos'
end

local function setRowBorderColor(row, color)
  if not row then return end
  if row.setBorderColor then row:setBorderColor(color); return end
  if row.setBorderColorTop    then row:setBorderColorTop(color)    end
  if row.setBorderColorLeft   then row:setBorderColorLeft(color)   end
  if row.setBorderColorRight  then row:setBorderColorRight(color)  end
  if row.setBorderColorBottom then row:setBorderColorBottom(color) end
end

-- helpers de identidade/liderança otimizados com cache
local function myName()
  return getCachedPlayerName()
end

local function iAmLeader()
  local now = os.time() * 1000
  if not pvp._cache.isLeader or (now - pvp._cache.lastUpdate) > CACHE_TTL then
    pvp._cache.isLeader = _norm(pvp.slots.slotA1 and pvp.slots.slotA1.name or '') == _norm(myName())
    pvp._cache.lastUpdate = now
  end
  return pvp._cache.isLeader
end

local function iAmPartner()
  if iAmLeader() then return false end
  local now = os.time() * 1000
  if not pvp._cache.isPartner or (now - pvp._cache.lastUpdate) > CACHE_TTL then
    pvp._cache.isPartner = _norm(pvp.slots.slotA2 and pvp.slots.slotA2.name or '') == _norm(myName())
    pvp._cache.lastUpdate = now
  end
  return pvp._cache.isPartner
end

--------------------------------------------------------------------------------
-- Net helpers (ExtendedOpcode) otimizados
--------------------------------------------------------------------------------
local function pvpSend(tbl)
  if not g_game or not g_game.isOnline or not g_game:isOnline() then return false end
  local proto = g_game.getProtocolGame and g_game.getProtocolGame() or nil
  if not proto or not proto.sendExtendedOpcode then return false end
  
  -- Validação rápida antes de serializar
  if not tbl or type(tbl) ~= 'table' then return false end
  
  local ok, buf = pcall(json.encode, tbl)
  if not ok then 
    toast('Erro ao serializar dados: ' .. tostring(buf))
    return false 
  end
  
  proto:sendExtendedOpcode(pvp.OPCODE, buf)
  return true
end

--------------------------------------------------------------------------------
-- UI: raiz e helpers
--------------------------------------------------------------------------------
function ensureWindow()
  if window and not window:isDestroyed() then return window end
  window = g_ui.displayUI('pvp')
  if not window then return nil end
  if window.show and window.hide then window:hide() end

  pvp._uiRefs.invitePartnerBtn  = window:recursiveGetChildById('inviteButton')
  pvp._uiRefs.inviteEnemyButton = window:recursiveGetChildById('inviteEnemyButton')
  pvp._uiRefs.historyButton     = window:recursiveGetChildById('historyButton')
  pvp._uiRefs.rankingButton     = window:recursiveGetChildById('rankingButton')
  pvp._uiRefs.playerInfoButton  = window:recursiveGetChildById('playerInfoButton')
  pvp._uiRefs.pvpTypeMainPanel  = window:recursiveGetChildById('pvpTypeMainPanel')
  
  return window
end

local function setPlayerAvatar()
  local w = ensureWindow()
  if not w then return end
  
  local view = w:recursiveGetChildById('playerView')
  local name = w:recursiveGetChildById('playerName')
  local cn   = getCachedPlayerName()
  
  if name then name:setText(cn) end
  if not view then return end
  
  -- Prioridade: servidor > slots > LocalPlayer > padrão
  local lookType = pvp._localPlayerLookType
  
  if not lookType then
    local me = cn:lower()
    for _, slotId in ipairs({'slotA1', 'slotA2', 'slotB1', 'slotB2'}) do
      local slot = pvp.slots[slotId]
      if slot and slot.name and slot.name:lower() == me and slot.lookType then
        lookType = slot.lookType
        break
      end
    end
  end
  
  if not lookType then
    local lp = g_game.getLocalPlayer()
    if lp and lp.getOutfit then
      local outfit = lp:getOutfit()
      if outfit and outfit.type then
        lookType = outfit.type
      end
    end
  end
  
  view:setOutfit({ type = lookType or 128 })
  view:setVisible(true)
end

-- === PvP Match Timer ===
pvp._timer = pvp._timer or { dlg=nil, ev=nil, endsAt=0 }

local function ensureTimerWindow()
  if pvp._timer.dlg and not pvp._timer.dlg:isDestroyed() then return pvp._timer.dlg end
  local root = g_ui.getRootWidget(); if not root then return nil end
  local dlg = g_ui.createWidget('PvPTimerWindow', root)
  dlg:hide()
  pvp._timer.dlg = dlg
  return dlg
end

local function _fmtMMSS(secs)
  secs = math.max(0, math.floor(tonumber(secs) or 0))
  local m = math.floor(secs/60)
  local s = secs % 60
  return string.format('%02d:%02d', m, s)
end

local function _tickTimer()
  local dlg = pvp._timer.dlg; if not dlg or dlg:isDestroyed() then return end
  local remain = (pvp._timer.endsAt or 0) - os.time()
  local lab = dlg:recursiveGetChildById('timerLabel')
  if remain <= 0 then
    if lab then lab:setText('Tempo Restante: 00:00') end
    -- tempo esgotado: esconder e avisar. (teleporte volta pelo servidor)
    pvp._stopMatchTimer(true)
    return
  end
  if lab then lab:setText('Tempo Restante: ' .. _fmtMMSS(remain)) end
end

function pvp._startMatchTimer(durationOrEndsAt, isEndsAt)
  local dlg = ensureTimerWindow(); if not dlg then return end
  if isEndsAt then
    pvp._timer.endsAt = math.floor(tonumber(durationOrEndsAt) or os.time())
  else
    pvp._timer.endsAt = os.time() + math.max(0, math.floor(tonumber(durationOrEndsAt) or 0))
  end

  dlg:show(); dlg:raise(); dlg:focus()
  _tickTimer()

  if pvp._timer.ev and removeEvent then removeEvent(pvp._timer.ev) end
  if cycleEvent then
    pvp._timer.ev = cycleEvent(_tickTimer, 1000)
  else
    local function loop()
      if not pvp._timer.dlg or pvp._timer.dlg:isDestroyed() then return end
      _tickTimer()
      pvp._timer.ev = scheduleEvent(loop, 1000)
    end
    pvp._timer.ev = scheduleEvent(loop, 1000)
  end
end

function pvp._stopMatchTimer(timeUp)
  if pvp._timer.ev and removeEvent then removeEvent(pvp._timer.ev) end
  pvp._timer.ev   = nil
  pvp._timer.endsAt = 0
  if pvp._timer.dlg and not pvp._timer.dlg:isDestroyed() then
    pvp._timer.dlg:hide()
  end
  if timeUp then
    toast('Tempo da arena encerrado.')
  end
end

--------------------------------------------------------------------------------
-- Slots
--------------------------------------------------------------------------------
local function getSlotWidgets(w, id)
  local root = w:recursiveGetChildById(id); if not root then return nil end
  if root.getHeight and root:getHeight() < 92 then root:setHeight(92) end
  return {
    root  = root,
    view  = root:recursiveGetChildById('view'),
    label = root:recursiveGetChildById('label'),
  }
end

function applySlotToUi(w, id, st)
  local s = getSlotWidgets(w, id)
  if not s then return end
  
  if s.label and not s.root._blocked then
    s.label:setText(st.name or '')
    s.label:setVisible(true)
  end
  
  if not s.view then return end
  
  local lt = tonumber(st.lookType or st.looktype or st.type)
  if lt and lt > 0 then
    s.view:setOutfit({ type = lt })
    s.view:setVisible(true)
  elseif st.name and st.name ~= '' then
    s.view:setOutfit({ type = 128 })
    s.view:setVisible(true)
  else
    s.view:setVisible(false)
  end
end

local function coverWholeParent(widget, parent)
  if not widget or not parent then return end
  local hasLayout = parent.getLayout and parent:getLayout() ~= nil
  if hasLayout then
    local function sync()
      local r = parent:getRect()
      widget:setRect(r)
    end
    sync()
    if not widget._syncHooked then
      connect(parent, { onGeometryChange = sync })
      widget._syncHooked = true
    end
  else
    widget:addAnchor(AnchorTop,    'parent', AnchorTop)
    widget:addAnchor(AnchorLeft,   'parent', AnchorLeft)
    widget:addAnchor(AnchorRight,  'parent', AnchorRight)
    widget:addAnchor(AnchorBottom, 'parent', AnchorBottom)
  end
end

local function setSlotBlocked(w, id, blocked)
  local s = getSlotWidgets(w,id); if not s then return end
  local r, lab, v = s.root, s.label, s.view
  if blocked then
    if not r._blocker then
      local ov = g_ui.createWidget('UIWidget', r)
      coverWholeParent(ov, r)
      if ov.setBackgroundColor then ov:setBackgroundColor('#000000AA') end
      local lx = g_ui.createWidget('UILabel', ov)
      lx:setText('X'); lx:setColor('#E7D59A')
      if lx.setFont then lx:setFont('baby-20') end
      lx:setWidth(20); lx:setHeight(20)
      local function center()
        local pr = ov:getRect()
        lx:setX(pr.x + math.floor((pr.width - lx:getWidth())/2))
        lx:setY(pr.y + math.floor((pr.height - lx:getHeight())/2))
      end
      center()
      connect(ov, { onGeometryChange = center })
      r._blocker, r._blockerLabel = ov, lx
    end
    r._blocked = true
    if v   then v:setVisible(false)   end
    if lab then lab:setVisible(false) end
    r._blocker:setVisible(true)
  else
    r._blocked = false
    if r._blocker then r._blocker:setVisible(false) end
    if v   then v:setVisible(true) end
    if lab then
      lab:setVisible(true)
      local st = pvp.slots[id]
      lab:setText(st and st.name or '')
    end
  end
end

local function isOnePerTeam()
  return pvp.state.pvpType=='1x1' or pvp.state.pvpType=='lure1x1'
end

local function findMySlot()
  local cn = getCachedPlayerName()
  for id,st in pairs(pvp.slots) do
    if st.name and st.name ~= '' and st.name == cn then
      return id
    end
  end
end

local function ensureLocalPlayerPresent(w)
  if pvp._hasServerLobby then
    refreshWaiting(w)
    return
  end
  local cn = getCachedPlayerName()
  local where = findMySlot()
  if not where then
    pvp.setSlot('slotA1',{ name = cn, lookType = nil })
    where = 'slotA1'
  end
  
  -- Otimização: aplicar regras de bloqueio em batch
  local onePerTeam = isOnePerTeam()
  local allowed2 = onePerTeam and (MIRROR[where] or 'slotB2') or nil
  
  for id,_ in pairs(pvp.slots) do 
    local blocked = onePerTeam and not (id==where or id==allowed2)
    setSlotBlocked(w, id, blocked)
  end
  refreshWaiting(w)
end

--------------------------------------------------------------------------------
-- ?Buscando? (animação)
--------------------------------------------------------------------------------
local function _stopWaiting(id)
  local ev = pvp._waiting.timers[id]
  if ev and removeEvent then removeEvent(ev) end
  pvp._waiting.timers[id] = nil
  pvp._waiting.state[id]  = nil
end

local function _startWaiting(w, id)
  local s = getSlotWidgets(w,id); if not s or (s.root and s.root._blocked) then return end
  if s.view  then s.view:setVisible(false) end
  if s.label then s.label:setVisible(true); if s.label.setColor then s.label:setColor('#c8b894') end end
  if pvp._waiting.timers[id] then return end

  pvp._waiting.state[id] = { i=1 }
  local function tick()
    local st = pvp._waiting.state[id]; if not st then return end
    local frame = WAVE_FRAMES[st.i]
    st.i = (st.i % #WAVE_FRAMES) + 1
    local sw = getSlotWidgets(w,id)
    if not sw or sw.root._blocked then _stopWaiting(id); return end
    if sw.label then sw.label:setText('Buscando '..frame) end
  end

  if cycleEvent then
    pvp._waiting.timers[id] = cycleEvent(tick, WAVE_MS)
  else
    local function loop()
      if not pvp._waiting.state[id] then return end
      tick(); pvp._waiting.timers[id] = scheduleEvent(loop, WAVE_MS)
    end
    pvp._waiting.timers[id] = scheduleEvent(loop, WAVE_MS)
  end
end

local function setSlotWaiting(w, id, waiting)
  if waiting then
    _startWaiting(w, id)
  else
    _stopWaiting(id)
    local s = getSlotWidgets(w,id); if not s then return end
    local st = pvp.slots[id]
    if s.label then if s.label.setColor then s.label:setColor('#E7D59A') end; s.label:setText(st and st.name or '') end
    if s.view then
      local lt = tonumber(st.lookType or st.looktype or st.type)
      if lt and lt > 0 then
        s.view:setOutfit({ type = lt })
        s.view:setVisible(true)
      else
        s.view:setVisible(false)
      end
    end
  end
end

function refreshWaiting(w)
  local my = findMySlot()
  for id,st in pairs(pvp.slots) do
    local s = getSlotWidgets(w,id)
    if s then
      local blocked = s.root._blocked == true
      if id == my then
        setSlotWaiting(w,id,false)
      else
        if blocked then
          setSlotWaiting(w,id,false)
        else
          local hasName = (st.name and st.name~='')
          if hasName then setSlotWaiting(w,id,false) else setSlotWaiting(w,id,true) end
        end
      end
    end
  end
end

local function stopAllWaiting()
  for k,_ in pairs(pvp._waiting.timers) do _stopWaiting(k) end
end

--------------------------------------------------------------------------------
-- API de Slots (público)
--------------------------------------------------------------------------------
function pvp.setSlot(id, params)
  local w = ensureWindow(); if not w then return end
  local st = pvp.slots[id]; if not st then return end
  if params.name ~= nil then st.name = params.name end
  if params.lookType ~= nil then st.lookType = tonumber(params.lookType) end
  applySlotToUi(w,id,st)
  refreshWaiting(w)
end

function pvp.swapTeams()
  local w = ensureWindow(); if not w then return end
  pvp.slots.slotA1, pvp.slots.slotB1 = pvp.slots.slotB1, pvp.slots.slotA1
  pvp.slots.slotA2, pvp.slots.slotB2 = pvp.slots.slotB2, pvp.slots.slotA2
  for id,st in pairs(pvp.slots) do applySlotToUi(w,id,st) end
  ensureLocalPlayerPresent(w)
  refreshWaiting(w)
end

--------------------------------------------------------------------------------
-- Prompt / Convite (enviar)
--------------------------------------------------------------------------------
local function ensureInviteDialog()
  if pvp._inviteDlg and not pvp._inviteDlg:isDestroyed() then return pvp._inviteDlg end
  local root = g_ui.getRootWidget(); if not root then return nil end
  pvp._inviteDlg = g_ui.createWidget('InviteDialogWindow', root)
  pvp._inviteDlg:hide()
  return pvp._inviteDlg
end

function pvp.openPrompt(opts)
  local dlg = ensureInviteDialog(); if not dlg then return end
  opts = opts or {}
  dlg:setText(opts.title or 'Prompt')
  dlg:show(); dlg:raise(); dlg:focus()

  local info   = dlg:recursiveGetChildById('promptInfo')
  local input  = dlg:recursiveGetChildById('inviteInput')
  local okBtn  = dlg:recursiveGetChildById('inviteOkButton')
  local cancel = dlg:recursiveGetChildById('inviteCancelButton')

  if info and opts.hint then info:setText(opts.hint) end

  if input then
    local def = opts.defaultText or ''
    input:setText(def)
    if input.setCursorPos then input:setCursorPos(#def) end
    input:focus()
  end

  okBtn.onClick  = nil
  cancel.onClick = nil
  okBtn.onClick  = function()
    local value = input and input:getText() or ''
    if opts.onConfirm then opts.onConfirm(value) end
    dlg:hide()
  end
  cancel.onClick = function()
    if opts.onCancel then opts.onCancel() end
    dlg:hide()
  end
end

-- Parceiro (apenas 2x2)
function pvp.openInvitePartner()
  if pvp.state.pvpType ~= '2x2' then
    toast('Convite de parceiro disponível apenas no modo 2x2.')
    return
  end
  pvp.openPrompt({
    title='Convidar Parceiro',
    hint = 'Digite o nome do parceiro:',
    defaultText='',
    onConfirm=function(name)
      name = strtrim(name)
      if name=='' then toast('Nome vazio, convite nao enviado.'); return end
      pvpSend({ action='invite', kind='ally', names={name} })
      toast(string.format('Convite (ally) enviado para: %s (modo: %s)', name, pvp.state.pvpType))
    end
  })
end

-- Inimigo(s) - robusto, com filtros e envio de mode
function pvp.openInviteEnemy()
  local w = ensureWindow(); if not w then return end
  local wantCount = (pvp.state.pvpType=='1x1' or pvp.state.pvpType=='lure1x1') and 1 or 2
  local hint = (wantCount == 1) and 'Digite o nome do inimigo:' or 'Digite 1 ou 2 nomes (separados por virgula):'

  pvp.openPrompt({
    title = 'Convidar Inimigo',
    hint  = hint,
    defaultText = '',
    onConfirm = function(text)
      local me     = myName()
      local ally   = pvp.slots.slotA2 and pvp.slots.slotA2.name or ''
      local names, seen = {}, {}

      for token in tostring(text):gmatch('[^,%s]+') do
        local t = token:gsub('^%s+',''):gsub('%s+$','')
        local tn = _norm(t)
        if t ~= '' and not seen[tn] and tn ~= _norm(me) and tn ~= _norm(ally) then
          table.insert(names, t)
          seen[tn] = true
        end
      end

      if #names == 0 then
        toast('Nenhum nome válido (não pode ser você nem seu parceiro).')
        return
      end

      if wantCount == 1 then
        names = { names[1] }
      else
        if #names > 2 then names = { names[1], names[2] } end
      end

      local payload = { action='invite', kind='enemy', names=names, mode=pvp.state.pvpType }
      local ok = pvpSend(payload)
      if ok then
        toast(string.format('Convite (enemy) enviado: %s (modo: %s)', table.concat(names, ', '), pvp.state.pvpType))
      else
        toast('Falha ao enviar convite (offline?).')
      end

      applyModeSlotRules(w); refreshWaiting(w)
    end
  })
end

--------------------------------------------------------------------------------
-- MODOS (render + sync servidor)
--------------------------------------------------------------------------------
local function highlightTypeRows(w, sel)
  local list = w:recursiveGetChildById('pvpTypeMainPanel'); if not list then return end
  for _,row in ipairs(list:getChildren() or {}) do
    local cb = row:recursiveGetChildById('check')
    if cb then setRowBorderColor(row, (cb._value==sel) and COLOR_SELECTED or COLOR_NORMAL) end
  end
end

local function resizeTypeRows(ct)
  if not ct then return end
  local cw = ct:getWidth()
  for _,ch in ipairs(ct:getChildren()) do ch:setWidth(cw) end
end

local function setListHeightByCount(panel, count)
  if not panel or count<=0 then return end
  panel:setHeight((count*ROW_HEIGHT) + ((count-1)*ROW_SPACING))
end

function applyModeSlotRules(w)
  local onePerTeam = isOnePerTeam()
  
  -- Controlar visibilidade dos slots baseado no modo
  if onePerTeam then
    -- Para 1x1, mostrar todos os slots mas apenas preencher slotA1 e slotB1
    local slotA1 = w:recursiveGetChildById('slotA1')
    local slotA2 = w:recursiveGetChildById('slotA2')
    local vsBox = w:recursiveGetChildById('vsBox')
    local slotB1 = w:recursiveGetChildById('slotB1')
    local slotB2 = w:recursiveGetChildById('slotB2')
    
    -- Mostrar todos os slots
    if slotA1 then slotA1:show() end
    if slotA2 then slotA2:show() end
    if vsBox then vsBox:show() end
    if slotB1 then slotB1:show() end
    if slotB2 then slotB2:show() end
    
    -- Limpar slots não usados no modo 1x1
    if slotA2 then
      local slotA2Label = slotA2:recursiveGetChildById('label')
      local slotA2View = slotA2:recursiveGetChildById('view')
      if slotA2Label then slotA2Label:setText('') end
      if slotA2View then slotA2View:setVisible(false) end
    end
    
    if slotB2 then
      local slotB2Label = slotB2:recursiveGetChildById('label')
      local slotB2View = slotB2:recursiveGetChildById('view')
      if slotB2Label then slotB2Label:setText('') end
      if slotB2View then slotB2View:setVisible(false) end
    end
  else
    -- Para 2x2, mostrar todos os slots normalmente
    local slotA1 = w:recursiveGetChildById('slotA1')
    local slotA2 = w:recursiveGetChildById('slotA2')
    local vsBox = w:recursiveGetChildById('vsBox')
    local slotB1 = w:recursiveGetChildById('slotB1')
    local slotB2 = w:recursiveGetChildById('slotB2')
    
    if slotA1 then slotA1:show() end
    if slotA2 then slotA2:show() end
    if vsBox then vsBox:show() end
    if slotB1 then slotB1:show() end
    if slotB2 then slotB2:show() end
  end
  
  if not onePerTeam then
    -- Desbloquear todos os slots
    for id,_ in pairs(pvp.slots) do setSlotBlocked(w,id,false) end
    return
  end
  
  local where = findMySlot()
  if not where then 
    ensureLocalPlayerPresent(w)
    where = findMySlot()
  end
  
  local mirror = MIRROR[where] or 'slotB2'
  -- Aplicar bloqueios em batch para melhor performance
  for id,_ in pairs(pvp.slots) do 
    setSlotBlocked(w,id, not (id==where or id==mirror)) 
  end
end

local function disbandPartyIfNeeded(which)
  if which=='1x1' or which=='lure1x1' then
    pvp.setSlot('slotA2',{ name='', lookType=nil })
    pvp.setSlot('slotB2',{ name='', lookType=nil })
    pvpSend({ action='disbandParty' })
  end
end

-- botão dinâmico: Convidar Parceiro ? Sair da equipe
local function applyPartnerButtonState(w)
  w = w or ensureWindow(); if not w then return end
  local btn = pvp._uiRefs.invitePartnerBtn or w:recursiveGetChildById('inviteButton')
  if not btn then return end

  if pvp._hasServerLobby and iAmPartner() then
    btn:setText('Sair da equipe')
    btn:setEnabled(true)
    btn.onClick = function()
      local wasPartner = iAmPartner()
      pvpSend({ action='leaveParty' })
      if wasPartner then
        pvp._hasServerLobby = false
        pvp.setSlot('slotA2', { name='', lookType=nil })
        pvp.setSlot('slotB2', { name='', lookType=nil })
        applyModeSlotRules(w)
        refreshWaiting(w)
        applyPartnerButtonState(w)
      end
      pvpSend({ action='getLobby' })
      toast('Solicitado: sair da equipe.')
    end
    return
  end

  btn:setText('Convidar Parceiro')
  local enablePartner = (pvp.state.pvpType == '2x2')
  btn:setEnabled(enablePartner)
  btn.onClick = function() pvp.openInvitePartner() end
end

function pvp.selectMode(which)
  if pvp._updating then return end
  if which == pvp.state.pvpType then
    local w = ensureWindow(); if w then
      updateModeDependentControls(w)
      applyModeSlotRules(w)
      refreshWaiting(w)
      applyBetState(w)
    end
    return
  end
  if not pvp._canSelectMode then
    toast('Apenas o líder da sala pode alterar o modo.')
    local w = ensureWindow(); if w then highlightTypeRows(w, pvp.state.pvpType) end
    return
  end
  pvp._updating = true
  pvp.state.pvpType = which
  pvpSend({ action='selectMode', value=which })
  pvp._updating = false
  local w = ensureWindow(); if not w then return end
  disbandPartyIfNeeded(which)
  updateModeDependentControls(w)
  highlightTypeRows(w, which)
  applyModeSlotRules(w)
  refreshWaiting(w)
  applyBetState(w)
end

function buildPvpTypeRowsFrom(modes, selected)
  local w = ensureWindow(); if not w then return end
  local list = w:recursiveGetChildById('pvpTypeMainPanel'); if not list then return end

  list:destroyChildren()
  local count = 0
  for _,opt in ipairs(modes) do
    if opt.enabled ~= false then
      count = count + 1
      local row = g_ui.createWidget('PvPTypeRow', list)
      row:setId((opt.value or 'mode')..'_row'); row:setHeight(ROW_HEIGHT); row:setWidth(list:getWidth())
      local cb  = row:recursiveGetChildById('check') or g_ui.createWidget('CheckBox', row)
      cb:setId('cb_'..(opt.value or tostring(count)))
      cb._value = opt.value
      cb:setText(opt.text or opt.value or '?')
      cb:setChecked((opt.value or '') == (selected or ''))
      cb:setEnabled(pvp._canSelectMode)
      if not pvp._canSelectMode then cb:setTooltip('Somente o líder pode alterar o modo.') end
      cb.onCheckChange = function(widget, checked)
        if pvp._updating then return end
        if not pvp._canSelectMode then
          pvp._updating=true; widget:setChecked((widget._value)==(pvp.state.pvpType)); pvp._updating=false
          toast('Somente o líder pode alterar o modo.')
          return
        end
        if checked then pvp.selectMode(widget._value)
        elseif pvp.state.pvpType==widget._value then
          pvp._updating = true; widget:setChecked(true); pvp._updating = false
        end
      end
    end
  end
  setListHeightByCount(list, count)
  if not list._resizeHooked then
    connect(list, { onGeometryChange=function() resizeTypeRows(list) end })
    list._resizeHooked = true
  end
  resizeTypeRows(list)
  highlightTypeRows(w, selected)
  pvp._modesBuilt = true
  updateModeDependentControls(w)
end

function pvp._applyModes(payload)
  pvp._modes = payload.modes or FALLBACK_MODES
  pvp._canSelectMode = (payload.canSelect ~= false)
  pvp.state.pvpType = payload.selected or (pvp._modes[1] and pvp._modes[1].value) or '1x1'
  buildPvpTypeRowsFrom(pvp._modes, pvp.state.pvpType)
  local w = ensureWindow(); if w then applyModeSlotRules(w); refreshWaiting(w); applyPartnerButtonState(w); applyBetState(w) end
end

function pvp.requestModes()
  pvpSend({ action='getModes' })
  pvpSend({ action='getLobby' })
end

--------------------------------------------------------------------------------
-- Apostas (inputs numéricos + habilitação por checkbox)
--------------------------------------------------------------------------------
-- Verifica se há um time completo (pre-made)
local function hasCompleteTeam()
  local mode = pvp.state.pvpType or '1x1'
  local myName = getCachedPlayerName()
  
  -- Verificar se está em matchmaking (sem time definido)
  if pvp._queue and pvp._queue.inQueue then
    return false -- Matchmaking não permite apostas customizadas
  end
  
  -- 1v1: Precisa ter um oponente definido (slotB1 ou slotB2)
  if mode == '1x1' or mode == 'lure1x1' then
    local opponentName1 = pvp.slots.slotB1 and pvp.slots.slotB1.name or ''
    local opponentName2 = pvp.slots.slotB2 and pvp.slots.slotB2.name or ''
    return (opponentName1 ~= '' and opponentName1 ~= myName) or (opponentName2 ~= '' and opponentName2 ~= myName)
  end
  
  -- 2v2: Precisa ter um parceiro (slotA2) E oponentes (slotB1 e slotB2)
  if mode == '2x2' or mode == 'lure2x2' then
    local partnerName = pvp.slots.slotA2 and pvp.slots.slotA2.name or ''
    local opponent1Name = pvp.slots.slotB1 and pvp.slots.slotB1.name or ''
    local opponent2Name = pvp.slots.slotB2 and pvp.slots.slotB2.name or ''
    
    return partnerName ~= '' and opponent1Name ~= '' and opponent2Name ~= ''
  end
  
  return false
end

-- Verifica se o jogador atual é o líder (pode definir apostas)
local function canDefineBets()
  return hasCompleteTeam() and iAmLeader()
end

local function digitsOnly(s) return (s or ''):gsub('%D','') end
local function formatThousands_digits(d)
  if d=='' then return '' end
  local r = d:reverse():gsub('(%d%d%d)','%1.'):reverse()
  if r:sub(1,1)=='.' then r = r:sub(2) end
  return r
end

-- Formata números com separadores de milhares para exibição
local function formatNumberForDisplay(num)
  if not num or num == '' then return '' end
  local n = tonumber(num)
  if not n or n == 0 then return '0' end
  
  local formatted = tostring(n)
  local result = ''
  local len = #formatted
  
  for i = 1, len do
    local char = formatted:sub(i, i)
    result = result .. char
    -- Adiciona ponto a cada 3 dígitos (da direita para esquerda)
    if (len - i) % 3 == 0 and i < len then
      result = result .. '.'
    end
  end
  
  return result
end
local function formatWithCaret(t, pos)
  local left       = t:sub(1,pos)
  local digitsLeft = left:gsub('%D',''):len()
  local digitsAll  = digitsOnly(t)
  local formatted  = formatThousands_digits(digitsAll)
  local count, newPos = 0, 0
  for i=1,#formatted do
    local ch = formatted:sub(i,i)
    if ch:match('%d') then
      count = count + 1
      if count==digitsLeft then newPos = i; break end
    end
  end
  if digitsLeft==0 then newPos=0
  elseif digitsLeft>=digitsAll:len() then newPos=#formatted
  elseif newPos==0 then newPos=#formatted end
  return formatted, newPos
end
local function attachNumericHandlers(edit)
  if not edit or edit._wiredNumeric then return end
  edit._wiredNumeric = true
  edit.onTextChange = function(widget, text)
    if widget._fmtLock then return end
    widget._fmtLock = true
    local t   = text or widget:getText()
    local pos = widget.getCursorPos and widget:getCursorPos() or #t
    local f,np = formatWithCaret(t,pos)
    if f~=t then
      widget:setText(f)
      if widget.setCursorPos then widget:setCursorPos(np) end
    else
      if widget.setCursorPos then widget:setCursorPos(pos) end
    end
    widget._fmtLock = false
  end
end
local function wireSingleBetRow(w, rowId, checkId, inputId)
  local row  = w:recursiveGetChildById(rowId)
  local cb   = w:recursiveGetChildById(checkId)
  local edit = w:recursiveGetChildById(inputId)
  if not (row and cb and edit) then return end
  attachNumericHandlers(edit)
  local function apply()
    local on = cb:isChecked()
    setRowBorderColor(row, on and COLOR_SELECTED or COLOR_NORMAL)
    if edit.setEnabled then edit:setEnabled(on) end
    
    -- Se o jogador pode definir apostas, enviar valores para o servidor
    if canDefineBets() then
      sendBetValuesToServer()
    end
  end
  
  -- Função para enviar valores quando o input mudar
  local function onInputChange()
    if canDefineBets() then
      sendBetValuesToServer()
    end
  end
  
  if not cb._wiredBet then 
    cb._wiredBet = true
    cb.onCheckChange = apply
  end
  
  if not edit._wiredBetInput then
    edit._wiredBetInput = true
    edit.onTextChange = onInputChange
  end
  
  local t = edit:getText(); local f = select(1, formatWithCaret(t,#t))
  if f~=t then edit:setText(f); if edit.setCursorPos then edit:setCursorPos(#f) end end
  apply()
end

-- Envia valores das apostas para o servidor
function sendBetValuesToServer()
  local w = ensureWindow(); if not w then return end
  
  local goldInput = w:recursiveGetChildById('goldInput')
  local eloInput = w:recursiveGetChildById('eloInput')
  local pointsInput = w:recursiveGetChildById('pointsInput')
  
  local goldValue = goldInput and goldInput:getText() or ''
  local eloValue = eloInput and eloInput:getText() or ''
  local pointsValue = pointsInput and pointsInput:getText() or ''
  
  -- Remove formatação antes de enviar (apenas números)
  goldValue = digitsOnly(goldValue)
  eloValue = digitsOnly(eloValue)
  pointsValue = digitsOnly(pointsValue)
  
  pvpSend({
    action = 'setBetValues',
    goldValue = goldValue,
    eloValue = eloValue,
    pointsValue = pointsValue
  })
end
local function wireBetRows(w)
  wireSingleBetRow(w,'betGoldRow','optGold','goldInput')
  wireSingleBetRow(w,'betEloRow','optElo','eloInput')
  wireSingleBetRow(w,'betPointsRow','optPoints','pointsInput')
end

-- Atualiza o estado das apostas baseado em se há time completo
function applyBetState(w)
  if not w then return end
  
  local hasTeam = hasCompleteTeam()
  local canDefine = canDefineBets()
  
  -- Checkboxes de aposta
  local cbGold = w:recursiveGetChildById('optGold')
  local cbPoints = w:recursiveGetChildById('optPoints')
  local cbElo = w:recursiveGetChildById('optElo')
  
  -- Inputs de aposta
  local inputGold = w:recursiveGetChildById('goldInput')
  local inputPoints = w:recursiveGetChildById('pointsInput')
  local inputElo = w:recursiveGetChildById('eloInput')
  
  -- Se não há time completo: bloquear tudo (valores fixos do servidor)
  if not hasTeam then
    if cbGold then
      if cbGold.setEnabled then cbGold:setEnabled(false) end
      if cbGold.setChecked then cbGold:setChecked(false) end
    end
    if cbPoints then
      if cbPoints.setEnabled then cbPoints:setEnabled(false) end
      if cbPoints.setChecked then cbPoints:setChecked(false) end
    end
    if cbElo then
      if cbElo.setEnabled then cbElo:setEnabled(false) end
      if cbElo.setChecked then cbElo:setChecked(false) end
    end
    
    -- Desabilitar inputs
    if inputGold and inputGold.setEnabled then inputGold:setEnabled(false) end
    if inputPoints and inputPoints.setEnabled then inputPoints:setEnabled(false) end
    if inputElo and inputElo.setEnabled then inputElo:setEnabled(false) end
    
    -- Atualizar cores das bordas
    local rowGold = w:recursiveGetChildById('betGoldRow')
    local rowPoints = w:recursiveGetChildById('betPointsRow')
    local rowElo = w:recursiveGetChildById('betEloRow')
    
    if rowGold then setRowBorderColor(rowGold, COLOR_NORMAL) end
    if rowPoints then setRowBorderColor(rowPoints, COLOR_NORMAL) end
    if rowElo then setRowBorderColor(rowElo, COLOR_NORMAL) end
    
    return
  end
  
  -- Se há time completo: apenas o líder pode definir apostas
  if cbGold then
    if cbGold.setEnabled then cbGold:setEnabled(canDefine) end
    if not canDefine and cbGold.setChecked then cbGold:setChecked(false) end
  end
  
  if cbPoints then
    if cbPoints.setEnabled then cbPoints:setEnabled(canDefine) end
    if not canDefine and cbPoints.setChecked then cbPoints:setChecked(false) end
  end
  
  if cbElo then
    if cbElo.setEnabled then cbElo:setEnabled(canDefine) end
    if not canDefine and cbElo.setChecked then cbElo:setChecked(false) end
  end
  
  -- Inputs: só habilitados se checkbox estiver marcado E jogador pode definir
  if inputGold and inputGold.setEnabled then
    inputGold:setEnabled(canDefine and cbGold and cbGold:isChecked())
  end
  
  if inputPoints and inputPoints.setEnabled then
    inputPoints:setEnabled(canDefine and cbPoints and cbPoints:isChecked())
  end
  
  if inputElo and inputElo.setEnabled then
    inputElo:setEnabled(canDefine and cbElo and cbElo:isChecked())
  end
  
  -- Atualizar cores das bordas
  local rowGold = w:recursiveGetChildById('betGoldRow')
  local rowPoints = w:recursiveGetChildById('betPointsRow')
  local rowElo = w:recursiveGetChildById('betEloRow')
  
  if rowGold then
    setRowBorderColor(rowGold, (cbGold and cbGold:isChecked()) and COLOR_SELECTED or COLOR_NORMAL)
  end
  if rowPoints then
    setRowBorderColor(rowPoints, (cbPoints and cbPoints:isChecked()) and COLOR_SELECTED or COLOR_NORMAL)
  end
  if rowElo then
    setRowBorderColor(rowElo, (cbElo and cbElo:isChecked()) and COLOR_SELECTED or COLOR_NORMAL)
  end
end

--------------------------------------------------------------------------------
-- Histórico
--------------------------------------------------------------------------------
local function ensureHistoryWindow()
  if historyWin and not historyWin:isDestroyed() then return historyWin end
  local root = g_ui.getRootWidget(); if not root then return nil end
  historyWin = g_ui.createWidget('HistoryWindow', root)

  local modeFilter    = historyWin:recursiveGetChildById('modeFilter')
  local outcomeFilter = historyWin:recursiveGetChildById('outcomeFilter')
  local queueFilter   = historyWin:recursiveGetChildById('queueFilter')
  local searchInput   = historyWin:recursiveGetChildById('searchInput')

  if modeFilter and modeFilter.clearOptions then
    modeFilter:clearOptions(); modeFilter:addOption('Todos'); modeFilter:addOption('1x1'); modeFilter:addOption('2x2'); modeFilter:addOption('Lure 1x1'); modeFilter:addOption('Lure 2x2')
    if modeFilter.setCurrentOption then modeFilter:setCurrentOption('Todos') end
  end
  if outcomeFilter and outcomeFilter.clearOptions then
    outcomeFilter:clearOptions(); outcomeFilter:addOption('Todos'); outcomeFilter:addOption('Vitória'); outcomeFilter:addOption('Derrota'); outcomeFilter:addOption('Empate')
    if outcomeFilter.setCurrentOption then outcomeFilter:setCurrentOption('Todos') end
  end
  if queueFilter and queueFilter.clearOptions then
    queueFilter:clearOptions(); queueFilter:addOption('Todos'); queueFilter:addOption('Casual'); queueFilter:addOption('Ranked')
    if queueFilter.setCurrentOption then queueFilter:setCurrentOption('Todos') end
  end

  local function wireFilter(wd)
    if wd and not wd._wired then
      wd._wired = true
      wd.onTextChange   = function() debounceCall('histFilters', 140, function() pvp.refreshHistoryList() end) end
      wd.onOptionChange = function() debounceCall('histFilters', 140, function() pvp.refreshHistoryList() end) end
    end
  end
  wireFilter(searchInput); wireFilter(modeFilter); wireFilter(outcomeFilter); wireFilter(queueFilter)

  local closeBtn = historyWin:recursiveGetChildById('closeHistoryButton')
  if closeBtn and not closeBtn._wired then closeBtn._wired=true; closeBtn.onClick=function() historyWin:hide() end end
  return historyWin
end

local function addHistoryRow(list, h, idx)
  local row = g_ui.createWidget('PvPHistoryRow', list)
  if (idx%2)==0 and row.setBackgroundColor then row:setBackgroundColor('#24160c') end
  local outcomeBar = row:recursiveGetChildById('outcomeBar')
  local title      = row:recursiveGetChildById('title')
  local subtitle   = row:recursiveGetChildById('subtitle')
  local rightMeta  = row:recursiveGetChildById('rightMeta')

  local isWin = (h.result=='win'); local isLoss=(h.result=='loss')
  if outcomeBar and outcomeBar.setBackgroundColor then
    outcomeBar:setBackgroundColor(isWin and '#2ea043' or (isLoss and '#c73b3b' or '#8a8a8a'))
  end

  local a = table.concat(h.teamA or {}, ', ')
  local b = table.concat(h.teamB or {}, ', ')
  local qTag = '['..queueNice(h.queue or 'casual')..']'
  if title then title:setText(string.format('%s  %s   %s  vs  %s', qTag, modeNice(h.mode), a~='' and a or '?', b~='' and b or '?')) end

  local gold   = fmtThousandsBR((h.bets and h.bets.gold)   or 0)
  local eloBet = fmtThousandsBR((h.bets and h.bets.elo)    or 0)
  local points = fmtThousandsBR((h.bets and h.bets.points) or 0)
  if subtitle then
    local ts = h.when or os.time()
    local dur= tonumber(h.duration or 0) or 0
    subtitle:setText(string.format('%s - Gold:%s  Elo:%s  Points:%s - %s', fmtWhen(ts), gold, eloBet, points, fmtDuration(dur)))
  end

  if rightMeta then
    local delta = tonumber(h.eloDelta or 0) or 0
    rightMeta:setText(string.format('%+d ELO', delta))
    if rightMeta.setColor then rightMeta:setColor(delta>=0 and '#AEE07A' or '#E07A7A') end
  end
end

local function passesFilters(h, sText, mText, oText, qText)
  if sText ~= '' then
    local blob = table.concat(h.teamA or {}, ' ') .. ' ' .. table.concat(h.teamB or {}, ' ')
      .. ' ' .. (h.mode or '') .. ' ' .. (h.result or '') .. ' ' .. (h.queue or '')
    if not blob:lower():find(sText,1,true) then return false end
  end
  if mText and mText~='Todos' then
    if mText=='1x1' and h.mode~='1x1' then return false end
    if mText=='2x2' and h.mode~='2x2' then return false end
    if mText=='Lure 1x1' and h.mode~='lure1x1' then return false end
    if mText=='Lure 2x2' and h.mode~='lure2x2' then return false end
  end
  if oText and oText~='Todos' then
    local map={['Vitoria']='win',['Derrota']='loss',['Empate']='draw' }
    if (map[oText] or '') ~= (h.result or '') then return false end
  end
  if qText and qText~='Todos' then
    local qmap = { ['Casual']='casual', ['Ranked']='ranked', ['Rankeado']='ranked' }
    local want = qmap[qText] or qText:lower()
    local has  = (h.queue or 'casual')
    if want ~= has then return false end
  end
  return true
end

local function sizeHistoryList(list, count)
  if not list then return end
  local h = (count and count>0) and ((count*HIST_ROW_H) + ((count-1)*HIST_ROW_SP)) or 0
  list:setHeight(h)
end

function pvp.refreshHistoryList()
  local w = ensureHistoryWindow(); if not w then return end
  local list   = w:recursiveGetChildById('historyList'); if not list then return end
  local search = w:recursiveGetChildById('searchInput')
  local modeF  = w:recursiveGetChildById('modeFilter')
  local outF   = w:recursiveGetChildById('outcomeFilter')
  local queueF = w:recursiveGetChildById('queueFilter')
  local stats  = w:recursiveGetChildById('histStats')

  list:destroyChildren()

  local sText = (search and search:getText() or ''):lower()
  local mText = getComboText(modeF)
  local oText = getComboText(outF)
  local qText = getComboText(queueF)

  table.sort(pvp.history, function(a,b) return (a.when or 0) > (b.when or 0) end)

  local total, wcnt, lcnt, dcnt = 0, 0, 0, 0
  for _,h in ipairs(pvp.history) do
    if passesFilters(h, sText, mText, oText, qText) then
      total = total + 1
      if h.result=='win'  then wcnt = wcnt + 1
      elseif h.result=='loss' then lcnt = lcnt + 1
      else dcnt = dcnt + 1 end
      addHistoryRow(list, h, total)
    end
  end

  sizeHistoryList(list, total)
  local wr = (wcnt+lcnt)>0 and math.floor((wcnt/(wcnt+lcnt))*100) or 0
  if stats then stats:setText(string.format('Partidas: %d  -  W-L-D: %d-%d-%d  -  Winrate: %d%%', total, wcnt, lcnt, dcnt, wr)) end
end

function pvp.openHistory()
  local w = ensureHistoryWindow(); if not w then return end
  w:show(); w:raise(); w:focus()
  pvpSend({ action = "getHistory" })
end

--------------------------------------------------------------------------------
-- Ranking
--------------------------------------------------------------------------------
local function ensureRankingWindow()
  if rankingWin and not rankingWin:isDestroyed() then return rankingWin end
  local root = g_ui.getRootWidget(); if not root then return nil end
  rankingWin = g_ui.createWidget('RankingWindow', root)

  local closeBtn = rankingWin:recursiveGetChildById('closeRankingButton')
  if closeBtn and not closeBtn._wired then closeBtn._wired=true; closeBtn.onClick=function() rankingWin:hide() end end

  local rankSearch = rankingWin:recursiveGetChildById('rankSearch')
  if rankSearch and not rankSearch._wired then
    rankSearch._wired = true
    rankSearch.onTextChange = function()
      debounceCall('rankSearch', 140, function() pvp.refreshRankingList() end)
    end
  end

  local list = rankingWin:recursiveGetChildById('rankingList')
  if list then list:setWidth(RANK_MIN_W) end
  return rankingWin
end

local _rankingCache = { players = {} }

local function addRankingRow(list, rec, idx, myName)
  local row = g_ui.createWidget('RankingRow', list)
  if (idx%2)==0 and row.setBackgroundColor then row:setBackgroundColor('#24160c') end
  local pos = row:recursiveGetChildById('posLabel')
  local name= row:recursiveGetChildById('nameLabel')
  local wdl = row:recursiveGetChildById('wdlLabel')
  local pts = row:recursiveGetChildById('pointsLabel')
  if pos  then pos:setText('#'..tostring(idx)) end
  if name then name:setText(rec.name or '?') end
  if wdl  then wdl:setText(string.format('%dJ - %d-%d-%d', tonumber(rec.games or 0), tonumber(rec.w or 0), tonumber(rec.d or 0), tonumber(rec.l or 0))) end
  if pts  then pts:setText(string.format('%d pts', tonumber(rec.points or rec.pts or 0))) end
  if myName and _norm(rec.name or '')==_norm(myName) then
    if row.setBackgroundColor then row:setBackgroundColor('#3a2a17') end
    if name.setColor then name:setColor('#FFD58A') end
    if pts.setColor  then pts:setColor('#FFD58A')  end
  end
end

local function sizeRankingList(list, count)
  if not list then return end
  local h = (count and count>0) and ((count*RANK_ROW_H) + ((count-1)*RANK_ROW_SP)) or 0
  list:setWidth(RANK_MIN_W)
  list:setHeight(h)
end

function pvp._applyRanking(payload)
  _rankingCache.players = payload.players or {}
  pvp.refreshRankingList()
end

function pvp.refreshRankingList()
  local w = ensureRankingWindow(); if not w then return end
  local list   = w:recursiveGetChildById('rankingList'); if not list then return end
  local stats  = w:recursiveGetChildById('rankStats')
  local search = w:recursiveGetChildById('rankSearch')
  list:destroyChildren()

  local me   = getCachedPlayerName()
  local q    = (search and search:getText() or ''):lower()

  local filtered = {}
  for _,rec in ipairs(_rankingCache.players) do
    if q=='' or (tostring(rec.name or ''):lower():find(q,1,true)) then
      table.insert(filtered, rec)
    end
  end

  local shown = 0
  for _,rec in ipairs(filtered) do
    shown = shown + 1
    addRankingRow(list, rec, shown, me)
  end
  sizeRankingList(list, shown)
  
  if stats then 
    if shown == 0 and #_rankingCache.players == 0 then
      stats:setText('Nenhum jogador encontrado. (O servidor nao retornou dados do ranking)')
    else
      stats:setText(string.format('Jogadores: %d  -  (somente partidas Ranked)', shown))
    end
  end
end

function pvp.openRanking()
  local w = ensureRankingWindow(); if not w then return end
  w:show(); w:raise(); w:focus()
  pvpSend({ action = "getRanking" })
end

--------------------------------------------------------------------------------
-- Player Info (perfil vindo do servidor)
--------------------------------------------------------------------------------
local function ensurePlayerInfoWindow()
  if playerInfoWin and not playerInfoWin:isDestroyed() then return playerInfoWin end
  local root = g_ui.getRootWidget(); if not root then return nil end
  playerInfoWin = g_ui.createWidget('PlayerInfoWindow', root)
  local closeBtn = playerInfoWin:recursiveGetChildById('closePlayerInfoButton')
  if closeBtn and not closeBtn._wired then
    closeBtn._wired = true
    closeBtn.onClick = function() playerInfoWin:hide() end
  end
  playerInfoWin:hide()
  return playerInfoWin
end

function pvp._applyProfile(data)
  local w = ensurePlayerInfoWindow(); if not w then return end
  local infoName   = w:recursiveGetChildById('infoName')
  local infoAvatar = w:recursiveGetChildById('infoAvatar')
  local infoDiv    = w:recursiveGetChildById('infoDivision')
  local progBox    = w:recursiveGetChildById('progressBox')
  local progFill   = w:recursiveGetChildById('progressFill')
  local progText   = w:recursiveGetChildById('progressText')

  local vCur      = w:recursiveGetChildById('valueCurStreak')
  local vBest     = w:recursiveGetChildById('valueBestStreak')
  local vRankNow  = w:recursiveGetChildById('valueRankNow')
  local vPts      = w:recursiveGetChildById('valuePts')
  local vPartner  = w:recursiveGetChildById('valueBestPartner')
  local seasonBlk = w:recursiveGetChildById('seasonBlock')

  local name        = data.name or 'Player'
  local division    = data.division or '-'
  local points      = tonumber(data.points or 0) or 0
  local nextDiv     = data.nextDivision
  local pct         = tonumber(data.progressPct or 0) or 0
  local curStreak   = tonumber(data.curStreak or 0) or 0
  local bestStreak  = tonumber(data.bestStreak or 0) or 0
  local bestPartner = data.bestPartner
  local bpW         = tonumber(data.bestPartnerWins or 0) or 0
  local bpG         = tonumber(data.bestPartnerGames or 0) or 0
  local seasonText  = data.seasonText

  if infoName then infoName:setText(name) end
  if infoAvatar then
    -- Prioridade: servidor > slots > LocalPlayer > padrão
    local lookType = tonumber(data.outfit or data.lookType or data.looktype or data.type)
    
    if not lookType then
      local nameLower = name:lower()
      for _, slotId in ipairs({'slotA1', 'slotA2', 'slotB1', 'slotB2'}) do
        local slot = pvp.slots[slotId]
        if slot and slot.name and slot.name:lower() == nameLower and slot.lookType then
          lookType = slot.lookType
          break
        end
      end
    end
    
    if not lookType then
      local lp = g_game.getLocalPlayer()
      local cn = getCachedPlayerName()
      if lp and name:lower() == cn:lower() and lp.getOutfit then
        local outfit = lp:getOutfit()
        if outfit and outfit.type then
          lookType = outfit.type
        end
      end
    end
    
    infoAvatar:setOutfit({ type = lookType or 128 })
    infoAvatar:setVisible(true)
  end

  if infoDiv  then infoDiv:setText(string.format("Divisao: %s (%d pts)", division, points)) end
  if vRankNow then vRankNow:setText(division) end
  if vPts     then vPts:setText(tostring(points)) end
  if vCur     then vCur:setText(tostring(curStreak)) end
  if vBest    then vBest:setText(tostring(bestStreak)) end

  if vPartner then
    if bestPartner and bestPartner ~= "" then
      vPartner:setText(string.format("%s (%dW/%dJ)", bestPartner, bpW, bpG))
    else
      vPartner:setText("-")
    end
  end

  if progBox and progFill and progText then
    local totalW = progBox:getWidth() or 1
    local px = math.floor((pct/100) * totalW)
    progFill:setWidth(px)
    local toward = nextDiv and (" -> "..nextDiv) or ""
    progText:setText(string.format("%d%%%s", pct, toward))
  end

  if seasonBlk and seasonText then
    seasonBlk:setText(seasonText)
  end
end

function pvp.openPlayerInfo(nameOpt)
  local w = ensurePlayerInfoWindow(); if not w then return end
  local cn = nameOpt or getCachedPlayerName()
  w:show(); w:raise(); w:focus()
  local iname = w:recursiveGetChildById('infoName'); if iname then iname:setText(cn .. " (carregando...)") end
  pvpSend({ action = "getProfile", name = cn })
end

--------------------------------------------------------------------------------
-- Confirmação de Queue (Casual/Ranked) ? confirmArenaWindow (looktype slots)
--------------------------------------------------------------------------------
pvp._queueDlg     = nil
pvp._queueToken   = nil
pvp._queueSlotMap = nil   -- name -> slotId (a1Slot/a2Slot/b1Slot/b2Slot)

local function ensureQueueConfirmWindow()
  if pvp._queueDlg and not pvp._queueDlg:isDestroyed() then return pvp._queueDlg end
  local root = g_ui.getRootWidget(); if not root then return nil end
  pvp._queueDlg = g_ui.createWidget('confirmArenaWindow', root)
  pvp._queueDlg:hide()
  return pvp._queueDlg
end

-- refs de um slot do template
local function _slotRefs(dlg, slotId)
  local s = dlg and dlg:recursiveGetChildById(slotId)
  if not s then return nil end
  return {
    root  = s,
    view  = s:recursiveGetChildById('view'),
    label = s:recursiveGetChildById('label'),
    shade = s:recursiveGetChildById('shade'),
  }
end

local function _setSlotLook(dlg, slotId, lookTypeOrNil, visible, playerName)
  local s = _slotRefs(dlg, slotId); if not s then return end
  
  if not visible then
    if s.view then s.view:setVisible(false) end
    if s.label then s.label:setText('') end
    if s.root then s.root:setVisible(false) end
    return
  end
  
  -- Se for "X", não exibir outfit
  if playerName == "X" then
    if s.view then s.view:setVisible(false) end
    if s.label then s.label:setText("X") end
    if s.root then s.root:setVisible(true) end
    return
  end
  
  local lt = tonumber(lookTypeOrNil)
  if not lt or lt <= 0 then lt = 128 end -- Outfit padrão
  
  if s.view then
    s.view:setOutfit({ type = lt })
    s.view:setVisible(true)
  end
  
  if s.label and playerName then
    s.label:setText(playerName)
  end
  
  if s.root then s.root:setVisible(true) end
end

local function _setSlotDark(dlg, slotId, darkOn)
  local s = _slotRefs(dlg, slotId); if not s then return end
  if s.shade then if darkOn then s.shade:show() else s.shade:hide() end end
end

local function _hideUnusedSlots(dlg, mode)
  -- Sempre mostrar todos os 4 slots, independente do modo
  local a1 = dlg:recursiveGetChildById('a1Slot')
  local a2 = dlg:recursiveGetChildById('a2Slot')
  local b1 = dlg:recursiveGetChildById('b1Slot')
  local b2 = dlg:recursiveGetChildById('b2Slot')
  
  -- Mostrar todos os slots
  if a1 then a1:show() end
  if a2 then a2:show() end
  if b1 then b1:show() end
  if b2 then b2:show() end
end

local function _setConfirmText(dlg, queue, mode, timeout)
  local txt = dlg:recursiveGetChildById('confirmText')
  local qn  = (queue == 'ranked') and 'Ranked' or 'Casual'
  local mn  = (mode == '1x1' and '1x1') or (mode == '2x2' and '2x2')
           or (mode == 'lure1x1' and 'Lure 1x1') or (mode == 'lure2x2' and 'Lure 2x2') or (mode or '?')
  if txt then
    txt:setText(string.format('Entrar na partida %s (%s)? Voce tem %ds para responder.', qn, mn, tonumber(timeout or 20)))
  end
end

local function _updateAcceptButtonsEnabled(dlg, enabled)
  local okb = dlg:recursiveGetChildById('acceptButton')
  local cnb = dlg:recursiveGetChildById('declineButton')
  if okb then okb:setEnabled(enabled) end
  if cnb then cnb:setEnabled(enabled) end
end

-- tenta resolver lookType de um nome (payload ou lobby local)
local function _resolveLookTypeFor(name, payload)
  if not name or name == '' then return nil end
  
  local function scan(list)
    for _,v in ipairs(list or {}) do
      if type(v) == 'table' then
        local nm = (v.name or v.n or ''):lower()
        if nm ~= '' and nm == tostring(name or ''):lower() then
          return tonumber(v.lookType or v.looktype or v.type)
        end
      end
    end
    return nil
  end
  
  -- Primeiro tenta encontrar nos dados do payload
  local lt = scan(payload.members and payload.members.A or {}) or scan(payload.members and payload.members.B or {})
  if lt and lt > 0 then return lt end

  -- Se não encontrou, tenta no lobby local
  for _,id in ipairs({'slotA1','slotA2','slotB1','slotB2'}) do
    local st = pvp.slots[id]
    if st and st.name and st.name:lower() == tostring(name or ''):lower() then
      if st.lookType then return tonumber(st.lookType) end
    end
  end
  
  -- Fallback: usa outfit padrão
  return 128
end

local function _fillSlotsFromMembers(dlg, mode, members, payload)
  pvp._queueSlotMap = {}

  local function extract(list)
    local out = {}
    for _,v in ipairs(list or {}) do
      if type(v) == 'table' then
        table.insert(out, { name = v.name or v.n or '', lookType = tonumber(v.lookType or v.looktype or v.type) })
      else
        table.insert(out, { name = tostring(v or ''), lookType = nil })
      end
    end
    return out
  end

  local A = extract(members and members.A or {})
  local B = extract(members and members.B or {})

  local one = (mode == '1x1' or mode == 'lure1x1')

  -- Sempre preencher todos os 4 slots
  local a1 = A[1]
  if a1 then
    a1.lookType = a1.lookType or _resolveLookTypeFor(a1.name, payload)
    _setSlotLook(dlg, 'a1Slot', a1.lookType, true, a1.name)
    pvp._queueSlotMap[a1.name] = 'a1Slot'
  else
    _setSlotLook(dlg, 'a1Slot', nil, false)
  end

  local a2 = A[2]
  if a2 then
    a2.lookType = a2.lookType or _resolveLookTypeFor(a2.name, payload)
    _setSlotLook(dlg, 'a2Slot', a2.lookType, true, a2.name)
    pvp._queueSlotMap[a2.name] = 'a2Slot'
  else
    if one then
      -- No modo 1x1, preencher com "X"
      _setSlotLook(dlg, 'a2Slot', nil, true, "X")
    else
      _setSlotLook(dlg, 'a2Slot', nil, false)
    end
  end

  local b1 = B[1]
  if b1 then
    b1.lookType = b1.lookType or _resolveLookTypeFor(b1.name, payload)
    _setSlotLook(dlg, 'b1Slot', b1.lookType, true, b1.name)
    pvp._queueSlotMap[b1.name] = 'b1Slot'
  else
    if one then
      -- No modo 1x1, preencher com "X"
      _setSlotLook(dlg, 'b1Slot', nil, true, "X")
    else
      _setSlotLook(dlg, 'b1Slot', nil, false)
    end
  end

  local b2 = B[2]
  if b2 then
    b2.lookType = b2.lookType or _resolveLookTypeFor(b2.name, payload)
    _setSlotLook(dlg, 'b2Slot', b2.lookType, true, b2.name)
    pvp._queueSlotMap[b2.name] = 'b2Slot'
  else
    if one then
      -- No modo 1x1, preencher com "X"
      _setSlotLook(dlg, 'b2Slot', nil, true, "X")
    else
      _setSlotLook(dlg, 'b2Slot', nil, false)
    end
  end

  -- todos começam escuros; aceitações clareiam (exceto slots com "X")
  for _,sid in ipairs({'a1Slot','a2Slot','b1Slot','b2Slot'}) do 
    local s = _slotRefs(dlg, sid)
    if s and s.label then
      local text = s.label:getText()
      if text ~= "X" then
        _setSlotDark(dlg, sid, true)
      end
    end
  end
end

local function _applyAcceptedShading(dlg, acceptedNames)
  -- Primeiro, escurecer todos os slots (não confirmados)
  for _,sid in ipairs({'a1Slot','a2Slot','b1Slot','b2Slot'}) do 
    -- Verificar se o slot não é um "X" antes de aplicar shade
    local s = _slotRefs(dlg, sid)
    if s and s.label then
      local text = s.label:getText()
      if text ~= "X" then
        _setSlotDark(dlg, sid, true)
      end
    end
  end
  
  -- Depois, clarear apenas os que aceitaram
  if acceptedNames then
    for _,nm in ipairs(acceptedNames) do
      local sid = pvp._queueSlotMap and pvp._queueSlotMap[nm]
      if sid then _setSlotDark(dlg, sid, false) end
    end
  end
end

-- exibir pedido
function pvp._showQueueConfirmAsk(payload)
  local dlg = ensureQueueConfirmWindow(); if not dlg then return end
  pvp._queueToken = payload.token

  _setConfirmText(dlg, payload.queue, payload.mode, payload.timeout)
  _hideUnusedSlots(dlg, payload.mode)
  _fillSlotsFromMembers(dlg, payload.mode, payload.members or {A={},B={}}, payload)
  _applyAcceptedShading(dlg, payload.accepted)

  local okb = dlg:recursiveGetChildById('acceptButton')
  local cnb = dlg:recursiveGetChildById('declineButton')
  
  -- Sempre reconfigurar os botões para garantir que funcionem
  if okb then
    okb.onClick = function()
      _updateAcceptButtonsEnabled(dlg, false)
      pvpSend({ action='queueConfirmReply', token=pvp._queueToken, accepted=true })
    end
    okb:setEnabled(true)
  end
  
  if cnb then
    cnb.onClick = function()
      _updateAcceptButtonsEnabled(dlg, false)
      pvpSend({ action='queueConfirmReply', token=pvp._queueToken, accepted=false })
    end
    cnb:setEnabled(true)
  end

  dlg:show(); dlg:raise(); dlg:focus()
end

-- atualizar progresso (quem aceitou/pendente/recusou)
function pvp._applyQueueConfirmUpdate(payload)
  local dlg = ensureQueueConfirmWindow(); if not dlg or dlg:isHidden() then return end

  -- Aplicar shading baseado no status de confirmação
  _applyAcceptedShading(dlg, payload.accepted)

  local txt = dlg:recursiveGetChildById('confirmText')
  if txt then
    local acc = table.concat(payload.accepted or {}, ', ')
    local pen = table.concat(payload.pending  or {}, ', ')
    local dec = table.concat(payload.declined or {}, ', ')
    local lines = {}
    if acc ~= '' then table.insert(lines, 'Aceitaram: '..acc) end
    if pen ~= '' then table.insert(lines, 'Pendentes: '..pen) end
    if dec ~= '' then table.insert(lines, 'Recusaram: '..dec) end
    txt:setText(txt:getText()..'\n'..table.concat(lines,' | '))
  end
end

-- finalizar (começa/aborta)
function pvp._finishQueueConfirm(payload)
  local dlg = ensureQueueConfirmWindow(); if dlg then dlg:hide() end
  pvp._queueToken   = nil
  pvp._queueSlotMap = nil
  
  -- Limpa estados de confirmação
  pvp._activeInviteId = nil
  pvp._inviteQueue = {}
  pvp._inviteMap = {}
  
  -- Fechar janela principal do PVP quando partida iniciar
  local w = ensureWindow()
  if w then
    w:hide()
  end
  
  -- Fechar janela de fila se estiver aberta
  if pvp._queue and pvp._queue.window then
    pvp._queue.window:hide()
  end
  
  -- Fechar janelas de convite se estiverem abertas
  if pvp._askDlg and not pvp._askDlg:isDestroyed() then
    pvp._askDlg:hide()
  end
  if pvp._inviteDlg and not pvp._inviteDlg:isDestroyed() then
    pvp._inviteDlg:hide()
  end
  
  -- teleporte é responsabilidade do servidor
end

--------------------------------------------------------------------------------
-- Convites (Aceitar / Recusar)
--------------------------------------------------------------------------------
local function ensureAskDialog()
  if pvp._askDlg and not pvp._askDlg:isDestroyed() then return pvp._askDlg end
  local root = g_ui.getRootWidget(); if not root then return nil end
  local dlg = g_ui.createWidget('InviteDialogWindow', root)
  local input = dlg:recursiveGetChildById('inviteInput'); if input then input:hide() end
  local info  = dlg:recursiveGetChildById('promptInfo')
  local okBtn = dlg:recursiveGetChildById('inviteOkButton')
  local cnl   = dlg:recursiveGetChildById('inviteCancelButton')
  if okBtn then okBtn:setText('Aceitar') end
  if cnl  then cnl:setText('Recusar') end
  if info then info:setText('Convite PvP') end
  pvp._askDlg = dlg
  dlg:hide()
  return dlg
end

function pvp._enqueueInvite(inv)
  if not inv or not inv.id then return end
  pvp._inviteMap[inv.id] = inv
  table.insert(pvp._inviteQueue, inv.id)
  if not pvp._activeInviteId then
    pvp._showNextInvite()
  else
    toast(string.format('Novo convite de %s enfileirado.', tostring(inv.from)))
  end
end

function pvp._showNextInvite()
  if pvp._activeInviteId then return end
  local nextId = table.remove(pvp._inviteQueue, 1)
  if not nextId then return end
  local inv = pvp._inviteMap[nextId]; if not inv then return end
  pvp._activeInviteId = nextId

  local dlg = ensureAskDialog(); if not dlg then return end
  local info  = dlg:recursiveGetChildById('promptInfo')
  local okBtn = dlg:recursiveGetChildById('inviteOkButton')
  local cnl   = dlg:recursiveGetChildById('inviteCancelButton')

  if info then
    local kindTxt = inv.kind=='ally' and 'ser seu parceiro' or 'enfrentá-lo como inimigo'
    info:setText(string.format('%s convidou você para %s (%s).\nAceitar?', inv.from or '?', kindTxt, modeNice(inv.mode)))
  end

  if okBtn then okBtn.onClick  = function() pvp._replyInvite(inv.id, true)  end end
  if cnl  then cnl.onClick     = function() pvp._replyInvite(inv.id, false) end end

  dlg:setText('Convite PvP')
  dlg:show(); dlg:raise(); dlg:focus()
end

function pvp._replyInvite(id, accepted)
  pvpSend({ action='inviteReply', id=id, accepted=accepted and true or false })
  local dlg = ensureAskDialog(); if dlg then dlg:hide() end
  pvp._inviteMap[id] = nil
  pvp._activeInviteId = nil
  pvp._showNextInvite()
end

function pvp._onInviteStatus(payload)
  if payload.who then
    toast(string.format('%s %s o convite.', payload.who, payload.accepted and 'ACEITOU' or 'RECUSOU'))
  else
    toast('Convites enviados. Aguardando respostas...')
  end
end

--------------------------------------------------------------------------------
-- Lado direito (times), botões
--------------------------------------------------------------------------------
local function wireTeams(w)
  if not (w:recursiveGetChildById('slotA1') and w:recursiveGetChildById('slotA2') and
          w:recursiveGetChildById('slotB1') and w:recursiveGetChildById('slotB2')) then return end
  if not pvp._teamsWired then
    local cn = getCachedPlayerName()
    pvp.setSlot('slotA1',{name=cn, lookType=nil})
    pvp.setSlot('slotA2',{name='',  lookType=nil})
    pvp.setSlot('slotB1',{name='',  lookType=nil})
    pvp.setSlot('slotB2',{name='',  lookType=nil})
    local vsButton = w:recursiveGetChildById('vsButton')
    if vsButton and not vsButton._wired then
      vsButton._wired = true
      vsButton.onClick = function() pvp.swapTeams(); applyModeSlotRules(w); refreshWaiting(w) end
    end
    pvp._teamsWired = true
  else
    for id,st in pairs(pvp.slots) do applySlotToUi(w,id,st) end
  end
  ensureLocalPlayerPresent(w)
  refreshWaiting(w)
end

-- Inicia a queue (Casual/Ranked) - somente líder
function pvp.queueStart(queue)
  queue = (queue == 'ranked') and 'ranked' or 'casual'
  pvpSend({ action = 'queueStart', queue = queue })
end

-- Entra na fila de matchmaking
function pvp.queueJoin(queue, mode)
  queue = (queue == 'ranked') and 'ranked' or 'casual'
  mode = mode or pvp.state.pvpType
  pvpSend({ action = 'queueJoin', queue = queue, mode = mode })
end

-- Sai da fila de matchmaking
function pvp.queueLeave()
  pvpSend({ action = 'queueLeave' })
end

-- Verifica status da fila
function pvp.queueStatus()
  pvpSend({ action = 'queueStatus' })
end

-- ---------- Interface de Fila de Matchmaking ----------
local function ensureQueueWindow()
  if pvp._queue.window and not pvp._queue.window:isDestroyed() then return pvp._queue.window end
  local root = g_ui.getRootWidget(); if not root then return nil end
  pvp._queue.window = g_ui.createWidget('QueueWindow', root)
  pvp._queue.window:hide()
  return pvp._queue.window
end

local function _fmtQueueTime(seconds)
  local m = math.floor(seconds / 60)
  local s = seconds % 60
  return string.format('%02d:%02d', m, s)
end

local function _updateQueueTimer()
  if not pvp._queue.inQueue then return end
  
  local elapsed = os.time() - pvp._queue.startTime
  local w = ensureQueueWindow()
  if not w then return end
  
  local timeLabel = w:recursiveGetChildById('queueTimeLabel')
  if timeLabel then
    timeLabel:setText('Tempo na fila: ' .. _fmtQueueTime(elapsed))
  end
  
  local statusLabel = w:recursiveGetChildById('queueStatusLabel')
  if statusLabel then
    local queueText = (pvp._queue.queue == 'ranked') and 'Ranked' or 'Casual'
    local modeText = modeNice(pvp._queue.mode)
    statusLabel:setText(string.format('Procurando partida %s (%s)', queueText, modeText))
  end
end

local function _startQueueTimer()
  if pvp._queue.timer and removeEvent then removeEvent(pvp._queue.timer) end
  
  local function tick()
    if not pvp._queue.inQueue then return end
    _updateQueueTimer()
    pvp._queue.timer = scheduleEvent(tick, 1000)
  end
  
  pvp._queue.timer = scheduleEvent(tick, 1000)
end

local function _stopQueueTimer()
  if pvp._queue.timer and removeEvent then removeEvent(pvp._queue.timer) end
  pvp._queue.timer = nil
end

function pvp._showQueueWindow(queue, mode)
  local w = ensureQueueWindow()
  if not w then return end
  
  pvp._queue.inQueue = true
  pvp._queue.queue = queue
  pvp._queue.mode = mode
  pvp._queue.startTime = os.time()
  
  -- Configura a janela
  local titleLabel = w:recursiveGetChildById('queueTitleLabel')
  if titleLabel then
    local queueText = (queue == 'ranked') and 'Ranked' or 'Casual'
    titleLabel:setText('Fila de Matchmaking - ' .. queueText)
  end
  
  local modeLabel = w:recursiveGetChildById('queueModeLabel')
  if modeLabel then
    modeLabel:setText('Modo: ' .. modeNice(mode))
  end
  
  -- Botão de sair da fila
  local leaveBtn = w:recursiveGetChildById('queueLeaveButton')
  if leaveBtn then
    leaveBtn.onClick = function()
      pvp.queueLeave()
    end
  end
  
  w:show()
  w:raise()
  w:focus()
  
  _startQueueTimer()
  _updateQueueTimer()
end

function pvp._hideQueueWindow()
  local w = ensureQueueWindow()
  if w then w:hide() end
  
  pvp._queue.inQueue = false
  pvp._queue.queue = nil
  pvp._queue.mode = nil
  pvp._queue.startTime = 0
  
  _stopQueueTimer()
end

-- Handlers para ações da fila
function pvp._onQueueJoined(payload)
  pvp._showQueueWindow(payload.queue, payload.mode)
  toast(string.format('Entrou na fila %s (%s)', 
    (payload.queue == 'ranked') and 'Ranked' or 'Casual',
    modeNice(payload.mode)))
end

function pvp._onQueueLeft(payload)
  pvp._hideQueueWindow()
  toast('Saiu da fila de matchmaking')
end

function pvp._onQueueStatus(payload)
  if payload.inQueue then
    pvp._queue.inQueue = true
    pvp._queue.startTime = payload.startTime or os.time()
    _startQueueTimer()
    _updateQueueTimer()
  else
    pvp._hideQueueWindow()
  end
end

local function applyQueueButtonsState(w)
  w = w or ensureWindow(); if not w then return end
  local casualBtn = w:recursiveGetChildById('casualButton')
  local rankedBtn = w:recursiveGetChildById('rankedButton')
  local enable = iAmLeader()
  if casualBtn then casualBtn:setEnabled(enable); casualBtn.onClick = function() pvp.queueStart('casual') end end
  if rankedBtn then rankedBtn:setEnabled(enable); rankedBtn.onClick = function() pvp.queueStart('ranked') end end
end

function updateModeDependentControls(w)
  w = w or ensureWindow(); if not w then return end
  applyPartnerButtonState(w)
  applyQueueButtonsState(w)
end

local function wireButtons()
  local w = ensureWindow(); if not w then return end
  local inviteBtn       = w:recursiveGetChildById('inviteButton')
  local inviteEnemyBtn  = w:recursiveGetChildById('inviteEnemyButton')
  local historyBtn      = w:recursiveGetChildById('historyButton')
  local rankingBtn      = w:recursiveGetChildById('rankingButton')
  local playerInfoBtn   = w:recursiveGetChildById('playerInfoButton')

  if inviteBtn       and not inviteBtn._wired      then inviteBtn._wired      = true; inviteBtn.onClick      = function() pvp.openInvitePartner() end end
  if inviteEnemyBtn  and not inviteEnemyBtn._wired then inviteEnemyBtn._wired = true; inviteEnemyBtn.onClick = function() pvp.openInviteEnemy() end end
  if historyBtn      and not historyBtn._wired     then historyBtn._wired     = true; historyBtn.onClick     = function() pvp.openHistory() end end
  if rankingBtn      and not rankingBtn._wired     then rankingBtn._wired     = true; rankingBtn.onClick     = function() pvp.openRanking() end end
  if playerInfoBtn   and not playerInfoBtn._wired  then playerInfoBtn._wired  = true; playerInfoBtn.onClick  = function() pvp.openPlayerInfo() end end

  if not pvp._modesBuilt then
    buildPvpTypeRowsFrom(pvp._modes or FALLBACK_MODES, pvp.state.pvpType or '1x1')
  end

  updateModeDependentControls(w)
  wireTeams(w)
  wireBetRows(w)
  applyBetState(w)
end

--------------------------------------------------------------------------------
-- Cleanup ao fechar
--------------------------------------------------------------------------------
function pvp._resetLocalLobby()
  local w = ensureWindow(); if not w then return end
  pvp._hasServerLobby = false
  local me = getCachedPlayerName()
  pvp.slots.slotA1 = { name = me, lookType = nil }
  pvp.slots.slotA2 = { name = '',  lookType = nil }
  pvp.slots.slotB1 = { name = '',  lookType = nil }
  pvp.slots.slotB2 = { name = '',  lookType = nil }
  
  -- Limpa estados de convites
  pvp._inviteQueue = {}
  pvp._inviteMap = {}
  pvp._activeInviteId = nil
  
  -- Fecha janelas de convite se estiverem abertas
  if pvp._askDlg and not pvp._askDlg:isDestroyed() then 
    pvp._askDlg:hide() 
  end
  if pvp._inviteDlg and not pvp._inviteDlg:isDestroyed() then 
    pvp._inviteDlg:hide() 
  end
  
  -- Fecha janela de confirmação de partida se estiver aberta
  local confirmWin = g_ui.getRootWidget():recursiveGetChildById('confirmArenaWindow')
  if confirmWin and not confirmWin:isDestroyed() then
    confirmWin:hide()
  end
  
  -- Atualiza UI
  for id,st in pairs(pvp.slots) do applySlotToUi(w,id,st) end
  applyModeSlotRules(w)
  refreshWaiting(w)
  applyPartnerButtonState(w)
  applyQueueButtonsState(w)
  applyBetState(w)
end

-- Função para invalidar cache quando necessário
local function invalidateCache()
  pvp._cache.playerName = nil
  pvp._cache.isLeader = nil
  pvp._cache.isPartner = nil
  pvp._cache.lastUpdate = 0
end

function pvp._cleanupOnClose()
  local online = g_game and g_game.isOnline and g_game:isOnline()
  if online then
    if iAmLeader() then
      pvpSend({ action='cancelInvites' })
      pvpSend({ action='disbandParty' })
    elseif iAmPartner() then
      pvpSend({ action='leaveParty' })
    end
    
    -- Sair da fila se estiver em uma
    if pvp._queue.inQueue then
      pvpSend({ action='queueLeave' })
    end
  end

  -- Cleanup otimizado
  if pvp._askDlg and not pvp._askDlg:isDestroyed() then pvp._askDlg:hide() end
  if pvp._inviteDlg and not pvp._inviteDlg:isDestroyed() then pvp._inviteDlg:hide() end
  
  -- Limpar estruturas de dados
  pvp._inviteQueue = {}
  pvp._inviteMap = {}
  pvp._activeInviteId = nil
  
  -- Limpar fila
  pvp._hideQueueWindow()
  
  -- Invalidar cache
  invalidateCache()

  pvp._resetLocalLobby()
end

--------------------------------------------------------------------------------
-- Dispatcher do ExtendedOpcode otimizado (com proteção anti-reentrância)
--------------------------------------------------------------------------------
local function _handlePvpOpcode(opcode, buffer)
  if opcode ~= pvp.OPCODE then return end
  if pvp._rxBusy then return end
  pvp._rxBusy = true

  local ok, payload = pcall(function() return json.decode(buffer) end)
  if not ok or type(payload) ~= 'table' then 
    pvp._rxBusy = false
    toast('Erro ao decodificar payload: ' .. tostring(buffer))
    return 
  end

  local action = payload.action
  -- Invalidar cache quando necessário
  if action == "lobby" or action == "modes" then
    invalidateCache()
  end
  if action == "profile" then
    pvp._applyProfile(payload)

  elseif action == "history" then
    pvp.history = payload.matches or {}
    pvp.refreshHistoryList()

  elseif action == "ranking" then
    pvp._applyRanking(payload)

  elseif action == "modes" then
    local sig = ((payload.canSelect ~= false) and '1' or '0') .. '|' ..
                tostring(payload.selected or '') .. '|' ..
                (pcall(json.encode, payload.modes or {}) and json.encode(payload.modes or {}) or '')
    if sig ~= pvp._lastModesSig then
      pvp._lastModesSig = sig
      pvp._applyModes(payload)
    end
  elseif action == "matchTimer" then
    -- servidor pode mandar duration (segundos) OU endsAt (timestamp)
    local endsAt   = tonumber(payload.endsAt)
    local duration = tonumber(payload.duration)
    if endsAt and endsAt > os.time() then
      pvp._startMatchTimer(endsAt, true)
    elseif duration and duration > 0 then
      pvp._startMatchTimer(duration, false)
    end

  elseif action == "matchEnd" then
    -- fim normal (vitória/derrota), servidor vai teletransportar
    pvp._stopMatchTimer(false)
    
    -- Limpa todos os estados relacionados à partida
    pvp._resetLocalLobby()
    
    -- Limpa estados de fila
    if pvp._queue then
      pvp._queue.inQueue = false
      pvp._queue.queue = nil
      pvp._queue.mode = nil
      pvp._queue.startTime = nil
      if pvp._queue.timer then
        removeEvent(pvp._queue.timer)
        pvp._queue.timer = nil
      end
      if pvp._queue.window then
        pvp._queue.window:hide()
      end
    end
    
    -- Limpa estados de confirmação
    pvp._queueSlotMap = {}
    
    -- Força atualização da interface
    local w = ensureWindow()
    if w then
      applyModeSlotRules(w)
      refreshWaiting(w)
      applyPartnerButtonState(w)
      applyQueueButtonsState(w)
      applyBetState(w)
    end

  elseif action == "error" then
    toast(payload.message or 'Erro.')

  elseif action == "info" then
    toast(payload.message or 'OK.')

  elseif action == "queueConfirmAsk" then
    pvp._showQueueConfirmAsk(payload)

  elseif action == "queueConfirmUpdate" then
    pvp._applyQueueConfirmUpdate(payload)

  elseif action == "queueConfirmDone" then
    pvp._finishQueueConfirm(payload)

  elseif action == "betValues" then
    -- Sincronizar valores de apostas definidos pelo líder
    local w = ensureWindow(); if not w then return end
    
    local goldValue = payload.goldValue or ''
    local eloValue = payload.eloValue or ''
    local pointsValue = payload.pointsValue or ''
    
    local goldInput = w:recursiveGetChildById('goldInput')
    local eloInput = w:recursiveGetChildById('eloInput')
    local pointsInput = w:recursiveGetChildById('pointsInput')
    
    -- Formatar números para exibição
    if goldInput and goldValue ~= '' then 
      goldInput:setText(formatNumberForDisplay(goldValue)) 
    end
    if eloInput and eloValue ~= '' then 
      eloInput:setText(formatNumberForDisplay(eloValue)) 
    end
    if pointsInput and pointsValue ~= '' then 
      pointsInput:setText(formatNumberForDisplay(pointsValue)) 
    end
    
    -- Aplicar estado das apostas após sincronizar valores
    applyBetState(w)

  elseif action == "lobby" then
    local s = payload.slots or {}
    pvp._hasServerLobby = true
    for id,_ in pairs(pvp.slots) do
      pvp.slots[id].name     = ''
      pvp.slots[id].lookType = nil
    end
    
    -- Captura o lookType do jogador local se vier do servidor (como no inspect.lua)
    local me = getCachedPlayerName()
    if payload.playerLookType then
      pvp._localPlayerLookType = tonumber(payload.playerLookType)
    elseif payload.outfit then
      pvp._localPlayerLookType = tonumber(payload.outfit)
    else
      pvp._localPlayerLookType = nil
    end
    
    local w = ensureWindow()
    local function _apply(id, rec)
      if not rec then return end
      if pvp.slots[id] then
        pvp.slots[id].name     = rec.name or ''
        pvp.slots[id].lookType = tonumber(rec.lookType or rec.looktype or rec.type)
        if w then applySlotToUi(w, id, pvp.slots[id]) end
        
        -- Se o jogador local está neste slot, atualiza o lookType
        if rec.name and rec.name:lower() == me:lower() and pvp.slots[id].lookType then
          pvp._localPlayerLookType = pvp.slots[id].lookType
        end
      end
    end
    _apply('slotA1', s.slotA1)
    _apply('slotA2', s.slotA2)
    _apply('slotB1', s.slotB1)
    _apply('slotB2', s.slotB2)
    if w then
      -- Sincroniza valores das apostas se disponíveis
      if payload.betValues then
        local goldInput = w:recursiveGetChildById('goldInput')
        local eloInput = w:recursiveGetChildById('eloInput')
        local pointsInput = w:recursiveGetChildById('pointsInput')
        
        if goldInput and payload.betValues.gold then 
          goldInput:setText(formatNumberForDisplay(payload.betValues.gold)) 
        end
        if eloInput and payload.betValues.elo then 
          eloInput:setText(formatNumberForDisplay(payload.betValues.elo)) 
        end
        if pointsInput and payload.betValues.points then 
          pointsInput:setText(formatNumberForDisplay(payload.betValues.points)) 
        end
      end
      
      applyModeSlotRules(w)
      refreshWaiting(w)
      applyPartnerButtonState(w)
      applyQueueButtonsState(w)
      applyBetState(w)
      -- Atualiza o avatar do jogador local quando o servidor envia dados do lobby
      setPlayerAvatar()
    end

  elseif action == "invite" then
    pvp._enqueueInvite(payload)

  elseif action == "inviteStatus" then
    pvp._onInviteStatus(payload)

  elseif action == "queueJoined" then
    pvp._onQueueJoined(payload)

  elseif action == "queueLeft" then
    pvp._onQueueLeft(payload)

  elseif action == "queueStatus" then
    pvp._onQueueStatus(payload)
  end

  pvp._rxBusy = false
end

-- Wrappers (duas APIs possíveis)
local function onGameExtendedOpcode(opcode, buffer)     _handlePvpOpcode(opcode, buffer) end
local function onProtoExtendedOpcode(_, opcode, buffer) _handlePvpOpcode(opcode, buffer) end

--------------------------------------------------------------------------------
-- Lifecycle (sem auto-open no login)
--------------------------------------------------------------------------------
function pvp.init()
  math.randomseed(os.time())
  _G.pvp_open = function() pvp.toggle() end

  g_keyboard.bindKeyDown(HOTKEY, pvp.toggle)

  local function registerHandler()
    local registered = false
    if ProtocolGame and ProtocolGame.registerExtendedOpcode then
      local ok = pcall(function() ProtocolGame.registerExtendedOpcode(pvp.OPCODE, onProtoExtendedOpcode) end)
      if ok then pvp._usingProtoHook = true; registered = true end
    end
    if not registered then
      connect(g_game, { onExtendedOpcode = onGameExtendedOpcode })
      pvp._usingProtoHook = false
      registered = true
    end
    return registered
  end

  registerHandler()

  connect(g_game, {
    onGameStart=function()
      registerHandler()
      pvp.requestModes()
      if window and window:isVisible() then setPlayerAvatar() end
    end
  })
end

function pvp.terminate()
  disconnect(g_game,{ onGameStart=nil })
  if pvp._debouncers then
    for id,ev in pairs(pvp._debouncers) do
      if ev and removeEvent then removeEvent(ev) end
      pvp._debouncers[id] = nil
    end
  end
  if pvp._usingProtoHook and ProtocolGame and ProtocolGame.unregisterExtendedOpcode then
    ProtocolGame.unregisterExtendedOpcode(pvp.OPCODE)
  else
    disconnect(g_game, { onExtendedOpcode = onGameExtendedOpcode })
  end
  stopAllWaiting()
  pvp._stopMatchTimer(false) 
  pvp._cleanupOnClose()
  pvp.hide()
  g_keyboard.unbindKeyDown(HOTKEY)
  _G.pvp_open=nil
end

function pvp.toggle()
  local w = ensureWindow(); if not w then return end
  if w:isVisible() then pvp.hide() else pvp.show() end
end

function pvp.show()
  local w = ensureWindow(); if not w then return end
  w:show(); w:raise(); w:focus()
  setPlayerAvatar()
  wireButtons()
  if not pvp._hasServerLobby then
    ensureLocalPlayerPresent(w)
  else
    applyModeSlotRules(w)
    refreshWaiting(w)
  end
  updateModeDependentControls(w)
  pvp.requestModes()
end

function pvp.hide()
  stopAllWaiting()
  pvp._stopMatchTimer(false)   -- << add
  pvp._cleanupOnClose()
  if window then window:hide() end
end


-- (fim)
