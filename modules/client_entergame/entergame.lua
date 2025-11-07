-- =========================================================
-- EnterGame (login via API + compat Tibia12; TCP fallback)
-- =========================================================
EnterGame = {}

-- =====================[ Estado / Locais ]=====================
local loadBox
local enterGame
local enterGameButton
local clientBox
local protocolLogin
local server = nil
local versionsFound = false

local customServerSelectorPanel
local serverSelectorPanel
local serverSelector
local clientVersionSelector
local serverHostTextEdit
local rememberPasswordBox

local protos = {
  "860"
}

local checkedByUpdater = {}

-- Variável global para captcha token
local captchaToken = nil

-- =====================[ API config ]=====================
-- Se quiser travar o endpoint: defina API_BASE e ignore o campo de host.
-- Caso contrario, usaremos o que o usuario escrever em G.host.
local API_BASE = "https://ntoascension.com/createAccount.php" or nil  -- exemplo: "https://191.101.78.116/createAccount.php"
local sessionCookie = rawget(_G, "sessionCookie") or nil

-- =====================[ Helpers ]=====================
-- Busca recursiva segura
local function R(id)
  return enterGame and enterGame:recursiveGetChildById(id) or nil
end

-- Texto seguro de widget (string)
local function T(w)
  return (w and w:getText()) or ""
end

-- number seguro de widget (ou de string)
local function TN(s, fallback)
  local n = tonumber(type(s) == "string" and s or (s and s:getText()))
  return n or fallback
end

local function W(id)
  return enterGame and enterGame:recursiveGetChildById(id)
end

-- Tornar W acessível globalmente para funções chamadas do OTUI
_G.W = W

local function infoBox(title, msg, onOk)
  local b = displayInfoBox(tr(title), tr(msg))
  if onOk then b.onOk = onOk end
  return b
end

local function errorBox(title, msg, onOk)
  local b = displayErrorBox(tr(title), msg)
  if onOk then b.onOk = onOk end
  return b
end

-- Tornar funções auxiliares acessíveis globalmente para funções chamadas do OTUI
_G.infoBox = infoBox
_G.errorBox = errorBox

local function chooseApiUrl()
  if type(API_BASE) == "string" and #API_BASE > 6 then
    return API_BASE
  end
  local h = (G and G.host) or ""
  if h:lower():find("^http") then
    return h
  end
  -- fallback amigavel local
  return "http://127.0.0.1/createAccount.php"
end

local function apiPostJSON(url, payload, cb, extraHeaders)
  local headers = extraHeaders or {}
  if sessionCookie then headers["Cookie"] = sessionCookie end

  HTTP.postJSON(url, payload, function(data, err, headersOut)
    if err then cb(nil, err, headersOut); return end
    local result = type(data) == "table" and data or json.decode(data)

    -- capturar cookie de sessao (se o backend usar)
    if headersOut then
      for k,v in pairs(headersOut) do
        if string.lower(k) == "set-cookie" then
          sessionCookie = v:match("^(.-);") or v
          break
        end
      end
    end
    cb(result, nil, headersOut)
  end, headers)
end

-- =====================[ NORMALIZACAO DO SERVERS ]=====================
-- PATCH: aceita array de objetos ({ {name=..., address=...}, ... }) ou mapa { ["Nome"]="addr" }
local ServersList = {}   -- array de { name=..., address=... }
local ServersByName = {} -- mapa name -> address

local function normalizeServers()
  ServersList = {}
  ServersByName = {}

  if type(Servers) ~= "table" then return end

  local isArray = (#Servers > 0 and type(Servers[1]) == "table" and (Servers[1].name or Servers[1].address)) and true or false
  if isArray then
    for _, s in ipairs(Servers) do
      local name = tostring(s.name or "")
      local addr = tostring(s.address or "")
      if name ~= "" and addr ~= "" then
        table.insert(ServersList, { name = name, address = addr })
        ServersByName[name] = addr
      end
    end
  else
    for k, v in pairs(Servers) do
      local name, addr
      if type(k) == "string" and type(v) == "string" then
        name, addr = k, v
      elseif type(v) == "table" then
        name = tostring(v.name or k or "")
        addr = tostring(v.address or "")
      end
      if name and name ~= "" and addr and addr ~= "" then
        table.insert(ServersList, { name = name, address = addr })
        ServersByName[name] = addr
      end
    end
    table.sort(ServersList, function(a,b) return a.name:lower() < b.name:lower() end)
  end
end

local function getServerAddressByName(name)
  return ServersByName and ServersByName[name] or nil
end

-- chama na carga
normalizeServers()

-- =====================[ Protocol / Features ]=====================
local function onProtocolError(_protocol, message, errorCode)
  if errorCode then return EnterGame.onError(message) end
  return EnterGame.onLoginError(message)
end

local function onSessionKey(_protocol, sessionKey)
  G.sessionKey = sessionKey
end

local function onProxyList(_protocol, proxies)
  for _, proxy in ipairs(proxies or {}) do
    g_proxy.addProxy(proxy["host"], proxy["port"], proxy["priority"])
  end
end

local function parseFeatures(features)
  for feature_id, value in pairs(features or {}) do
    local on = (value == "1" or value == "true" or value == true)
    if on then g_game.enableFeature(feature_id) else g_game.disableFeature(feature_id) end
  end
end

local function validateThings(things)
  -- Aceita ambos: {"data"={"860/Tibia.dat","<checksum>"}, "sprites"={"860/Tibia.cwm","<checksum>"}}
  -- ou "Tibia.spr"
  local incorrectThings, missingFiles, versionForMissingFiles = "", false, 0
  if things ~= nil then
    local thingsNode = {}
    for _kind, arr in pairs(things) do
      local fname = arr[1]
      thingsNode[_kind] = fname
      local path = "/things/" .. fname
      if not g_resources.fileExists(path) then
        incorrectThings = incorrectThings .. "Missing file: " .. fname .. "\n"
        missingFiles = true
        versionForMissingFiles = fname:split("/")[1]
      else
        local localChecksum = g_resources.fileChecksum(path):lower()
        local wantChecksum  = (arr[2] or ""):lower()
        
        -- Verificar se estamos em HD Mode com arquivos zipados
        local isHDMode = g_app.isHDMode and g_app:isHDMode()
        local isFromArchive = g_resources.isLoadedFromArchive()
        
        if localChecksum ~= wantChecksum and #wantChecksum > 1 then
          if g_resources.isLoadedFromArchive() then
            -- Em arquivos zipados, ser mais tolerante com checksums
            if isHDMode then
              -- HD Mode com arquivos zipados pode ter checksums diferentes
              -- apenas avisar mas não bloquear
              print("Warning: Checksum mismatch for " .. fname .. " in HD Mode with compressed files")
            else
              incorrectThings = incorrectThings ..
                "Invalid checksum of file: " .. fname ..
                " (is " .. localChecksum .. ", should be " .. wantChecksum .. ")\n"
            end
          end
        end
      end
    end
    g_settings.setNode("things", thingsNode)
  else
    g_settings.setNode("things", {})
  end

  if missingFiles then
    incorrectThings = incorrectThings ..
      ("\nYou should open data/things and create directory %s.\n" ..
       "In this directory (data/things/%s) you should put missing\n" ..
       "files (Tibia.dat and Tibia.spr/Tibia.cwm) from correct Tibia version."):format(versionForMissingFiles, versionForMissingFiles)
  end
  return incorrectThings
end

-- =====================[ Character List handler ]=====================
local function onCharacterList(_protocol, characters, account, otui)
  if rememberPasswordBox and rememberPasswordBox.isChecked and rememberPasswordBox:isChecked() then
    g_settings.set('account',  g_crypt.encrypt(G.account))
    g_settings.set('password', g_crypt.encrypt(G.password))
  else
    -- nao salvar credenciais; nao limpar campos aqui
    g_settings.remove('account')
    g_settings.remove('password')
  end

  for _, info in pairs(characters or {}) do
    if info.previewState and info.previewState ~= PreviewState.Default then
      info.worldName = (info.worldName or "") .. ", Preview"
    end
  end

  if loadBox then loadBox:destroy(); loadBox = nil end
  CharacterList.create(characters or {}, account or {}, otui)
  CharacterList.show()
  g_settings.save()
end


-- =====================[ API responses ]=====================
local function applyServerDataAndGo(data)
  -- Erros comuns
  if data['error'] and #data['error'] > 0 then
    return EnterGame.onLoginError(data['error'])
  end
  if data['errorMessage'] and #data['errorMessage'] > 0 then
    return EnterGame.onLoginError(data['errorMessage'])
  end

  -- Caso 'Tibia12 style': session + playdata
  if type(data["session"]) == "table" and type(data["playdata"]) == "table" then
    local session  = data["session"]
    local playdata = data["playdata"]

    -- monta account (status/premium)
    local account = { status = 0, subStatus = 0, premDays = 0 }
    if session["status"] ~= "active" then account.status = 1 end
    if session["ispremium"] then account.subStatus = 1 end
    if tonumber(session["premiumuntil"] or 0) > g_clock.seconds() then
      account.subStatus = math.floor((session["premiumuntil"] - g_clock.seconds()) / 86400)
    end

    -- mundos
    local worlds = {}
    for _, w in pairs(playdata["worlds"] or {}) do
      worlds[w.id] = {
        name    = w.name,
        port    = w.externalportunprotected or w.externalportprotected or w.externaladdress,
        address = w.externaladdressunprotected or w.externaladdressprotected or w.externalport
      }
    end

    -- characters
    local characters = {}
    for _, ch in pairs(playdata["characters"] or {}) do
      local w = worlds[ch.worldid]
      if w then
        table.insert(characters, {
          name      = ch.name,
          worldName = w.name,
          worldIp   = w.address,
          worldPort = w.port
        })
      end
    end

    -- proxies
    if g_proxy then
      g_proxy.clear()
      for _, p in ipairs(playdata["proxies"] or {}) do
        g_proxy.addProxy(p["host"], tonumber(p["port"]), tonumber(p["priority"]))
      end
    end

    -- versao/protocolo
    g_game.setCustomProtocolVersion(0)
    g_game.chooseRsa(G.host)
    g_game.setClientVersion(G.clientVersion)
    g_game.setProtocolVersion(g_game.getClientProtocolVersion(G.clientVersion))
    g_game.setCustomOs(-1)
    if not g_game.getFeature(GameExtendedOpcode) then
      g_game.setCustomOs(5) -- windows (safe)
    end

    onSessionKey(nil, session["sessionkey"])
    return onCharacterList(nil, characters, account, nil)
  end

  -- Caminho padrao (nosso API)
  local version        = tonumber(data["version"] or G.clientVersion or 860)
  local things         = data["things"]
  local customProtocol = tonumber(data["customProtocol"] or 0)
  local features       = data["features"]
  local settings       = data["settings"]
  local rsa            = data["rsa"]
  local proxies        = data["proxies"]
  local session        = data["session"]
  local characters     = data["characters"] or {}
  local account        = data["account"] or {}

  -- Validar/registrar things (se vier)
  if things then
    local err = validateThings(things)
    if #err > 0 then
      -- Se voce usa Updater, pode acionar aqui. Por simplicidade, erro direto:
      return EnterGame.onError(err)
    end
  end

  -- Custom protocol
  g_game.setCustomProtocolVersion(0)
  if customProtocol and customProtocol > 0 then
    g_game.setCustomProtocolVersion(customProtocol)
  end

  -- Forcar opcoes do jogador (se o servidor quiser)
  if settings ~= nil then
    for option, value in pairs(settings) do
      modules.client_options.setOption(option, value, true)
    end
  end

  -- Versao/Protocolo/OS
  G.clientVersion = version
  g_game.setClientVersion(version)
  g_game.setProtocolVersion(g_game.getClientProtocolVersion(version))
  g_game.setCustomOs(-1)

  -- RSA custom (opcional)
  if rsa ~= nil then g_game.setRsa(rsa) end

  -- Features do servidor
  parseFeatures(features)

  -- SessionKey simples (string)
  if type(session) == "string" and #session > 0 then
    onSessionKey(nil, session)
  end

  -- Proxies
  if g_proxy then
    g_proxy.clear()
    for _, p in ipairs(proxies or {}) do
      g_proxy.addProxy(p["host"], tonumber(p["port"]), tonumber(p["priority"]))
    end
  end

  return onCharacterList(nil, characters, account, nil)
end

-- =====================[ HTTP Login ]=====================
local function doHttpLoginRequest()
  local url = chooseApiUrl()
  if not url or #url < 10 then
    return EnterGame.onError("Invalid server url: " .. tostring(url))
  end

  loadBox = displayCancelBox(tr('Please wait'), tr('Connecting to login server...'))
  connect(loadBox, { onCancel = function()
    loadBox = nil
    EnterGame.show()
  end })

  -- Payload minimo canonico (o seu backend aceita diversos aliases;
  -- aqui usamos os campos mais comuns)
  local payload = {
    type     = "login",
    account  = G.account,
    password = G.password,
    version  = APP_VERSION,
    uid      = G.UUID,
    stayloggedin = true
  }

  -- Se seu backend exige action/login sem "type": mude para { action="login", ... }
  -- payload.action = "login"

  apiPostJSON(url, payload, function(result, err)
    if err then
      return EnterGame.onError(err)
    end
    -- sucesso ? interpreta estrutura e abre CharacterList
    applyServerDataAndGo(result)
  end)

  EnterGame.hide()
end

-- =====================[ Public / UI ciclo ]=====================
function EnterGame.init()
  if USE_NEW_ENERGAME then return end
  enterGame = g_ui.displayUI('entergame')

   -- ===== Widgets (robusto contra ausencia de paineis/filhos) =====
  serverSelectorPanel       = R('serverSelectorPanel')                      -- pode ser nil
  customServerSelectorPanel = R('customServerSelectorPanel')                -- pode ser nil

  -- serverSelector pode estar dentro do panel OU direto na raiz/arvore
  serverSelector = (serverSelectorPanel and serverSelectorPanel:getChildById('serverSelector')) or R('serverSelector')
  rememberPasswordBox   = R('rememberPasswordBox') or enterGame:getChildById('rememberPasswordBox')
  -- clientVersionSelector idem: pode estar dentro do custom panel ou solto
  clientVersionSelector = (customServerSelectorPanel and customServerSelectorPanel:getChildById('clientVersionSelector')) or R('clientVersionSelector')
  serverHostTextEdit    = (customServerSelectorPanel and customServerSelectorPanel:getChildById('serverHostTextEdit'))    or R('serverHostTextEdit')

  -- ===== Popular combos apenas se existirem =====
  if serverSelector then
    serverSelector:clearOptions() -- PATCH: garantir limpeza
    for _, s in ipairs(ServersList) do
      serverSelector:addOption(s.name) -- PATCH: nomes reais
    end
    if serverSelector:getOptionsCount() == 0 or ALLOW_CUSTOM_SERVERS then
      serverSelector:addOption(tr("Another"))
    end
  end

  if clientVersionSelector then
    for _,proto in ipairs(protos) do
      clientVersionSelector:addOption(proto)
    end
  end

  -- Se so ha um servidor e o painel existe, esconda-o
  if serverSelector and serverSelectorPanel and serverSelector:getOptionsCount() == 1 then
    enterGame:setHeight(enterGame:getHeight() - serverSelectorPanel:getHeight())
    serverSelectorPanel:setOn(false)
  end

  -- ===== Preferencias salvas =====
  local savedAccount       = g_crypt.decrypt(g_settings.get('account'))
  local savedPassword      = g_crypt.decrypt(g_settings.get('password'))
  local savedServerName    = g_settings.get('server')
  local savedHost          = g_settings.get('host')
  local savedClientVersion = g_settings.get('client-version')

  if serverSelector and savedServerName and serverSelector:isOption(savedServerName) then
    serverSelector:setCurrentOption(savedServerName, false)
    -- PATCH: preencher host pelo nome salvo (se existir)
    local addr = getServerAddressByName(savedServerName)
    if addr and serverHostTextEdit then
      serverHostTextEdit:setText(addr)
    elseif serverHostTextEdit then
      serverHostTextEdit:setText(savedHost or "")
    end
    if clientVersionSelector and savedClientVersion then
      clientVersionSelector:setOption(savedClientVersion)
    end
  else
    -- fallback 'em branco' quando nao existe seletor
    savedServerName = ""
    savedHost = savedHost or ""
    if serverHostTextEdit then serverHostTextEdit:setText(savedHost) end
  end

  local pwEdit  = R('accountPasswordTextEdit')
  local accEdit = R('accountNameTextEdit')
  if pwEdit  then pwEdit:setText(savedPassword or "") end
  if accEdit then accEdit:setText(savedAccount or "") end
  if rememberPasswordBox then rememberPasswordBox:setChecked(savedAccount and #savedAccount > 0) end

  g_keyboard.bindKeyDown('Ctrl+G', EnterGame.openWindow)

  if g_game.isOnline() then
    return EnterGame.hide()
  end

  scheduleEvent(function() EnterGame.show() end, 100)
end

function EnterGame.terminate()
  if not enterGame then return end
  g_keyboard.unbindKeyDown('Ctrl+G')

  enterGame:destroy()
  if loadBox then loadBox:destroy(); loadBox = nil end
  if protocolLogin then protocolLogin:cancelLogin(); protocolLogin = nil end
  EnterGame = nil
end

function EnterGame.show()
  if not enterGame or enterGame:isDestroyed() then return end
  enterGame:show()
  enterGame:raise()
  enterGame:focus()

  -- procura em toda a hierarquia; se nao achar, nao crasha
  local acc = enterGame:recursiveGetChildById('accountNameTextEdit')
              or enterGame:getChildById('accountNameTextEdit')
  if acc then
    acc:focus()
  end
end

function EnterGame.hide()
  if not enterGame or enterGame:isDestroyed() then return end
  enterGame:hide()
end


function EnterGame.openWindow()
  if g_game.isOnline() then
    CharacterList.show()
  elseif not g_game.isLogging() and not CharacterList.isVisible() then
    EnterGame.show()
  end
end

function EnterGame.clearAccountFields()
  enterGame:getChildById('accountNameTextEdit'):clearText()
  enterGame:getChildById('accountPasswordTextEdit'):clearText()
  enterGame:getChildById('accountNameTextEdit'):focus()
  g_settings.remove('account')
  g_settings.remove('password')
end

function EnterGame.onServerChange()
  if not serverSelector then return end
  server = serverSelector:getText()

  if server == tr("Another") then
    if customServerSelectorPanel and not customServerSelectorPanel:isOn() then
      if serverHostTextEdit then serverHostTextEdit:setText("") end
      customServerSelectorPanel:setOn(true)
      enterGame:setHeight(enterGame:getHeight() + customServerSelectorPanel:getHeight())
    end
  elseif customServerSelectorPanel and customServerSelectorPanel:isOn() then
    enterGame:setHeight(enterGame:getHeight() - customServerSelectorPanel:getHeight())
    customServerSelectorPanel:setOn(false)
  end

  -- PATCH: preencher host via nome -> address
  local addr = getServerAddressByName(server)
  if addr and serverHostTextEdit then
    serverHostTextEdit:setText(addr)
  end
end

-- =====================[ Login ]=====================
function EnterGame.doLogin(account, password, token, host)
  if g_game.isOnline() then
    local b = displayErrorBox(tr('Login Error'), tr('Cannot login while already in game.'))
    connect(b, { onOk = EnterGame.show })
    return
  end

  -- Widgets (tolerantes a ausencia)
  local accEdit  = R('accountNameTextEdit')
  local pwEdit   = R('accountPasswordTextEdit')
  -- esses tres podem nao existir dependendo do seu OTUI
  -- por isso, sempre passamos por T() / TN()
  -- e damos defaults.
  -- se existirem paineis, voce ja tem referencias globais; se nao, busco via R().
  local serverSel = _G.serverSelector or R('serverSelector')
  local hostEdit  = _G.serverHostTextEdit or R('serverHostTextEdit')
  local versSel   = _G.clientVersionSelector or R('clientVersionSelector')

  -- Coleta credenciais
  G.account = account or T(accEdit)
  G.password = password or T(pwEdit)
  G.stayLogged = true

  -- Server / Host / Versao com fallback seguro
  local serverText = T(serverSel)
  G.server = (serverText ~= "" and (serverText.trim and serverText:trim() or serverText)) or ""

  -- host vindo de param, do edit, ou vazio (quando usa API fixa)
  G.host = host or T(hostEdit)
  -- PATCH: se host vazio, tenta pelo nome escolhido
  if (not G.host or G.host == "") and G.server and G.server ~= tr("Another") then
    local addr = getServerAddressByName(G.server)
    if addr then G.host = addr end
  end

  -- versao do combo, senao ultimo proto da lista, senao 860
  local defaultProto = protos and protos[#protos] or "860"
  G.clientVersion = TN(versSel, tonumber(defaultProto)) or 860

  -- Salva preferencias apenas se o 'remember login' estiver marcado
  if rememberPasswordBox and rememberPasswordBox.isChecked and rememberPasswordBox:isChecked() then
    g_settings.set('account',  g_crypt.encrypt(G.account))
    g_settings.set('password', g_crypt.encrypt(G.password))
  else
    g_settings.remove('account')
    g_settings.remove('password')
  end

  g_settings.set('host', G.host)
  g_settings.set('server', G.server)
  g_settings.set('client-version', G.clientVersion)
  g_settings.save()

  -- Decide rota: HTTP (API) x TCP
  local hostLower = (G.host or ""):lower()
  local useHttp = (hostLower:find("^http") ~= nil)
  -- Se voce usa API fixa, pode forcar:
  -- useHttp = true

  if useHttp then
    -- === HTTP / API ===
    local function doHttp()
      local url = (API_BASE and #API_BASE > 6) and API_BASE or G.host
      if not url or #url < 10 then
        return EnterGame.onError("Invalid server url: " .. tostring(url))
      end

      loadBox = displayCancelBox(tr('Please wait'), tr('Connecting to login server...'))
      connect(loadBox, { onCancel = function()
        loadBox = nil
        EnterGame.show()
      end })

      local payload = {
        -- ajuste os nomes conforme seu backend:
        type     = "login",
        account  = G.account,
        password = G.password,
        version  = APP_VERSION,
        uid      = G.UUID,
        stayloggedin = true
      }

      -- Se o seu backend espera 'action="login"' em vez de 'type':
      -- payload.action = "login"; payload.type = nil

      -- Usa a funcao apiPostJSON definida no arquivo (ou HTTP.postJSON direto)
      if apiPostJSON then
        apiPostJSON(url, payload, function(result, err)
          if err then
            return EnterGame.onError(err)
          end
          -- aplica dados (characters/account/version/etc.)
          local ok, errmsg = pcall(function()
            -- reaproveita sua funcao existente:
            if applyServerDataAndGo then
              applyServerDataAndGo(result)
            else
              -- fallback antigo:
              onHTTPResult(result, nil)
            end
          end)
          if not ok then
            EnterGame.onError("Parsing error: " .. tostring(errmsg))
          end
        end)
      else
        -- fallback direto
        HTTP.postJSON(url, payload, function(data, err)
          if err then
            return EnterGame.onError(err)
          end
          local result = type(data) == "table" and data or json.decode(data)
          local ok, errmsg = pcall(function()
            if applyServerDataAndGo then
              applyServerDataAndGo(result)
            else
              onHTTPResult(result, nil)
            end
          end)
          if not ok then
            EnterGame.onError("Parsing error: " .. tostring(errmsg))
          end
        end)
      end

      EnterGame.hide()
    end

    return doHttp()
  end

  -- === TCP (fallback) ===
  local server_params = (G.host or ""):split(":")
  local server_ip   = server_params[1]
  local server_port = (#server_params >= 2) and tonumber(server_params[2]) or 7171
  if #server_params >= 3 then
    G.clientVersion = tonumber(server_params[3]) or G.clientVersion
  end

  if type(server_ip) ~= 'string' or server_ip:len() <= 3 or not server_port or not G.clientVersion then
    return EnterGame.onError("Invalid server, it should be in format IP:PORT or it should be http url to login script")
  end

  protocolLogin = ProtocolLogin.create()
  protocolLogin.onLoginError    = onProtocolError
  protocolLogin.onSessionKey    = onSessionKey
  protocolLogin.onCharacterList = onCharacterList
  protocolLogin.onUpdateNeeded  = function()
    EnterGame.onError(tr('Your client needs updating, try redownloading it.'))
  end
  protocolLogin.onProxyList     = onProxyList

  EnterGame.hide()
  loadBox = displayCancelBox(tr('Please wait'), tr('Connecting to login server...'))
  connect(loadBox, { onCancel = function()
    loadBox = nil
    protocolLogin:cancelLogin()
    EnterGame.show()
  end })

  if G.clientVersion == 1000 then G.clientVersion = 1100 end
  g_game.setClientVersion(G.clientVersion)
  g_game.setProtocolVersion(g_game.getClientProtocolVersion(G.clientVersion))
  g_game.setCustomProtocolVersion(0)
  g_game.setCustomOs(-1)
  g_game.chooseRsa(G.host)
  if #server_params <= 3 and not g_game.getFeature(GameExtendedOpcode) then
    g_game.setCustomOs(2) -- windows
  end

  for i = 4, #server_params do
    local f = tonumber(server_params[i])
    if f then g_game.enableFeature(f) end
  end

  if g_proxy then g_proxy.clear() end

  if modules and modules.game_things and modules.game_things.isLoaded and modules.game_things.isLoaded() then
    protocolLogin:login(server_ip, server_port, G.account, G.password, G.authenticatorToken, G.stayLogged)
  else
    if loadBox then loadBox:destroy(); loadBox = nil end
    EnterGame.show()
  end
end

-- Mantido so para compat: agora usamos doHttpLoginRequest diretamente
function EnterGame.doLoginHttp()
  return doHttpLoginRequest()
end

-- =====================[ Erros ]=====================
function EnterGame.onError(err)
  if loadBox then loadBox:destroy(); loadBox = nil end
  local b = displayErrorBox(tr('Login Error'), err)
  b.onOk = EnterGame.show
end

function EnterGame.onLoginError(err)
  if loadBox then loadBox:destroy(); loadBox = nil end
  local b = displayErrorBox(tr('Login Error'), err)
  b.onOk = EnterGame.show
  local low = (err or ""):lower()
  if low:find("invalid") or low:find("not correct") or low:find("or password") then
    EnterGame.clearAccountFields()
  end
end

-- =====================[ Registro de Conta Embutido ]=====================
-- POST generico igual ao CharacterList: coloca 'action' no body e usa chooseApiUrl()
local function apiPost(action, payload, cb, extraHeaders)
  payload = payload or {}
  payload.action = action
  local url = chooseApiUrl()
  apiPostJSON(url, payload, cb, extraHeaders)
end

function Createaccount()
  local loginPanel  = W('loginPanel')
  local createPanel = W('createAccountPanel')
  if loginPanel  then loginPanel:setVisible(false) end
  if createPanel then createPanel:setVisible(true)  end

  apiPost("get_captcha", {}, function(result, err)
    if err then
      errorBox("Erro", tr("Falha ao obter captcha: ") .. err)
      return
    end
    if result and result.success then
      createPanel:getChildById("captchaImage"):setText(result.captcha)
      captchaToken = result.token
    else
      errorBox("Erro", tr(result and (result.error or "Erro desconhecido") or "Erro desconhecido"))
    end
  end)
end

function VoltardoCreate()
  local loginPanel  = W('loginPanel')
  local createPanel = W('createAccountPanel')
  if createPanel then createPanel:setVisible(false) end
  if loginPanel  then loginPanel:setVisible(true)  end
end

function EnviarConta()
  local panel = W('createAccountPanel'); if not panel then return end
  local conta           = panel:getChildById("accountText"):getText()
  local email           = panel:getChildById("emailText"):getText()
  local password        = panel:getChildById("passwordText"):getText()
  local captchaDigitado = panel:getChildById("captchaText"):getText()

  local addresses  = g_platform.getMacAddresses()
  local macAddress = (type(addresses) == "table" and next(addresses)) and (addresses[1] or "UNKNOWN") or "UNKNOWN"

  local payload = {
    Conta   = conta,
    Email   = email,
    Senha   = password,
    Captcha = captchaDigitado,
    token   = captchaToken,
    mac     = macAddress
  }

  apiPost("create_account", payload, function(result, err)
    if err then
      errorBox("Erro", tr("Erro ao conectar-se com o servidor."))
      return
    end
    if result and result.success then
      panel:getChildById("accountText"):clearText()
      panel:getChildById("emailText"):clearText()
      panel:getChildById("passwordText"):clearText()
      panel:getChildById("captchaText"):clearText()
      VoltardoCreate()
      infoBox("Sucesso", "Sua Conta Foi Criada!")
    else
      local msg = result and result.error or "Erro desconhecido"
      if msg:lower():find("captcha expirado") then
        infoBox("Erro", tr("Captcha expirado! Gerando um novo..."))
        apiPost("get_captcha", {}, function(r2, e2)
          if not e2 and r2 and r2.success then
            panel:getChildById("captchaImage"):setText(r2.captcha)
            captchaToken = r2.token
          else
            errorBox("Erro", tr("Nao foi possivel gerar novo captcha."))
          end
        end)
      else
        errorBox("Erro", tr(msg))
      end
    end
  end)
end
