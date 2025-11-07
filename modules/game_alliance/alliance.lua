local allianceWindow = nil
local allianceButton = nil

-- Inicializa o módulo
function init()
    ProtocolGame.registerExtendedOpcode(101, onAllianceInfoReceived)

    -- Adiciona o botï¿½o ao menu superior
    allianceButton = modules.client_topmenu.addRightGameToggleButton(
        'allianceButton', 
        tr('Alliance') .. ' (Ctrl+Shift+A)', 
        '/images/topbuttons/alliance', 
        toggleAllianceWindow
    )
    allianceButton:setOn(false)
    g_keyboard.bindKeyDown('Ctrl+Shift+A', toggleAllianceWindow)

    -- Torna as funï¿½ï¿½es globais
    _G.switchToTab = switchToTab
    _G.closeWindow = closeWindow
end

-- Finaliza o módulo
function terminate()
    ProtocolGame.unregisterExtendedOpcode(101)
    if allianceWindow then
        allianceWindow:destroy()
        allianceWindow = nil
    end
    if allianceButton then
        allianceButton:destroy()
        allianceButton = nil
    end
end

-- Recebe informações da aliança enviadas pelo servidor
function onAllianceInfoReceived(protocol, opcode, buffer)
  local allianceData = json.decode(buffer)
  if allianceData then
      openAllianceWindow(allianceData)
  else
      g_game.addMessage("Erro ao processar os dados da aliança.")
  end
end

-- Funï¿½ï¿½o para abrir a janela da aliança
function openAllianceWindow(allianceData)
  if not allianceWindow then
      allianceWindow = g_ui.loadUI('/modules/game_alliance/alliance.otui', modules.game_interface.getRootPanel())
      allianceWindow:hide()

      -- Configura o botï¿½o de fechar
      allianceWindow:getChildById('closeButton'):onClick(function()
          closeWindow()
      end)
  end

  -- Aba Geral
  local playerNameLabel = allianceWindow:getChildById('contentPanel'):getChildById('generalPanel'):getChildById('playerName')
  if playerNameLabel then 
      playerNameLabel:setText(allianceData.playerName or "N/A") 
      playerNameLabel:setColor('#00FF00') -- Verde para destacar o nome do jogador
  end

  local allianceNameLabel = allianceWindow:getChildById('contentPanel'):getChildById('generalPanel'):getChildById('allianceName')
  if allianceNameLabel then 
      allianceNameLabel:setText(allianceData.name or "Sem aliança") 
      allianceNameLabel:setColor('#FF4500') -- Laranja para o nome da aliança
  end

  local playerRankLabel = allianceWindow:getChildById('contentPanel'):getChildById('generalPanel'):getChildById('playerRank')
  if playerRankLabel then 
      playerRankLabel:setText(allianceData.rank or "N/A")
      playerRankLabel:setColor('#FFD700') -- Dourado para o rank do jogador
  end

  local playerKillsLabel = allianceWindow:getChildById('contentPanel'):getChildById('generalPanel'):getChildById('playerKills')
  if playerKillsLabel then
      playerKillsLabel:setText(tostring(allianceData.kills or 0))
      playerKillsLabel:setColor('#FF0000') -- Vermelho para o número de mortes
  end

  local attributesLabel = allianceWindow:getChildById('contentPanel'):getChildById('generalPanel'):getChildById('attributes')
  if attributesLabel then
      local attributesText = table.concat(allianceData.attributes or {}, "\n")
      attributesLabel:setText(attributesText ~= "" and attributesText or "Sem atributos")
      attributesLabel:setColor('#20B2AA') -- Vermelho para o número de mortes
  end

  -- Aba Estatísticas
  local allianceRankLabel = allianceWindow:getChildById('contentPanel'):getChildById('statsPanel'):getChildById('allianceRank')
  if allianceRankLabel then
      allianceRankLabel:setText(allianceData.allianceRank or "Sem rank")      
      allianceRankLabel:setColor('#B0E0E6') -- Vermelho para o número de mortes
  end

  local competitionPanel = allianceWindow:getChildById('contentPanel'):getChildById('statsPanel'):getChildById('factionCompetition')

  -- Limpa o conteúdo existente
  competitionPanel:destroyChildren()

  -- Adiciona os ranks dinamicamente
  for _, rank in ipairs(allianceData.allianceRanks) do
      local rankColor
      if rank.position == 1 then
          rankColor = "#FFD700" -- Dourado para 1ï¿½ lugar
      elseif rank.position == 2 then
          rankColor = "#C0C0C0" -- Prata para 2ï¿½ lugar
      elseif rank.position == 3 then
          rankColor = "#CD7F32" -- Bronze para 3ï¿½ lugar
      else
          rankColor = "#FFFFFF" -- Branco para outros
      end

      -- Cria um novo widget de Label para cada rank
      local rankLabel = g_ui.createWidget('Label', competitionPanel)
      rankLabel:setText(string.format("%s: %s com %d mortes", rank.name, rank.alliance, rank.kills))
      rankLabel:setColor(rankColor) -- Aplica a cor baseada na posiï¿½ï¿½o
      rankLabel:setMarginBottom(5) -- Espaï¿½amento entre os labels
  end

  local membersLabel = allianceWindow:getChildById('contentPanel'):getChildById('statsPanel'):getChildById('members')
  if membersLabel then
      membersLabel:setText(tostring(allianceData.membersCount or 0))
      membersLabel:setColor('#F08080')
  end

  local onlineMembersLabel = allianceWindow:getChildById('contentPanel'):getChildById('statsPanel'):getChildById('onlineMembers')
  if onlineMembersLabel then 
    onlineMembersLabel:setText(tostring(allianceData.onlineMembers or 0))    
    onlineMembersLabel:setColor('#00FF00')
  end

  local targetNameLabel = allianceWindow:getChildById('contentPanel'):getChildById('targetPanel'):getChildById('targetName')
  if targetNameLabel then targetNameLabel:setText(allianceData.target.name or "N/A") end

  local targetVocationLabel = allianceWindow:getChildById('contentPanel'):getChildById('targetPanel'):getChildById('targetVocation')
  if targetVocationLabel then targetVocationLabel:setText(allianceData.target.vocation or "N/A") end

  local targetLevelLabel = allianceWindow:getChildById('contentPanel'):getChildById('targetPanel'):getChildById('targetLevel')
  if targetLevelLabel then targetLevelLabel:setText(tostring(allianceData.target.level or 0)) end

  local targetFactionLabel = allianceWindow:getChildById('contentPanel'):getChildById('targetPanel'):getChildById('targetFaction')
  if targetFactionLabel then targetFactionLabel:setText(allianceData.target.faction or "N/A") end

  local targetTimeLeftLabel = allianceWindow:getChildById('contentPanel'):getChildById('targetPanel'):getChildById('targetTimeLeft')
  if targetTimeLeftLabel then targetTimeLeftLabel:setText(allianceData.target.timeLeft or "N/A") end

  local missionsPanel = allianceWindow:getChildById('contentPanel'):getChildById('missionsPanel')

  -- Remove todos os filhos existentes do painel de Missões para evitar sobreposiï¿½ï¿½es
  missionsPanel:destroyChildren()

  -- Adiciona o tï¿½tulo "Missões da aliança"
  local titleLabel = g_ui.createWidget('Label', missionsPanel)
  titleLabel:setId('missionsTitle')
  titleLabel:setText("Missões da aliança")
  titleLabel:setColor('#FFFFFF')
  titleLabel:setMarginBottom(10) -- Adiciona margem inferior
  titleLabel:setMarginLeft(25) -- Adiciona margem inferior

  -- Adiciona as Missões dinamicamente
  for _, mission in ipairs(allianceData.missions) do
      -- Nome da missão
      local missionNameLabel = g_ui.createWidget('Label', missionsPanel)
      missionNameLabel:setText(mission.name)
      missionNameLabel:setColor('#FFFF00') -- Adiciona cor amarela para destaque
      missionNameLabel:setMarginBottom(5) -- Espaï¿½o entre o nome e a Descrição
      missionNameLabel:setMarginLeft(25) -- Espaï¿½o entre o nome e a Descrição

      -- Descrição da missão
      local missionDescriptionLabel = g_ui.createWidget('Label', missionsPanel)
      missionDescriptionLabel:setText(mission.description)
      missionDescriptionLabel:setColor('#AAAAAA') -- Cor diferenciada para Descrição
      missionDescriptionLabel:setMarginBottom(5) -- Espaï¿½o entre a Descrição e a prï¿½xima missão
      missionDescriptionLabel:setMarginLeft(25) -- Espaï¿½o entre a Descrição e a prï¿½xima missão
  end

  allianceWindow:show()
  allianceWindow:raise()
  allianceWindow:focus()
  allianceButton:setOn(true)
end

-- Alterna a visibilidade da janela
function toggleAllianceWindow()
    if not allianceWindow then
        allianceWindow = g_ui.loadUI('/modules/game_alliance/alliance.otui', modules.game_interface.getRootPanel())
        allianceWindow:hide()

        -- Configura o botï¿½o de fechar
        allianceWindow:getChildById('closeButton'):onClick(function()
            closeWindow()
        end)
    end

    if allianceWindow:isVisible() then
        allianceWindow:hide()
        allianceButton:setOn(false)
    else
        requestAllianceInfo()
        allianceWindow:show()
        allianceWindow:raise()
        allianceButton:setOn(true)
    end
end

-- Fecha a janela
function closeWindow()
  if allianceWindow then
      allianceWindow:hide()
      if allianceButton then
          allianceButton:setOn(false)
      end
  end
end

function switchToTab(tabId)
  local panels = {"generalPanel", "statsPanel", "missionsPanel", "targetPanel"}
  for _, panelId in ipairs(panels) do
      local panel = allianceWindow:getChildById('contentPanel'):getChildById(panelId)
      if panel then
          panel:setVisible(panelId == tabId)
      end
  end
end

-- Solicita informações da aliança ao servidor
function requestAllianceInfo()
    g_game.getProtocolGame():sendExtendedOpcode(101, "request")
end
