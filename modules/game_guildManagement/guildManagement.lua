-- =========================================================
-- Guild Management UI (OTCv8) ? Clean & DRY
-- =========================================================

-- ===== Constantes / Estado =====
local OPCODE_GUILD = 201

local COLOR_WHITE  = "#FFFFFF"
local COLOR_GRAY   = "#CCCCCC"
local COLOR_GREEN  = "#00FF00"
local COLOR_RED    = "#FF0000"
local COLOR_GOLD   = "#FFD700"
local LOCK_ICON    = "images/bloqueado"

local GUILDINPUT_DEFAULT_HEIGHT  = 95
local GUILDINPUT_MAX_HEIGHT      = 320
local GUILDINPUT_EXPANDED_HEIGHT = 150

local guildManagementWindow  = nil
local guildManagementButton  = nil -- reservado (se existir botão no top menu)
local guildInputWindow       = nil
local guildInputMode         = "create"
local guildInputCallback     = nil
local joinInvitePanel        = nil
local joinInviteWidgets      = {}

local currentTab             = "membros"

-- Dados vindos do servidor
guildMembers        = guildMembers or {}
guildManagementData = guildManagementData or {}
guildHunted         = guildHunted or {}

-- Seletor de emblemas
GuildSelectionWindow = nil

-- ===== Helpers =====
local function sendOpcode(text)
  local pg = g_game.getProtocolGame()
  if pg then pg:sendExtendedOpcode(OPCODE_GUILD, text) end
end

local function wrapText(text, limit)
  limit = limit or 50
  local result, line = "", ""
  for word in text:gmatch("%S+") do
    if (#line + #word + 1) > limit then
      result = result .. line .. "\n"
      line   = word .. " "
    else
      line = line .. word .. " "
    end
  end
  return result .. line
end

local function requestGuildManagementInfo()
  sendOpcode("request")
end

local function getSelfRank()
  for _, m in ipairs(guildMembers) do
    if m.isSelf then return m.rank or "" end
  end
  return ""
end

local function isLeaderOrVice(rank)
  return rank == "Leader" or rank == "Vice-Leader" or rank == "Guild Leader" or rank == "Vice Leader"
end

local function guildIconPath(num)
  num = tonumber(num) or 1
  return string.format("imgs/%d.png", num)
end

local function parseUnlocked(str)
  local t = {}
  for n in (str or ""):gmatch("%d+") do
    t[#t+1] = tonumber(n)
  end
  table.sort(t)
  return t
end

local function ensureGuildWindow()
  if guildManagementWindow then return guildManagementWindow end
  guildManagementWindow = g_ui.loadUI(
    "/modules/game_guildManagement/guildManagement.otui",
    modules.game_interface.getRootPanel()
  )
  if not guildManagementWindow then return nil end
  guildManagementWindow:hide()
  guildManagementWindow:getChildById("closeButton").onClick = function() 
    guildManagementWindow:hide()
  end
  return guildManagementWindow
end

local function ensureGuildInputWindow()
  if not guildInputWindow then
    guildInputWindow = g_ui.loadUI("/modules/game_guildManagement/guildInput.otui",
                                   modules.game_interface.getRootPanel())
    if not guildInputWindow then return nil end
    guildInputWindow:setHeight(GUILDINPUT_DEFAULT_HEIGHT)
    guildInputWindow:getChildById("okButton").onClick     = function() 
      if not guildInputWindow then return end
      local inputField = guildInputWindow:getChildById("guildNameEdit")
      if not inputField then return end
      local text = inputField:getText() or ""
      if guildInputCallback then
        local hadError = false
        _G.guildInputError = false
        guildInputCallback(text)
        scheduleEvent(function()
          hadError = _G.guildInputError == true
          if not hadError and guildInputWindow then
            if joinInvitePanel and not joinInvitePanel:isDestroyed() then
              joinInvitePanel:destroyChildren()
              joinInvitePanel:setHeight(0)
            end
            joinInvitePanel = nil
            guildInputWindow:destroy()
            guildInputWindow   = nil
            guildInputCallback = nil
            requestGuildManagementInfo()
          end
        end, 50)
      else
        -- fallback por modo
        if guildInputMode == "create" then
          g_game.talk("!createguild " .. text)
        elseif guildInputMode == "join" then
          sendOpcode("joinguild:" .. text)
        end
      end
    end
    guildInputWindow:getChildById("cancelButton").onClick = function()
      if guildInputWindow then
        if joinInvitePanel and not joinInvitePanel:isDestroyed() then
          joinInvitePanel:destroyChildren()
          joinInvitePanel:setHeight(0)
        end
        joinInvitePanel    = nil
        guildInputCallback = nil
        guildInputWindow:destroy()
        guildInputWindow = nil
      end
    end
  else
    guildInputWindow:setHeight(GUILDINPUT_DEFAULT_HEIGHT)
  end

  -- painel de convites
  joinInvitePanel = guildInputWindow:getChildById("joinListPanel")
  if joinInvitePanel then
    joinInvitePanel:setVisible(false)
    joinInvitePanel:destroyChildren()
  end
  return guildInputWindow
end

local function cleanupJoinInvites()
  if joinInvitePanel and not joinInvitePanel:isDestroyed() then
    joinInvitePanel:destroyChildren()
    joinInvitePanel:setHeight(0)
    joinInvitePanel:setVisible(false)
  end
  joinInviteWidgets = {}
end

-- ===== UI: Seletor de Emblemas =====
local function createGuildImageButtons()
  if not GuildSelectionWindow then return end
  local panel = GuildSelectionWindow:getChildById("GuildBar")
  if not panel then return end
  panel:destroyChildren()

  local maxIconId = tonumber(guildManagementData.maxIconId) or 50
  local unlocked  = {}
  for n in (guildManagementData.imgsDesbloqueadas or ""):gmatch("%d+") do
    unlocked[tonumber(n)] = true
  end
  local inUse = tonumber(guildManagementData.logo) or 1
  local gid   = tonumber(guildManagementData.guildId) or 0

  for id = 1, maxIconId do
    local btn = g_ui.createWidget("UIButton", panel)
    btn:setSize("100 40")
    btn:setImageSource(guildIconPath(id))

    if unlocked[id] then
      btn:setTooltip(id == inUse and "Emblema atual" or "Clique para escolher este emblema")
      if id ~= inUse then
        btn.onClick = function()
          sendOpcode(string.format("setlogo:%d,%d", gid, id))
          GuildSelectionWindow:hide()
        end
      end
    else
      btn:setIcon(LOCK_ICON)
      btn:setOpacity(0.35)
      btn:setTooltip("Emblema bloqueado")
      btn.onClick = function()
        displayInfoBox("Emblema bloqueado", "Este emblema ainda não foi desbloqueado.")
      end
    end
  end
end

function SelectGuildImg()
  if not GuildSelectionWindow then
    GuildSelectionWindow = g_ui.displayUI("selectguildimg.otui")
  end
  GuildSelectionWindow:show()
  GuildSelectionWindow:raise()
  GuildSelectionWindow:focus()
  createGuildImageButtons()
end

function CloseGuildImg()
  if GuildSelectionWindow then
    GuildSelectionWindow:setVisible(false)
  end
end

-- ===== UI: Input genérico (create/join/invite/nick/etc.) =====
local function openGuildInputWindowForAction(action, title, prompt, defaultText, callback)
  guildInputMode     = action
  guildInputCallback = callback
  local wnd = ensureGuildInputWindow()
  if not wnd then return end

  local titleLabel  = wnd:getChildById("titleLabel")
  local promptLabel = wnd:getChildById("promptLabel")
  local inputField  = wnd:getChildById("guildNameEdit")

  if titleLabel  then titleLabel:setText(title or "") end
  if promptLabel then promptLabel:setText(prompt or "") end
  if inputField  then inputField:setText(defaultText or "") end

  -- join mostra lista de convites
  if action == "join" then
    requestGuildManagementInfo()
    cleanupJoinInvites()
    if joinInvitePanel then joinInvitePanel:setVisible(true) end

    -- construir lista imediatamente e novamente com leve atraso para garantir payload
    local function buildJoinInvitesList()
      if not guildInputWindow or not guildInputWindow:isVisible() or not joinInvitePanel then return end

      joinInvitePanel:destroyChildren()
      joinInviteWidgets = {}
      joinInvitePanel:setVisible(true)

      local input   = guildInputWindow:getChildById("guildNameEdit")
      local invites = {}
      for _, inv in ipairs(guildManagementData.myInvites or {}) do
        invites[#invites+1] = { name = tostring(inv.name or ""), id = inv.id, guild_id = inv.guild_id }
      end
      table.sort(invites, function(a, b) return (a.name:lower()) < (b.name:lower()) end)

      local header = g_ui.createWidget("Label", joinInvitePanel)
      header:setId("inviteHeader")
      header:setText(#invites > 0 and "Convites de guild:" or "Você não possui convites.")
      header:setColor(COLOR_GRAY)
      header:setTextAlign(AlignCenter)
      header:setMarginTop(0); header:setMarginLeft(0); header:setMarginRight(0)
      header:addAnchor(AnchorTop,   "parent", AnchorTop)
      header:addAnchor(AnchorLeft,  "parent", AnchorLeft)
      header:addAnchor(AnchorRight, "parent", AnchorRight)
      table.insert(joinInviteWidgets, header)

      local prev = header
      local rows = 0
      for i, inv in ipairs(invites) do
        rows = rows + 1
        local btn = g_ui.createWidget("UIButton", joinInvitePanel)
        btn:setId("inviteBtn" .. i)
        btn:setText(inv.name)
        btn:setHeight(20)
        btn:setMarginTop(2)

        if i == 1 then
          btn:addAnchor(AnchorTop, "inviteHeader", AnchorBottom)
        else
          btn:addAnchor(AnchorTop, "inviteBtn" .. (i-1), AnchorBottom)
        end
        btn:addAnchor(AnchorLeft,  "parent", AnchorLeft)
        btn:addAnchor(AnchorRight, "parent", AnchorRight)

        btn.onClick = function()
          if input then input:setText(inv.name) end
        end
        btn.onDoubleClick = function()
          sendOpcode("joinguild:" .. inv.name)
          if guildInputWindow then guildInputWindow:destroy() guildInputWindow = nil end
          joinInvitePanel = nil
        end

        table.insert(joinInviteWidgets, btn)
        prev = btn
      end

      local headerH = 16
      local rowH    = 22
      local rowsH   = rows * rowH
      local panelH  = headerH + rowsH + 6
      if rows == 0 then panelH = headerH + 6 end

      joinInvitePanel:setHeight(panelH)
      guildInputWindow:setHeight(math.min(GUILDINPUT_DEFAULT_HEIGHT + panelH + 10, GUILDINPUT_MAX_HEIGHT))
    end

    buildJoinInvitesList()
    scheduleEvent(function()
      if guildInputWindow and guildInputWindow:isVisible() and guildInputMode == "join" then
        buildJoinInvitesList()
      end
    end, 150)
  else
    cleanupJoinInvites()
  end

  wnd:show()
  wnd:raise()
end

-- ===== Tabs =====
local function buildMembersTab(scroll)
  local selfRank = getSelfRank()
  if selfRank == "Leader" or selfRank == "Vice-Leader" or selfRank == "Guild Leader" or selfRank == "Vice Leader" then
    local btn = g_ui.createWidget("UIButton", scroll)
    btn:setText("Invite Player")
    btn:setTextOffset("20 0")
    btn:setWidth(150)
    btn:setHeight(22)
    btn.onClick = function()
      openGuildInputWindowForAction(
        "inviteplayer",
        "Convidar Jogador",
        "Digite o nome do jogador:",
        "",
        function(name) sendOpcode("inviteguild:" .. name) end
      )
    end
  else
    local spacer = g_ui.createWidget("UIWidget", scroll)
    spacer:setWidth(150)
    spacer:setHeight(22)
    spacer:setMarginBottom(5)
    spacer:setFocusable(false)
  end

  if #guildMembers == 0 then
    local lbl = g_ui.createWidget("Label", scroll)
    lbl:setText("Nenhum membro online.")
    lbl:setColor(COLOR_WHITE)
    lbl:setTextAlign(AlignCenter)
    return
  end

  local rankLevel = { ["Member"]=1, ["Vice-Leader"]=2, ["Vice Leader"]=2, ["Leader"]=3, ["Guild Leader"]=3 }
  for _, member in ipairs(guildMembers) do
    local entry = g_ui.createWidget("GuildMemberEntry", scroll)
    local outfWidget = entry:getChildById("outfitWidget"):getChildById("outfitBox")
    if outfWidget and member.outfit then
      outfWidget:setOutfit({ type = member.outfit.lookType })
      outfWidget:setAnimate(true)
    end

    local r = member.rank
    if r == "Vice-Leader"   then r = "Vice\nLeader"
    elseif r == "Guild Leader" then r = "Guild\nLeader" end

    local rankLbl = entry:getChildById("rankLabel")
    rankLbl:setText(r)
    rankLbl:setColor(member.online and COLOR_GREEN or COLOR_RED)

    local nameLbl = entry:getChildById("nameLabel")
    nameLbl:setText(member.name)
    nameLbl:setColor(member.online and COLOR_GREEN or COLOR_RED)

    local lvlLbl = g_ui.createWidget("Label", entry)
    lvlLbl:setText("Level " .. (member.level or 0))
    lvlLbl:setColor(COLOR_GRAY)
    lvlLbl:setWidth(70)
    lvlLbl:setTextAlign(AlignCenter)
    lvlLbl:setMarginTop(4)
    lvlLbl:setMarginLeft(-20)

    entry.onMouseRelease = function(_, pos, button)
      if button ~= MouseRightButton then return end
      local myLvl     = rankLevel[selfRank]    or 0
      local targetLvl = rankLevel[member.rank] or 0
      local isSelf    = member.isSelf
      local canActOn  = (myLvl > targetLvl) and (not isSelf)

      if (not isLeaderOrVice(selfRank)) and not isSelf then return end

      local menu = g_ui.createWidget("PopupMenu")
      if myLvl >= 2 and targetLvl < myLvl and targetLvl < 3 then
        menu:addOption("Promover", function() sendOpcode("promote:" .. member.name) end)
      end
      if canActOn then
        menu:addOption("Rebaixar", function() sendOpcode("demote:" .. member.name) end)
        menu:addOption("Expulsar", function() sendOpcode("kick:" .. member.name) end)
        menu:addOption("Alterar Nick", function()
          openGuildInputWindowForAction(
            "nick",
            "Alterar Nick",
            "Digite o novo nick:",
            "",
            function(newNick) sendOpcode("nick:" .. member.name .. "," .. newNick) end
          )
        end)
      end
      menu:display(pos)
    end
  end
end

local function buildInfoTab(scroll)
  local nameLbl = g_ui.createWidget("Label", scroll)
  nameLbl:setText(guildManagementData.guild or "Indefinido")
  nameLbl:setColor(COLOR_WHITE)
  nameLbl:setTextAlign(AlignCenter)

  local createdLbl = g_ui.createWidget("Label", scroll)
  createdLbl:setText("Criada em: " .. os.date("%d/%m/%Y", tonumber(guildManagementData.creationDate) or 0))
  createdLbl:setColor(COLOR_WHITE)
  createdLbl:setTextAlign(AlignCenter)

  local motdLbl = g_ui.createWidget("Label", scroll)
  motdLbl:setFixedSize(true)
  motdLbl:setWidth(250)
  motdLbl:setText(guildManagementData.motd or "Sem MOTD")
  motdLbl:setColor(COLOR_GRAY)
  motdLbl:setTextAlign(AlignCenter)
  motdLbl:setTextWrap(true)
  motdLbl:setTextAutoResize(true)

  motdLbl.onMouseRelease = function(_, pos, button)
    if button ~= MouseRightButton then return end
    if getSelfRank() ~= "Leader" then return end
    local menu = g_ui.createWidget("PopupMenu")
    menu:addOption("Alterar MOTD", function()
      openGuildInputWindowForAction(
        "setmotd",
        "Alterar MOTD",
        "Digite o novo MOTD:",
        "",
        function(newMotd) sendOpcode("setmotd:" .. newMotd) end
      )
    end)
    menu:display(pos)
  end

  local totalLbl = g_ui.createWidget("Label", scroll)
  totalLbl:setText("Total de Jogadores: " .. (guildManagementData.totalPlayers or 0))
  totalLbl:setColor(COLOR_WHITE)
  totalLbl:setTextAlign(AlignCenter)

  local killsLbl = g_ui.createWidget("Label", scroll)
  killsLbl:setText("Total de Frags: " .. (guildManagementData.totalKills or 0))
  killsLbl:setColor(COLOR_WHITE)
  killsLbl:setTextAlign(AlignCenter)

  local pointsLbl = g_ui.createWidget("Label", scroll)
  pointsLbl:setText("Guild Points: " .. (guildManagementData.guildPoints or 0))
  pointsLbl:setColor(COLOR_GOLD)
  pointsLbl:setTextAlign(AlignCenter)

  local selfRank = getSelfRank()
  if selfRank == "Leader" then
    local deleteBtn = g_ui.createWidget("UIButton", scroll)
    deleteBtn:setText("Deletar Guild")
    deleteBtn:setWidth(150)
    deleteBtn:setHeight(20)
    deleteBtn:setColor(COLOR_RED)
    deleteBtn:setMarginTop(20)
    deleteBtn:setMarginLeft(125)
    deleteBtn.onClick = function()
      local dlg
      dlg = displayGeneralBox(
        "Deletar Guild",
        "Você tem certeza que deseja deletar esta guild? Esta ação é irreversível.",
        {
          { text="Sim", callback=function()
              dlg:destroy()
              sendOpcode("deleteguild:" .. (guildManagementData.guild or ""))
              guildManagementWindow:hide()
            end
          },
          { text="Não", callback=function() dlg:destroy() end }
        }
      )
    end
  else
    local leaveBtn = g_ui.createWidget("UIButton", scroll)
    leaveBtn:setText("Sair da Guilda")
    leaveBtn:setWidth(150)
    leaveBtn:setHeight(20)
    leaveBtn:setColor("#FF5555")
    leaveBtn:setMarginTop(20)
    leaveBtn:setMarginLeft(125)
    leaveBtn.onClick = function()
      local dlg
      dlg = displayGeneralBox(
        "Sair da Guilda",
        "Tem certeza que deseja sair da guilda?",
        {
          { text="Sim", callback=function()
              dlg:destroy()
              local myName = guildManagementData.playerName or ""
              sendOpcode("leaveguild:" .. myName)
              guildManagementWindow:hide()
              scheduleEvent(requestGuildManagementInfo, 150)
            end
          },
          { text="Não", callback=function() dlg:destroy() end }
        }
      )
    end
  end
end

local function buildHuntedTab(scroll)
  local huntedList = guildManagementData.hunted or {}
  local selfRank = getSelfRank()

  if isLeaderOrVice(selfRank) then
    local addBtn = g_ui.createWidget("UIButton", scroll)
    addBtn:setText("Adicionar Hunted")
    addBtn:setWidth(150)
    addBtn.onClick = function()
      openGuildInputWindowForAction(
        "addhunted",
        "Adicionar Hunted",
        "Digite o nome:",
        "",
        function(newName) sendOpcode("addhunted:" .. newName) end
      )
    end
  end

  for _, hunted in ipairs(huntedList) do
    local entry = g_ui.createWidget("GuildHuntedEntry", scroll)
    local outfW = entry:getChildById("outfitWidget"):getChildById("outfitBox")
    if outfW then
      outfW:setOutfit({ type = hunted.outfit and hunted.outfit.lookType or 0 })
      outfW:setAnimate(true)
    end

    local nameLbl = entry:getChildById("nameLabel")
    nameLbl:setText(hunted.name)
    nameLbl:setTextOffset("15 0")
    nameLbl:setColor(hunted.online and COLOR_GREEN or COLOR_RED)

    local lvlLbl = entry:getChildById("levelLabel")
    lvlLbl:setText("Level " .. (hunted.level or 0))
    lvlLbl:setColor(COLOR_GRAY)

    if isLeaderOrVice(selfRank) then
      entry.onMouseRelease = function(_, pos, button)
        if button ~= MouseRightButton then return end
        local menu = g_ui.createWidget("PopupMenu")
        menu:addOption("Remover", function() sendOpcode("removehunted:" .. hunted.name) end)
        menu:display(pos)
      end
    end
  end
end

local function buildGuildsTab(scroll)
  local selfName     = guildManagementData.guild or "?"
  local selfMembers  = guildManagementData.totalPlayers or 0
  local selfKills    = guildManagementData.totalKills or 0
  local alreadyInWar = guildManagementData.activeWar ~= nil

  local myEntry   = g_ui.createWidget("GuildWarEntry", scroll)
  local myNameLbl = myEntry:getChildById("nameLabel")

  local icon = g_ui.createWidget("UIWidget", myNameLbl)
  icon:setImageSource(guildIconPath(guildManagementData.logo))
  icon:setWidth(40)
  icon:setHeight(40)
  icon:setMarginLeft(-55)
  icon:addAnchor(AnchorVerticalCenter, "parent", AnchorVerticalCenter)
  icon:addAnchor(AnchorHorizontalCenter, "parent", AnchorHorizontalCenter)
  icon:setTooltip("Clique para trocar o emblema")
  icon.onMouseRelease = function(_, _, button)
    if button ~= MouseLeftButton then return end
    local unlocked = parseUnlocked(guildManagementData.imgsDesbloqueadas)
    if #unlocked > 0 then
      SelectGuildImg()
    else
      displayInfoBox("Emblemas", "Nenhum emblema desbloqueado.")
    end
  end

  myNameLbl:setText(selfName)
  myNameLbl:setColor("#0000FF")
  myNameLbl:setTextOffset("50 0")

  myEntry:getChildById("membersLabel"):setText("Membros: " .. selfMembers)
  myEntry:getChildById("warsLabel"  ):setText("Kills: "   .. selfKills)

  local others = guildManagementData.warList or {}
  table.sort(others, function(a,b) return (a.kills or 0) > (b.kills or 0) end)

  if #others == 0 then
    local lbl = g_ui.createWidget("Label", scroll)
    lbl:setText("Nenhuma outra guild disponível.")
    lbl:setColor(COLOR_WHITE)
    lbl:setTextAlign(AlignCenter)
    return
  end

  local selfRank = getSelfRank()
  for _, g in ipairs(others) do
    local entry   = g_ui.createWidget("GuildWarEntry", scroll)
    local nameLbl = entry:getChildById("nameLabel")

    local ico = g_ui.createWidget("UIWidget", nameLbl)
    ico:setImageSource(guildIconPath(g.icon))
    ico:setWidth(40)
    ico:setHeight(40)
    ico:setMarginLeft(-55)
    ico:addAnchor(AnchorVerticalCenter, "parent", AnchorVerticalCenter)
    ico:addAnchor(AnchorHorizontalCenter, "parent", AnchorHorizontalCenter)

    nameLbl:setTextOffset("50 0")
    nameLbl:setText(g.name)
    nameLbl:setColor(COLOR_WHITE)

    entry:getChildById("membersLabel"):setText("Membros: " .. (g.members or 0))
    entry:getChildById("warsLabel"  ):setText("Kills: "   .. (g.kills   or 0))

    local invitedWar, sentWar, warId = false, false, nil
    for _, w in ipairs(guildManagementData.warInvitations or {}) do
      if w.guild_id == guildManagementData.guildId and w.enemy_id == g.id then
        sentWar, warId = true, w.id
      elseif w.enemy_id == guildManagementData.guildId and w.guild_id == g.id then
        invitedWar, warId = true, w.id
      end
    end
    if guildManagementData.activeWar then
      local a = guildManagementData.activeWar
      if (a.guild_id == guildManagementData.guildId and a.enemy_id == g.id)
      or (a.enemy_id == guildManagementData.guildId and a.guild_id == g.id) then
        warId = a.id
      end
    end

    if sentWar   then nameLbl:setColor(COLOR_GREEN)
    elseif invitedWar then nameLbl:setColor(COLOR_RED) end

    if selfRank == "Leader" then
      entry.onMouseRelease = function(_, pos, button)
        if button ~= MouseRightButton then return end
        local menu = g_ui.createWidget("PopupMenu")
        if not alreadyInWar and not sentWar and not invitedWar and not warId then
          menu:addOption("Declarar Guerra", function()
            sendOpcode(string.format("guildwar:invite,%s,100,0,3", g.name))
          end)
        end
        if invitedWar and warId and not alreadyInWar then
          menu:addOption("Aceitar Guerra", function() sendOpcode("guildwar:accept," .. warId) end)
          menu:addOption("Recusar Guerra", function() sendOpcode("guildwar:decline," .. warId) end)
        end
        if warId then
          menu:addOption("Cancelar Guerra", function() sendOpcode("guildwar:cancel," .. warId) end)
        end
        menu:display(pos)
      end
    end
  end
end

local function onShowTab(tabName)
  currentTab = tabName
  local wnd = ensureGuildWindow()
  if not wnd then return end
  local scroll = wnd:getChildById("guildScrollContainer"):getChildById("guildScroll")
  scroll:destroyChildren()

  if tabName == "membros" then
    buildMembersTab(scroll)
  elseif tabName == "informacoes" then
    buildInfoTab(scroll)
  elseif tabName == "hunted" then
    buildHuntedTab(scroll)
  elseif tabName == "guilds" then
    buildGuildsTab(scroll)
  end
end
_G.onShowTab = onShowTab -- chamado por botões das abas no OTUI

-- ===== Abertura da janela principal =====
local function openGuildManagementWindow(data)
  local wnd = ensureGuildWindow()
  if not wnd then return end

  -- normalizações mínimas de payload
  guildMembers                 = data.members or {}
  guildManagementData          = data
  guildManagementData.totalKills = tonumber(guildManagementData.totalKills) or 0
  if guildManagementData.warList then
    for _, g in ipairs(guildManagementData.warList) do
      g.members = tonumber(g.members) or 0
      g.kills   = tonumber(g.kills)   or 0
    end
  end

  local tabsPanel   = wnd:getChildById("guildTabsPanel")
  local scrollPanel = wnd:getChildById("guildScrollContainer")

  local noGuildPanel = wnd:getChildById("noGuildPanel")
  if noGuildPanel then noGuildPanel:destroy() end

  if data.isInGuild then
    wnd:setHeight(310)
    wnd:setWidth(400)
    tabsPanel:setVisible(true)
    scrollPanel:setVisible(true)
    onShowTab(currentTab)
  else
    wnd:setHeight(120)
    wnd:setWidth(250)
    tabsPanel:setVisible(false)
    scrollPanel:setVisible(false)

    local infoPanel = g_ui.createWidget("GuildNoGuildPanel", wnd)
    infoPanel:setId("noGuildPanel")
    infoPanel:setWidth(200)
    infoPanel:setHeight(90)

    infoPanel:getChildById("createButton").onClick = function()
      openGuildInputWindowForAction("create", "Criar Guild", "Digite o nome da guilda:", "", nil)
    end
    infoPanel:getChildById("joinButton").onClick = function()
      openGuildInputWindowForAction("join", "Entrar na Guild", "Digite o nome da guilda:", "", nil)
    end
  end

  wnd:show()
  wnd:raise()
end

-- ===== Handlers / Eventos =====
local function onTextMessage(mode, text)
  if not guildInputWindow or not guildInputWindow:isVisible() then return end

  local lower = (text or ""):lower()
  if lower:find("guild") or lower:find("nick") or lower:find("setrankname") then
    local warnLabel = guildInputWindow:getChildById("warningLabel")
    if not warnLabel then return end

    warnLabel:setText(wrapText(text, 30))
    warnLabel:setVisible(true)

    if lower:find("erro") or lower:find("falha") then
      warnLabel:setColor(COLOR_RED)
      _G.guildInputError = true
      guildInputWindow:setHeight(GUILDINPUT_EXPANDED_HEIGHT)
    else
      warnLabel:setColor(COLOR_GREEN)
      if guildInputMode == "create" or guildInputMode == "join" then
        guildInputWindow:destroy()
        guildInputWindow = nil
        if guildManagementWindow then guildManagementWindow:hide() end
        scheduleEvent(requestGuildManagementInfo, 50)
      end
    end
  end
end

local function onGuildManagementInfoReceived(_, opcode, buffer)
  if opcode ~= OPCODE_GUILD then return end
  local data = json.decode(buffer)
  if not data then return end

  -- DEBUG enxuto ? comente se não precisar
  -- print(string.format("[GuildUI] invites: %d", #(data.myInvites or {})))

  openGuildManagementWindow(data)
end

local function toggleGuildManagementWindow()
  if not guildManagementWindow then
    requestGuildManagementInfo()
    return
  end
  if guildManagementWindow:isVisible() then
    guildManagementWindow:hide()
  else
    requestGuildManagementInfo()
    guildManagementWindow:show()
    guildManagementWindow:raise()
  end
end
_G.toggleGuildManagementWindow = toggleGuildManagementWindow

-- ===== Ciclo de vida =====
function init()
  ProtocolGame.registerExtendedOpcode(OPCODE_GUILD, onGuildManagementInfoReceived)
  g_keyboard.bindKeyDown("Ctrl+Shift+S", toggleGuildManagementWindow)
  connect(g_game, {
    onTextMessage = onTextMessage,
    onGameEnd     = function() if guildManagementWindow then guildManagementWindow:hide() end end
  })
  GuildSelectionWindow = g_ui.displayUI("selectguildimg.otui")
  GuildSelectionWindow:hide()
end

function terminate()
  disconnect(g_game, { onTextMessage = onTextMessage })
  ProtocolGame.unregisterExtendedOpcode(OPCODE_GUILD)

  if GuildSelectionWindow then GuildSelectionWindow:destroy() GuildSelectionWindow = nil end
  if guildInputWindow     then guildInputWindow:destroy()     guildInputWindow     = nil end
  if guildManagementWindow then guildManagementWindow:destroy() guildManagementWindow = nil end
  if guildManagementButton then guildManagementButton:destroy() guildManagementButton = nil end
end
