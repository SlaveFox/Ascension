-- ? Desenvolvido por Raposo {Raphael T.}
-- ??? Interface do Sistema de Dungeon
local dungeonWindow = nil
if not modules.game_dungeon then
  modules.game_dungeon = {}
end

modules = modules or {}
modules.game_dungeon = modules.game_dungeon or {}
modules.game_dungeon.currentDungeonName = nil

--------------------------------------------------------------------------------
-- ?? SANITIZAÇÃO DE NOMES (para imagens e arquivos)
--------------------------------------------------------------------------------

local function removeAccents(str)
  local accents = {
    ["á"]="a", ["à"]="a", ["ã"]="a", ["â"]="a", ["ä"]="a",
    ["Á"]="A", ["À"]="A", ["Ã"]="A", ["Â"]="A", ["Ä"]="A",
    ["é"]="e", ["è"]="e", ["ê"]="e", ["ë"]="e",
    ["É"]="E", ["È"]="E", ["Ê"]="E", ["Ë"]="E",
    ["í"]="i", ["ì"]="i", ["î"]="i", ["ï"]="i",
    ["Í"]="I", ["Ì"]="I", ["Î"]="I", ["Ï"]="I",
    ["ó"]="o", ["ò"]="o", ["õ"]="o", ["ô"]="o", ["ö"]="o",
    ["Ó"]="O", ["Ò"]="O", ["Õ"]="O", ["Ô"]="O", ["Ö"]="O",
    ["ú"]="u", ["ù"]="u", ["û"]="u", ["ü"]="u",
    ["Ú"]="U", ["Ù"]="U", ["Û"]="U", ["Ü"]="U",
    ["ç"]="c", ["Ç"]="C",
    ["ñ"]="n", ["Ñ"]="N"
  }
  return (str:gsub("[%z\1-\127\194-\244][\128-\191]*", function(c)
    return accents[c] or c
  end))
end

local function sanitizeDungeonName(name)
  return string.lower(removeAccents(name)):gsub(" ", "_")
end

--------------------------------------------------------------------------------
-- ?? INICIALIZAÇÃO E DESTRUIÇÃO
--------------------------------------------------------------------------------
function init()
  connect(g_game, { onGameEnd = destroy })
  connect(LocalPlayer, { onPositionChange = onPositionChange })

  ProtocolGame.registerExtendedOpcode(204, onDungeonOpcode)
end

function terminate()
  disconnect(g_game, { onGameEnd = destroy })
  disconnect(LocalPlayer, { onPositionChange = onPositionChange })

  ProtocolGame.unregisterExtendedOpcode(204)

  destroy()
end

function onPositionChange(creature, newPos, oldPos)
  if creature:isLocalPlayer() then
    modules.game_dungeon.closeDungeonWindow()
    modules.game_dungeon.closeConfirmWindow()
  end
end

function destroy()
  modules.game_dungeon.closeDungeonWindow()
  modules.game_dungeon.closeConfirmWindow()
end

--------------------------------------------------------------------------------
-- ?? ABRIR E FECHAR A JANELA
--------------------------------------------------------------------------------

function modules.game_dungeon.toggleDungeonWindow()
  if dungeonWindow and dungeonWindow:isVisible() then
    modules.game_dungeon.closeDungeonWindow()
  else
    modules.game_dungeon.openDungeonWindow()
  end
end

function modules.game_dungeon.openDungeonWindow()
  if not dungeonWindow then
    dungeonWindow = g_ui.loadUI('/modules/game_dungeonSystem/dungeonSystem.otui', modules.game_interface.getRootPanel())
  end

  dungeonWindow:show()
  dungeonWindow:raise()
  dungeonWindow:focus()

  g_game.getProtocolGame():sendExtendedOpcode(204, json.encode({ action = "requestData" }))
end

function modules.game_dungeon.closeDungeonWindow()
  if dungeonWindow then
    dungeonWindow:destroy()
    dungeonWindow = nil
  end
end

function modules.game_dungeon.closeConfirmWindow()
  if modules.game_dungeon.confirmWindow then
    modules.game_dungeon.confirmWindow:destroy()
    modules.game_dungeon.confirmWindow = nil
    modules.game_dungeon.confirmWindowPlayers = nil
  end
end

--------------------------------------------------------------------------------
-- ?? PREENCHER A LISTA DE DUNGEONS
--------------------------------------------------------------------------------

function modules.game_dungeon.populateDungeonList(dungeonList)
  if not dungeonWindow then return end

  local dungeonListScroll = dungeonWindow:getChildById("dungeonListPanel"):getChildById("dungeonListScroll")
  dungeonListScroll:destroyChildren()

  local selected = modules.game_dungeon.currentDungeonName
  local selectedEntry = nil

  for _, dungeon in ipairs(dungeonList) do
    local entry = g_ui.createWidget("DungeonEntry", dungeonListScroll)

    entry:getChildById("nameLabel"):setText(dungeon.name)
    entry:getChildById("levelLabel"):setText("Nível " .. dungeon.level)

    local playersCount = dungeon.playersList and #dungeon.playersList or 0
    entry:getChildById("playerCountLabel"):setText(playersCount .. " de " .. (dungeon.players or 1))

    entry.onClick = function()
      modules.game_dungeon.selectDungeon(dungeon)
      entry:setFocusable(true)
      entry:focus()
    end

    if selected and dungeon.name == selected then
      selectedEntry = { widget = entry, dungeon = dungeon }
    end
  end

  if selectedEntry then
    modules.game_dungeon.selectDungeon(selectedEntry.dungeon)
    selectedEntry.widget:setFocusable(true)
    selectedEntry.widget:focus()
  elseif #dungeonList > 0 then
    local first = dungeonListScroll:getFirstChild()
    if first then
      modules.game_dungeon.selectDungeon(dungeonList[1])
      first:setFocusable(true)
      first:focus()
    end
  end
end

--------------------------------------------------------------------------------
-- ?? SELECIONAR UMA DUNGEON
--------------------------------------------------------------------------------

function modules.game_dungeon.selectDungeon(data)
  modules.game_dungeon.currentDungeonName = data.name

  if not dungeonWindow then return end
  local details = dungeonWindow:getChildById("dungeonDetailsPanel")
  if not details then return end

  details:getChildById("dungeonName"):setText(data.name)
  details:getChildById("dungeonDescription"):setText(data.description)
  details:getChildById("dungeonObjective"):setText(data.objective or "Objetivo não especificado.")
  details:getChildById("dungeonEstimatedTime"):setText("Tempo Estimado: " .. data.time .. " minutos")

  -- ?? Recompensas
  local rewards = details:getChildById("rewardPanel"):getChildById("rewardItemList")
  rewards:destroyChildren()

  local rewardLabel = details:getChildById("dungeonRewardLabel")
  if data.reward and #data.reward > 0 then
    rewardLabel:setVisible(true)
    for _, item in ipairs(data.reward) do
      local slot = g_ui.createWidget("DungeonRewardSlot", rewards)
      slot:setItemId(item.itemId or 2160)
      slot:setTooltip((item.count > 1 and (item.count .. "x ") or "") .. (item.name or "Item Desconhecido"))

      local itemCount = slot:getChildById("itemCount")
      if itemCount then
        itemCount:setText(item.count > 1 and tostring(item.count) or "")
      end
    end
  else
    rewardLabel:setVisible(false)
  end

  -- ??? Imagem
  local imageName = sanitizeDungeonName(data.name)
  local imagePath = "images/dungeons/" .. imageName .. ".png"
  if g_resources.fileExists(imagePath) then
    details:setImageSource(imagePath)
  else
    details:setImageSource("")
    details:setBackgroundColor("#121212")
  end

  -- ?? Chave
  local keyPanel = details:getChildById("keyPanel")
  if data.key then
    keyPanel:setVisible(true)
    local keyItem = keyPanel:getChildById("keyItem")
    keyItem:setItemId(data.key.itemId or 2089)
    keyItem:setTooltip(string.format("Você precisa de %dx %s para entrar.", data.key.count or 1, data.key.name or "Chave"))
  else
    keyPanel:setVisible(false)
  end

  -- ?? Party
  local partyPanel = details:getChildById("partyPreviewPanel")
  partyPanel:destroyChildren()
  local maxPlayers = data.players or 1
  partyPanel:setWidth((50 * maxPlayers) + (5 * (maxPlayers - 1)))

  local players = data.playersList or {}

  for i = 1, maxPlayers do
    local playerData = players[i]
    if playerData then
      local widget = g_ui.createWidget("PartyMemberWidget", partyPanel)
      local outfitBox = widget:getChildById("outfitBox")

      if outfitBox and playerData.outfit then
        outfitBox:setOutfit({ type = playerData.outfit.lookType })
        outfitBox:setAnimate(true)
        outfitBox:setTooltip(string.format("Nome: %s\nLevel: %d", playerData.name, playerData.level))

        outfitBox:setFocusable(true)

        outfitBox.onMouseRelease = function(_, mousePos, mouseButton)
          if mouseButton == MouseRightButton and playerData.name ~= g_game.getCharacterName() then
            local menu = g_ui.createWidget('PopupMenu')
            menu:setGameMenu(true)

            menu:addOption("Remover da Party", function()
              g_game.getProtocolGame():sendExtendedOpcode(204, json.encode({
                action = "removePlayer",
                target = playerData.name,
                dungeon = modules.game_dungeon.currentDungeonName
              }))
            end)

            menu:display(mousePos)
          end
        end
      end
    else
      local emptySlot = g_ui.createWidget("PartyEmptySlot", partyPanel)
      local addButton = emptySlot:getChildById("addButton")
      if addButton then
        addButton.onClick = function()
          modules.game_dungeon.openInviteWindow()
        end
      end
    end
  end
end

--------------------------------------------------------------------------------
-- ? JANELA DE CONVITE
--------------------------------------------------------------------------------

function modules.game_dungeon.openInviteWindow()
  local win = g_ui.createWidget("inviteWindow", modules.game_interface.getRootPanel())
  if not win then return end

  win:show()
  win:raise()
  win:focus()

  local input = win:getChildById("playerNameInput")
  local confirm = win:getChildById("confirmInviteButton")

  confirm.onClick = function()
    local name = input:getText():trim()
    if name ~= "" then
      g_game.getProtocolGame():sendExtendedOpcode(204, json.encode({
        action = "invitePlayer",
        target = name,
        dungeon = modules.game_dungeon.currentDungeonName
      }))
    end
    win:destroy()
  end
end

function modules.game_dungeon.openConfirmWindow(dungeonName, leader, players)
  local win = g_ui.createWidget("confirmDungeonWindow", modules.game_interface.getRootPanel())
  if not win then return end

  -- Salva a janela na variável de controle
  modules.game_dungeon.confirmWindow = win

  win:show()
  win:raise()
  win:focus()

  modules.game_dungeon.confirmWindowPlayers = {}

  local text = string.format("%s está iniciando a dungeon \"%s\".\nDeseja entrar?", leader, dungeonName)
  win:getChildById("confirmText"):setText(text)

  local partyPanel = win:getChildById("partyPreviewPanel")
  if partyPanel then
    partyPanel:destroyChildren()

    for _, player in ipairs(players) do
      local widget = g_ui.createWidget("PartyMemberWidget", partyPanel)
      local outfitBox = widget:getChildById("outfitBox")

      if outfitBox then
        outfitBox:setOutfit({ type = player.outfit.lookType })
        outfitBox:setOpacity(0.4)
      end

      modules.game_dungeon.confirmWindowPlayers[player.name] = outfitBox
    end
  end

  local function onConfirm(playerName)
    if modules.game_dungeon.confirmWindowPlayers[playerName] then
      modules.game_dungeon.confirmWindowPlayers[playerName]:setOpacity(1.0)
    end
  end

  win:getChildById("acceptButton").onClick = function()
    onConfirm(g_game.getCharacterName())
    g_game.getProtocolGame():sendExtendedOpcode(204, json.encode({
      action = "confirmStart",
      dungeon = dungeonName,
      accept = true
    }))
  end

  win:getChildById("declineButton").onClick = function()
    win:destroy()
    modules.game_dungeon.confirmWindow = nil
    modules.game_dungeon.confirmWindowPlayers = nil
    g_game.getProtocolGame():sendExtendedOpcode(204, json.encode({
      action = "confirmStart",
      dungeon = dungeonName,
      accept = false
    }))
  end
end

--------------------------------------------------------------------------------
-- ?? ENTRAR NA DUNGEON
--------------------------------------------------------------------------------

function modules.game_dungeon.enterSelectedDungeon()
  if not modules.game_dungeon.currentDungeonName then return end

  g_game.getProtocolGame():sendExtendedOpcode(204, json.encode({
    action = "requestStart", -- ? Correção aqui!
    dungeon = modules.game_dungeon.currentDungeonName
  }))
end

--------------------------------------------------------------------------------
-- ? DUNGEON TIMER
--------------------------------------------------------------------------------
local dungeonTimerWindow = nil
local dungeonTimerEvent = nil
local dungeonTimerSeconds = 0

-- ?? Abrir Timer
function modules.game_dungeon.openDungeonTimer(duration)
    modules.game_dungeon.dungeonTimerMaxSeconds = duration
dungeonTimerSeconds = modules.game_dungeon.dungeonTimerMaxSeconds

  if dungeonTimerWindow then
    dungeonTimerWindow:destroy()
    removeEvent(dungeonTimerEvent)
  end

  dungeonTimerWindow = g_ui.createWidget("DungeonTimerWindow", modules.game_interface.getRootPanel())
  if not dungeonTimerWindow then return end

  dungeonTimerWindow:show()
  dungeonTimerWindow:raise()

  dungeonTimerSeconds = duration -- minutos para segundos
  modules.game_dungeon.updateDungeonTimerLabel()

  -- Start loop
  dungeonTimerEvent = cycleEvent(function()
    dungeonTimerSeconds = dungeonTimerSeconds - 1
    if dungeonTimerSeconds <= 0 then
      modules.game_dungeon.closeDungeonTimer()
      return
    end
    modules.game_dungeon.updateDungeonTimerLabel()
  end, 1000)
end

-- ?? Atualizar Label do Timer
function modules.game_dungeon.updateDungeonTimerLabel()
  if not dungeonTimerWindow then return end

  local minutes = math.floor(dungeonTimerSeconds / 60)
  local seconds = dungeonTimerSeconds % 60
  local text = string.format("Tempo Restante: %02d:%02d", minutes, seconds)

  local label = dungeonTimerWindow:getChildById("timerLabel")
  label:setText(text)

  -- ?? Define a cor com base no tempo restante
  local percentage = dungeonTimerSeconds / modules.game_dungeon.dungeonTimerMaxSeconds

  if percentage > 0.66 then
    label:setColor("#00FF00") -- ?? Verde
  elseif percentage > 0.33 then
    label:setColor("#FFFF00") -- ?? Amarelo
  else
    label:setColor("#FF0000") -- ?? Vermelho
  end
end


-- ?? Fechar Timer
function modules.game_dungeon.closeDungeonTimer()
  if dungeonTimerWindow then
    dungeonTimerWindow:destroy()
    dungeonTimerWindow = nil
  end
  if dungeonTimerEvent then
    removeEvent(dungeonTimerEvent)
    dungeonTimerEvent = nil
  end
end

--------------------------------------------------------------------------------
-- ?? RECEBER DADOS DO SERVIDOR
--------------------------------------------------------------------------------

function onDungeonOpcode(protocol, opcode, buffer)
  if not modules.game_dungeon then
    modules.game_dungeon = {}
  end

  local success, data = pcall(json.decode, buffer)
  if not success or not data then
    print("[CLIENT] ? Erro ao decodificar JSON:", buffer)
    return
  end


  if data.list then
    if not dungeonWindow or not dungeonWindow:isVisible() then
      modules.game_dungeon.openDungeonWindow()
    end
    modules.game_dungeon.populateDungeonList(data.list)
    return
  end

  -- ?? Ao iniciar a dungeon
if data.action == "startDungeon" then
  local duration = data.time or 15 -- duração da dungeon em minutos
  modules.game_dungeon.closeConfirmWindow()
  modules.game_dungeon.closeDungeonWindow()
  modules.game_dungeon.openDungeonTimer(duration)
  return
end

-- ?? Ao finalizar a dungeon
if data.action == "finishDungeon" then
  modules.game_dungeon.closeDungeonTimer()
  return
end


    if data.action == "confirmStart" then
    local dungeonName = data.dungeon or "Dungeon Misteriosa"
    local leader = data.leader or "Líder"
    local players = data.players or {}

    modules.game_dungeon.openConfirmWindow(dungeonName, leader, players)
    return
    end

    if data.action == "playerConfirmed" then
  local playerName = data.player
  if modules.game_dungeon.confirmWindowPlayers and modules.game_dungeon.confirmWindowPlayers[playerName] then
    modules.game_dungeon.confirmWindowPlayers[playerName]:setOpacity(1.0)
  end
  return
end



  if data.action == "inviteReceived" then
    local inviter = data.inviter or "Desconhecido"
    local dungeonName = data.dungeon or "Dungeon Misteriosa"

    local win = g_ui.createWidget("inviteReceivedWindow", modules.game_interface.getRootPanel())
    if not win then return end

    win:show()
    win:raise()
    win:focus()

    win:getChildById("inviteText"):setText(string.format("%s te convidou para a dungeon \"%s\". Deseja se juntar?", inviter, dungeonName))

    win:getChildById("acceptButton").onClick = function()
      g_game.getProtocolGame():sendExtendedOpcode(204, json.encode({
        action = "acceptInvite",
        inviter = inviter,
        dungeon = dungeonName
      }))
      win:destroy()
    end

    win:getChildById("declineButton").onClick = function()
      win:destroy()
    end
    return
  end

  if data.action == "openWindow" then
    modules.game_dungeon.openDungeonWindow()
    return
  end
end
