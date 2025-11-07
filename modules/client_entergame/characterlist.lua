--[[
  CharacterList.lua ? optimized, DRY, safer
  - Consolidates duplicated UI/event logic
  - Extracts HTTP helpers (cookie reuse, URL selection, captcha)
  - Centralizes wait/load/error boxes and event cleanup
  - Guards nils; preserves public API and OTUI ids
  - Keeps compatibility with server payload shapes you already use
]]

CharacterList   = CharacterList or {}
CreateCharacter = CreateCharacter or {}
DeleteCharacter = DeleteCharacter or {}

-- =====================[ Config / Estado ]=====================
local API_BASE = "https://ntoascension.com/createAccount.php" or nil  -- exemplo: "https://191.101.78.116/createAccount.php"
local sessionCookie = rawget(_G, "sessionCookie") or nil
local captchaToken   = rawget(_G, 'captchaToken')  or nil

local ui -- charactersWindow
local listWidget -- characterList
local loadBox, errorBox, waitingWindow
local autoReconnectButton
local updateWaitEvent, resendWaitEvent, loginEvent, autoReconnectEvent
local lastLogout = 0
local createCharSubmitting = false

-- seleção de vocação
local selectedVocCard, selectedVocationId, selectedNewtypeId = nil, nil, nil
selectedVocationName = selectedVocationName or nil -- mantido global
VOCATION_INDEX = VOCATION_INDEX or { byId = {}, byName = {} }

-- seleção de delete
selectedCharacterId   = selectedCharacterId   or nil
selectedCharacterName = selectedCharacterName or nil

-- =====================[ Tiny utils ]=====================
local function W(id)
  return ui and ui:recursiveGetChildById(id)
end

local function nowMillis()  return g_clock.millis() end
local function nowSeconds() return g_clock.seconds() end

local function destroyEvent(ev)
  if ev then removeEvent(ev) end
  return nil
end

local function setInfoBox(title, msg, onOk)
  local box = displayInfoBox(tr(title), tr(msg))
  if onOk then box.onOk = onOk end
  return box
end

local function setErrorBox(title, msg, onOk)
  local box = displayErrorBox(tr(title), msg)
  if onOk then box.onOk = onOk end
  return box
end

local function destroyLoadBox()
  if loadBox then loadBox:destroy(); loadBox = nil end
end

local function showLoadBox(title, message, onCancel)
  destroyLoadBox()
  loadBox = displayCancelBox(tr(title), tr(message))
  connect(loadBox, { onCancel = function()
    destroyLoadBox()
    if onCancel then onCancel() end
  end })
end

local function hideEnterGame()
  if EnterGame and EnterGame.hide then EnterGame.hide() end
end

local function getMac()
  local addrs = g_platform.getMacAddresses()
  return (type(addrs) == 'table' and next(addrs) and (addrs[1] or 'UNKNOWN')) or 'UNKNOWN'
end

local function isHttpUrl(s)
  s = tostring(s or ''):lower()
  return s:find('http://', 1, true) == 1 or s:find('https://', 1, true) == 1
end

-- Decide a URL da API: usa global API_BASE; senão G.host se for http; senão fallback dev
local function chooseApiUrl()
  if type(API_BASE) == 'string' and #API_BASE > 6 then return API_BASE end
  local h = (G and G.host) and G.host or ''
  if isHttpUrl(h) then return h end
  return 'http://127.0.0.1/createAccount.php'
end

-- HTTP POST JSON (reuse cookie; capture set-cookie)
local function apiPost(action, payload, cb, extraHeaders)
  payload = payload or {}; payload.action = action
  local headers = extraHeaders or {}
  if sessionCookie then headers['Cookie'] = sessionCookie end

  local url = chooseApiUrl()

  HTTP.postJSON(url, payload, function(data, err, headersOut)
    if headersOut then
      local sc = headersOut.status_code or headersOut.Status or headersOut.status or '?'
    end
    if err then
      cb(nil, err, headersOut); return
    end

    local ok, result = pcall(function()
      return type(data) == 'table' and data or json.decode(data)
    end)
    if not ok then
      g_logger.error('[CharacterList] JSON decode failed: ' .. tostring(result))
      cb(nil, 'invalid_json', headersOut); return
    end

    if headersOut then
      for k, v in pairs(headersOut) do
        if string.lower(k) == 'set-cookie' then
          sessionCookie = v:match('^(.-);') or v
          _G.sessionCookie = sessionCookie
          break
        end
      end
    end

    cb(result, nil, headersOut)
  end, headers)
end

local function fetchCaptcha(labelId)
  apiPost('get_captcha', {}, function(res, err)
    if not err and res and res.success then
      local lab = labelId and W(labelId) or nil
      if lab then lab:setText(res.captcha or '') end
      captchaToken = res.token; _G.captchaToken = captchaToken
    end
  end)
end

local function switchPanel(targetId)
  for _, id in ipairs({ 'listPanel', 'createCharacterPanel', 'deleteCharacterPanel', 'changePasswordPanel' }) do
    local p = W(id)
    if p then p:setVisible(id == targetId) end
  end
end

local function setLabelText(id, text)
  local w = W(id)
  if not w then return end
  -- se vier vazio/nil, usa ASCII simples pra não virar "?"
  if text == nil or text == '' then
    text = '-'         -- (antes você usava '?')
  end
  w:setText(tostring(text))
end

local function fetchAccountInfo()
  -- 1) Preenche imediatamente com o que veio no pacote de login
  local acc = (G and G.characterAccount) or {}
  if acc then
    if acc.email and acc.email ~= '' then
      setLabelText('EmailValue', acc.email)
    end
    if acc.recoveryKey and acc.recoveryKey ~= '' then
      setLabelText('RecoveryKeyValue', acc.recoveryKey)
    end
  end

  -- 2) (Opcional) Tenta atualizar via API, mas NÃO sobrescreve com vazio
  if not (G and G.account and #G.account > 0) then return end
  apiPost('get_account_info', { account_name = G.account }, function(res, err)
    if err or not res then return end
    local email = res.email or (res.account and res.account.email)
    local rkey  = res.recovery_key or (res.account and res.account.recovery_key)
    if email and email ~= '' then setLabelText('EmailValue', email) end
    if rkey  and rkey  ~= '' then setLabelText('RecoveryKeyValue', rkey) end
  end)
end

-- Copia texto do label para a área de transferência e dá um feedback visual
function CopyLabel(id)
  local w = ui and ui:recursiveGetChildById(id)
  if not w then return end

  local s = tostring(w:getText() or '')
  -- sanitiza: tira controles e trim
  s = s:gsub("[%z\1-\31]", ""):match("^%s*(.-)%s*$")

  -- evita copiar placeholder
  if s == '' or s == '-' or s == '?' then return end

  local ok = false
  if g_window and g_window.setClipboardText then
    g_window.setClipboardText(s); ok = true
  elseif g_platform and g_platform.setClipboardText then
    g_platform.setClipboardText(s); ok = true
  end

  -- feedback visual rápido (pisca a cor)
  if ok then
    local originalColor = '#FFFFFF' -- seus labels estão em branco no OTUI
    w:setColor('#FFD700')
    scheduleEvent(function()
      if w and not w:isDestroyed() then w:setColor(originalColor) end
    end, 220)
  end
end


-- =====================[ Auto Reconnect ]=====================
local function scheduleAutoReconnect()
  if lastLogout + 2000 > nowMillis() then return end
  autoReconnectEvent = destroyEvent(autoReconnectEvent)
  autoReconnectEvent = scheduleEvent(function()
    if autoReconnectButton and autoReconnectButton:isOn() and not g_game.isOnline() then
      if errorBox then errorBox:destroy(); errorBox = nil end
      CharacterList.doLogin()
    end
  end, 2500)
end

-- =====================[ Login Flow ]=====================
local function tryLogin(charInfo, tries)
  tries = tries or 1
  if tries > 50 then return end

  if g_game.isOnline() then
    if tries == 1 then g_game.safeLogout() end
    loginEvent = scheduleEvent(function() tryLogin(charInfo, tries + 1) end, 100)
    return
  end

  local host  = charInfo.worldHost or charInfo.worldIp or charInfo.host or '127.0.0.1'
  local port  = tonumber(charInfo.worldPort or charInfo.port or 7172)
  local wname = charInfo.worldName or charInfo.world or 'Ascension'
  local cname = charInfo.characterName or charInfo.name or 'Unknown'

  CharacterList.hide()
  hideEnterGame()

  g_game.loginWorld(G.account, G.password, wname, host, port, cname, G.authenticatorToken, G.sessionKey)
  g_logger.info(string.format('Login to %s:%d', host, port))

  showLoadBox('Please wait', 'Connecting to game server...', function()
    g_game.cancelLogin()
    CharacterList.show()
  end)

  g_settings.set('last-used-character', cname)
  g_settings.set('last-used-world', wname)
end

-- =====================[ Waiting (queue) ]=====================
local function updateWait(timeStart, timeEnd)
  if not waitingWindow then return end
  local now = nowSeconds()
  if now <= timeEnd then
    local percent = ((now - timeStart) / (timeEnd - timeStart)) * 100
    local timeStr = string.format('%.0f', timeEnd - now)
    local progressBar = waitingWindow:getChildById('progressBar')
    if progressBar then progressBar:setPercent(percent) end
    local label = waitingWindow:getChildById('timeLabel')
    if label then label:setText(tr('Trying to reconnect in %s seconds.', timeStr)) end
    updateWaitEvent = scheduleEvent(function() updateWait(timeStart, timeEnd) end, 500)
    return true
  end
  updateWaitEvent = destroyEvent(updateWaitEvent)
end

local function resendWait()
  if not waitingWindow then return end
  waitingWindow:destroy(); waitingWindow = nil
  updateWaitEvent = destroyEvent(updateWaitEvent)

  if ui and listWidget then
    local selected = listWidget:getFocusedChild()
    if selected then
      tryLogin({
        worldHost     = selected.worldHost or selected.worldIp or selected.host,
        worldPort     = tonumber(selected.worldPort or selected.port),
        worldName     = selected.worldName or selected.world,
        characterName = selected.characterName or selected.name
      })
    end
  end
end

local function onLoginWait(message, time)
  destroyLoadBox()
  waitingWindow = g_ui.displayUI('waitinglist')
  local label = waitingWindow:getChildById('infoLabel')
  if label then label:setText(message) end
  updateWaitEvent = scheduleEvent(function() updateWait(nowSeconds(), nowSeconds() + time) end, 0)
  resendWaitEvent = scheduleEvent(resendWait, time * 1000)
end

-- =====================[ g_game Events ]=====================
local function onGameLoginError(message)
  destroyLoadBox()
  errorBox = setErrorBox('Login Error', message, function()
    errorBox = nil
    CharacterList.showAgain()
  end)
  scheduleAutoReconnect()
end

local function onGameLoginToken(_)
  destroyLoadBox()
  errorBox = setErrorBox('Two-Factor Authentification',
                         'A new authentification token is required.\nPlease login again.',
                         function()
                           errorBox = nil
                           if EnterGame and EnterGame.show then EnterGame.show() end
                         end)
end

local function onGameConnectionError(message, code)
  destroyLoadBox()
  if (not g_game.isOnline() or code ~= 2) and not errorBox then
    local text = translateNetworkError(code, g_game.getProtocolGame() and g_game.getProtocolGame():isConnecting(), message)
    errorBox = setErrorBox('Connection Error', text, function()
      errorBox = nil
      CharacterList.showAgain()
    end)
  end
  scheduleAutoReconnect()
end

local function onGameUpdateNeeded(_)
  destroyLoadBox()
  errorBox = setErrorBox('Update needed', tr('Enter with your account again to update your client.'), function()
    errorBox = nil
    CharacterList.showAgain()
  end)
end

local function onGameEnd()
  CharacterList.showAgain()
  scheduleAutoReconnect()
end

local function onLogout()
  lastLogout = nowMillis()
end

-- =====================[ API Público ]=====================
function CharacterList.init()
  if USE_NEW_ENERGAME then return end

  connect(g_game, {
    onLoginError      = onGameLoginError,
    onLoginToken      = onGameLoginToken,
    onUpdateNeeded    = onGameUpdateNeeded,
    onConnectionError = onGameConnectionError,
    onGameStart       = CharacterList.destroyLoadBox,
    onLoginWait       = onLoginWait,
    onGameEnd         = onGameEnd,
    onLogout          = onLogout
  })

  if G.characters then
    CharacterList.create(G.characters, G.characterAccount)
  end
end

function CharacterList.terminate()
  if USE_NEW_ENERGAME then return end

  disconnect(g_game, {
    onLoginError      = onGameLoginError,
    onLoginToken      = onGameLoginToken,
    onUpdateNeeded    = onGameUpdateNeeded,
    onConnectionError = onGameConnectionError,
    onGameStart       = CharacterList.destroyLoadBox,
    onLoginWait       = onLoginWait,
    onGameEnd         = onGameEnd,
    onLogout          = onLogout
  })

  if ui then listWidget = nil; ui:destroy(); ui = nil end
  destroyLoadBox()
  if waitingWindow then waitingWindow:destroy(); waitingWindow = nil end

  updateWaitEvent    = destroyEvent(updateWaitEvent)
  resendWaitEvent    = destroyEvent(resendWaitEvent)
  loginEvent         = destroyEvent(loginEvent)
  autoReconnectEvent = destroyEvent(autoReconnectEvent)

  CharacterList = nil
end

function CharacterList.create(characters, account, otui)
  otui = otui or 'characterlist'
  if ui then ui:destroy() end

  ui                = g_ui.displayUI(otui)
  listWidget        = W('characters')
  autoReconnectButton = W('autoReconnect')
  switchPanel('listPanel')

  G.characters       = characters or {}
  G.characterAccount = account or {}

  listWidget:destroyChildren()
  local focusLabel

  for i, info in ipairs(G.characters) do
    local item = g_ui.createWidget('CharacterWidget', listWidget)

    local nameLabel = item:recursiveGetChildById('name')
    if nameLabel then nameLabel:setText(info.name or 'Unknown') end

    local levelLabel = item:recursiveGetChildById('level')
    if levelLabel then levelLabel:setText('Level: ' .. (info.level or '??')) end

    local vocationLabel = item:recursiveGetChildById('vocation')
    if vocationLabel then
      if info.vocationName then
        vocationLabel:setText(info.vocationName)
      else
        vocationLabel:setText('Vocation: ??')
      end
    end

    local worldLabel = item:recursiveGetChildById('worldName')
    if worldLabel then worldLabel:setText('(' .. (info.worldName or '') .. ')') end

    local outfitWidget = item:recursiveGetChildById('outfit')
    if outfitWidget then
      if info.outfit then outfitWidget:setOutfit(info.outfit)
      elseif info.looktype then outfitWidget:setOutfit({ type = info.looktype }) end
      outfitWidget:setAnimate(false)
      outfitWidget:setSize('80 80')
    end

    item.characterName = info.name
    item.worldName     = info.worldName
    item.worldHost     = info.worldHost or info.worldIp or info.host
    item.worldPort     = tonumber(info.worldPort or info.port)

    connect(item, { onDoubleClick = function() CharacterList.doLogin() return true end })

    if i == 1 or (g_settings.get('last-used-character') == item.characterName and g_settings.get('last-used-world') == item.worldName) then
      focusLabel = item
    end
  end

  if focusLabel then
    listWidget:focusChild(focusLabel, KeyboardFocusReason)
    addEvent(function() listWidget:ensureChildVisible(focusLabel) end)
  end

  listWidget.onChildFocusChange = function()
    autoReconnectEvent = destroyEvent(autoReconnectEvent)
  end

  local accountStatusLabel = W('accountStatusLabel')
  if accountStatusLabel and account then
    local status = ''
    if account.status == AccountStatus.Frozen    then status = tr(' (Frozen)')    end
    if account.status == AccountStatus.Suspended then status = tr(' (Suspended)') end

    if account.subStatus == SubscriptionStatus.Free and account.premDays < 1 then
      accountStatusLabel:setText(('%s%s'):format(tr('Free Account'), status))
    else
      if account.premDays == 0 or account.premDays == 65535 then
        accountStatusLabel:setText(('%s%s'):format(tr('Gratis Premium Account'), status))
      else
        accountStatusLabel:setText(('%s%s'):format(tr('Premium Account (%s) days left', account.premDays), status))
      end
    end
    accountStatusLabel:setOn(account.premDays > 0 and account.premDays <= 7)
  end

  if autoReconnectButton then
    autoReconnectButton.onClick = function()
      local on = not g_settings.getBoolean('autoReconnect', true)
      autoReconnectButton:setOn(on)
      g_settings.set('autoReconnect', on)
    end
    autoReconnectButton:setOn(g_settings.getBoolean('autoReconnect', true))
  end
end

function CharacterList.destroy()
  if ui then listWidget = nil; ui:destroy(); ui = nil end
end

function CharacterList.show()
  if loadBox or errorBox or not ui then return end
  ui:show(); ui:raise(); ui:focus()
  if autoReconnectButton then
    autoReconnectButton:setOn(g_settings.getBoolean('autoReconnect', true))
  end
end

function CharacterList.hide(showLogin)
  autoReconnectEvent = destroyEvent(autoReconnectEvent)
  if ui then ui:hide() end
  if showLogin and EnterGame and not g_game.isOnline() then EnterGame.show() end
end

function CharacterList.showAgain()
  if listWidget and listWidget:hasChildren() then CharacterList.show() end
end

function CharacterList.isVisible()
  return ui and ui:isVisible() or false
end

function CharacterList.doLogin()
  autoReconnectEvent = destroyEvent(autoReconnectEvent)
  local selected = listWidget and listWidget:getFocusedChild()
  if not selected then
    setErrorBox('Error', tr('You must select a character to login!'))
    return
  end

  if ui then ui:hide() end
  loginEvent = destroyEvent(loginEvent)
  tryLogin({
    worldHost     = selected.worldHost or selected.worldIp or selected.host,
    worldPort     = tonumber(selected.worldPort or selected.port or 7172),
    worldName     = selected.worldName or selected.world or 'Ascension',
    characterName = selected.characterName or selected.name or 'Unknown'
  })
end

function CharacterList.destroyLoadBox()
  destroyLoadBox()
end

function CharacterList.cancelWait()
  if waitingWindow then waitingWindow:destroy(); waitingWindow = nil end
  updateWaitEvent = destroyEvent(updateWaitEvent)
  resendWaitEvent = destroyEvent(resendWaitEvent)
  destroyLoadBox()
  CharacterList.showAgain()
end

-- =====================[ Vocações / Create Char ]=====================
local function buildVocationGrid(list)
  local listUI = W('vocationList')
  if not listUI then return end
  listUI:destroyChildren()
  selectedVocCard = nil

  local firstSelect

  for _, v in ipairs(list) do
    local card = g_ui.createWidget('VocationCard', listUI)
    local name = card:getChildById('vocName')
    if name then name:setText(v.name or ('ID ' .. v.id)) end
    local oc = card:getChildById('vocOutfit')
    if oc and v.newtype then oc:setOutfit({ type = v.newtype }); oc:setAnimate(false) end

    local function select()
      selectedVocationId   = tonumber(v.id)
      selectedNewtypeId    = tonumber(v.newtype)
      selectedVocationName = v.name

      if selectedVocCard and selectedVocCard ~= card then
        selectedVocCard:setOn(false)
        local old = selectedVocCard:getChildById('selBorder')
        if old then old:setVisible(false) end
      end

      selectedVocCard = card
      selectedVocCard:setOn(true)
      local border = card:getChildById('selBorder')
      if border then border:setVisible(true) end
    end

    connect(card, { onClick = select, onMouseRelease = select })
    if oc   then connect(oc,   { onClick = select, onMouseRelease = select }) end
    if name then connect(name, { onClick = select, onMouseRelease = select }) end

    if not firstSelect then firstSelect = select end
  end

  if firstSelect then firstSelect() end
end

local function loadVocations()
  apiPost('get_vocations', {}, function(res, err)
    if err or not res then return end
    local raw = res.vocations or res.list or res.data or res
    if type(raw) ~= 'table' then return end

    local list = {}
    for k, v in pairs(raw) do
      if type(v) == 'table' then
        local id      = tonumber(v.id or k)
        local name    = v.name or v.vocation or v.title or ('Vocation ' .. tostring(id or k))
        local newtype = tonumber(v.newtype or v.looktype or v.type)
        if id then
          list[#list+1] = { id = id, name = name, newtype = newtype }
          VOCATION_INDEX.byId[id] = { name = name, newtype = newtype }
          if name then VOCATION_INDEX.byName[(name .. ''):lower()] = id end
        end
      elseif tonumber(k) and type(v) == 'string' then
        local id = tonumber(k)
        list[#list+1] = { id = id, name = v, newtype = nil }
        VOCATION_INDEX.byId[id] = { name = v, newtype = nil }
        VOCATION_INDEX.byName[v:lower()] = id
      end
    end

    table.sort(list, function(a, b) return (a.id or 1e9) < (b.id or 1e9) end)
    if #list > 0 then buildVocationGrid(list) end
  end)
end

function Createchar()
  switchPanel('createCharacterPanel')
  loadVocations()
  fetchCaptcha('CaptchaLabel')
end

function CreateCharacter.showVocationPopup() end

function CreateCharacter.cancel()
  switchPanel('listPanel')
end

function CreateCharacter.submit()
  if createCharSubmitting then return end

  local nameField    = W('characterNameText')
  local captchaField = W('CaptchaText')
  if not nameField or not captchaField then
    setErrorBox('Erro', tr('Campos obrigatórios não encontrados.'))
    return
  end

  local name    = (nameField:getText() or ''):trim()
  local captcha = (captchaField:getText() or ''):trim()

  if name:len() < 3 then
    setErrorBox('Erro', tr('O nome do personagem deve ter pelo menos 3 letras.'))
    return
  end
  if not selectedVocationId then
    setErrorBox('Erro', tr('Você deve selecionar uma vocação.'))
    return
  end
  if captcha == '' then
    setErrorBox('Erro', tr('Você deve digitar o captcha.'))
    return
  end

  local payload = {
    action         = 'create_character',
    character_name = name,
    vocation       = tonumber(selectedVocationId),
    vocation_id    = tonumber(selectedVocationId),
    vocationName   = selectedVocationName,
    vocation_name  = selectedVocationName,
    newtype        = tonumber(selectedNewtypeId),
    looktype       = tonumber(selectedNewtypeId),
    account_name   = G.account,
    token          = captchaToken,
    captcha        = captcha,
    mac            = getMac()
  }

  createCharSubmitting = true
  apiPost('create_character', payload, function(result, err)
    createCharSubmitting = false
    if err then
      setErrorBox('Erro', tr('Falha de comunicação com o servidor.'))
      return
    end

    if result and result.success then
      setInfoBox('Sucesso', 'Seu personagem foi criado!').onOk = function()
        switchPanel('listPanel')
        CharacterList.refreshFromApi()
        if ui then ui:show(); ui:raise(); ui:focus() end
        CharacterList.hide(true)
      end
    else
      local msg = result and (result.error or 'Erro desconhecido') or 'Erro desconhecido'
      if msg:lower():find('captcha expirado') then
        fetchCaptcha('CaptchaLabel')
      else
        setErrorBox('Erro', tr(msg))
      end
    end
  end)
end

-- =====================[ Delete Character ]=====================
local function updateDeleteButtonState()
  local btn = W('confirmDelete')
  local p1  = W('PasswordConfirm')
  local p2  = W('PasswordConfirm2')
  local ok  = selectedCharacterId and p1 and p2 and p1:getText():len() > 0 and (p1:getText() == p2:getText())
  if btn then btn:setEnabled(ok and true or false) end
end

local function buildDeleteCharGrid(chars)
  local grid = W('deleteCharList')
  if not grid then return end
  grid:destroyChildren()

  local deleteBtn = W('confirmDelete')
  if deleteBtn then deleteBtn:setEnabled(#(chars or {}) > 0) end

  local lastCard, firstSelect

  for _, ch in ipairs(chars or {}) do
    local card = g_ui.createWidget('CharCard', grid)

    local name = card:getChildById('charName')
    if name then name:setText(ch.name or ('ID ' .. (ch.id or '?'))) end

    local oc = card:getChildById('charOutfit')
    if oc then
      local look = tonumber(ch.looktype) or 128
      oc:setOutfit({ type = look })
      oc:setAnimate(false)
    end

    local function select()
      selectedCharacterId   = tonumber(ch.id)
      selectedCharacterName = ch.name

      if lastCard and lastCard ~= card then
        lastCard:setOn(false)
        local old = lastCard:getChildById('selBorder')
        if old then old:setVisible(false) end
      end

      lastCard = card
      card:setOn(true)
      local border = card:getChildById('selBorder')
      if border then border:setVisible(true) end

      if deleteBtn then deleteBtn:setEnabled(true) end
      updateDeleteButtonState()
    end

    connect(card, { onClick = select, onMouseRelease = select })
    if oc   then connect(oc,   { onClick = select, onMouseRelease = select }) end
    if name then connect(name, { onClick = select, onMouseRelease = select }) end

    if not firstSelect then firstSelect = select end
  end

  if firstSelect then firstSelect() end
end

local function loadCharactersForDeletion()
  apiPost('get_chars', { account_name = G.account }, function(res, err)
    if err or not res or not res.success then return end
    buildDeleteCharGrid(res.characters or {})
  end)
end

function DeleteCharacter.showCharacterPopup()
  local popup = W('deleteCharacterCombo')
  if not popup then return end
  popup:setVisible(not popup:isVisible())
  if popup:isVisible() then popup:raise() end
end

function showDeleteCharacterUI()
  switchPanel('deleteCharacterPanel')
  local p1, p2 = W('PasswordConfirm'), W('PasswordConfirm2')
  if p1 then p1:setText('') end
  if p2 then p2:setText('') end
  updateDeleteButtonState()

  if p1 then connect(p1, { onTextChange = updateDeleteButtonState }) end
  if p2 then connect(p2, { onTextChange = updateDeleteButtonState }) end

  loadCharactersForDeletion()
end

function closeDeleteCharacterUI()
  switchPanel('listPanel')
end

function confirmDeletion()
  if not selectedCharacterId then
    setErrorBox('Erro', tr('Selecione um personagem para deletar.'))
    return
  end

  local function yesCallback()
    if logoutWindow and not logoutWindow:isDestroyed() then logoutWindow:destroy(); logoutWindow = nil end

    local p1 = W('PasswordConfirm')
    local p2 = W('PasswordConfirm2')
    local pass1 = p1 and p1:getText() or ''
    local pass2 = p2 and p2:getText() or ''

    if pass1 == '' or pass2 == '' then
      setErrorBox('Erro', tr('Preencha os dois campos de senha.'))
      return
    end
    if pass1 ~= pass2 then
      setErrorBox('Erro', tr('As senhas não coincidem.'))
      return
    end

    apiPost('delete_character', {
      account_name = G.account,
      character_id = tonumber(selectedCharacterId),
      password     = pass1
    }, function(res, err)
      if err then
        setErrorBox('Erro', tr('Falha de comunicação com o servidor.'))
        return
      end
      if res and res.success then
        selectedCharacterId, selectedCharacterName = nil, nil
        setInfoBox('Sucesso', 'Seu personagem foi deletado!').onOk = function()
          CharacterList.hide(true)
          if EnterGame then addEvent(function() EnterGame.show() end) end
        end
      else
        setErrorBox('Erro', tostring(res and (res.error or 'Erro desconhecido') or 'Erro desconhecido'))
      end
    end)
  end

  local function noCallback()
    if logoutWindow and not logoutWindow:isDestroyed() then logoutWindow:destroy(); logoutWindow = nil end
  end

  local msg = 'Tem certeza que deseja deletar o personagem ' .. (selectedCharacterName or '?') .. '?'
  logoutWindow = displayGeneralBox(tr('Confirmacao'), tr(msg), {
    { text = tr('Sim'), callback = yesCallback },
    { text = tr('Nao'), callback = noCallback },
    anchor = AnchorHorizontalCenter
  }, yesCallback, noCallback)
end

-- =====================[ Alterar Senha ]=====================
function showAlterarSenhaUI()
  switchPanel('changePasswordPanel')

  -- pré-preenche com dados do login imediatamente
  local acc = (G and G.characterAccount) or {}
  setLabelText('EmailValue', acc.email)
  setLabelText('RecoveryKeyValue', acc.recoveryKey)

  -- tenta atualizar via API (sem apagar valores)
  fetchAccountInfo()

  -- captcha da troca de senha
  fetchCaptcha('CaptchaLabelCP')
end



function closeAlterarSenhaUI()
  switchPanel('listPanel')
end

function changePassword()
  local oldField = W('OldPassword')
  local newField = W('NewPassword')
  local capField = W('CaptchaTextCP')

  if not oldField or not newField or not capField then
    setErrorBox('Erro', tr('Campos obrigatórios não encontrados.')); return
  end

  local oldPass = oldField:getText() or ''
  local newPass = newField:getText() or ''
  local captcha = capField:getText() or ''

  if newPass:len() < 6 then
    setErrorBox('Erro', tr('A nova senha deve ter ao menos 6 caracteres.')); return
  end
  if captcha == '' then
    setErrorBox('Erro', tr('Você deve digitar o captcha.')); return
  end

  apiPost('change_password', {
    account_name = G.account,
    old_password = oldPass,
    new_password = newPass,
    token        = captchaToken,  -- << usa token atual
    captcha      = captcha,       -- << texto digitado
    mac          = getMac()
  }, function(res, err)
    if err then
      setErrorBox('Erro', tr('Falha na requisição: ') .. err); return
    end
    if res and res.success then
      setInfoBox('Sucesso', 'Senha alterada com êxito.')
      closeAlterarSenhaUI()
    else
      local msg = (res and res.error) or tr('Erro desconhecido.')
      if msg:lower():find('captcha') then
        fetchCaptcha('CaptchaLabelCP')  -- << renova captcha se deu ruim
      end
      setErrorBox('Erro', msg)
    end
  end)
end

-- =====================[ Atualizar lista ]=====================
function CharacterList.refreshFromApi()
  if not G or not G.account or #G.account == 0 then return end
  apiPost('get_chars', { account_name = G.account }, function(res, err)
    if err then return end
    if res and res.success then
      G.characters = res.characters or {}
      if ui then
        CharacterList.create(G.characters, G.characterAccount)
        switchPanel('listPanel')
      end
    end
  end)
end
