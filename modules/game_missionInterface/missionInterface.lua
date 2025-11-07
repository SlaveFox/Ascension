
MissionInterface = {}
missionWindow = nil
MissionInterface.missions = {}

function MissionInterface.init()
  connect(g_game, { onGameStart = MissionInterface.online, onGameEnd = MissionInterface.offline })
  missionWindow = g_ui.displayUI('missionInterface')
  missionWindow:hide()
  ProtocolGame.registerExtendedOpcode(210, MissionInterface.onExtendedOpcode)

  local closeButton = missionWindow:recursiveGetChildById('closeButton')
  if closeButton then
    closeButton.onClick = function()
      missionWindow:hide()
    end
    local searchBox = missionWindow:recursiveGetChildById('missionSearch')
if searchBox then
  searchBox.onTextChange = function(self, text)
    MissionInterface.applyCurrentFilters(text)
  end
end

  end
end


function MissionInterface.terminate()
  disconnect(g_game, { onGameStart = MissionInterface.online, onGameEnd = MissionInterface.offline })
  ProtocolGame.unregisterExtendedOpcode(210)
  if missionWindow then
    missionWindow:destroy()
    missionWindow = nil
  end
end

function MissionInterface.online() end
function MissionInterface.offline()
  if missionWindow then
    missionWindow:hide()
  end
end

function MissionInterface.toggle()
  if not missionWindow then return end
  if missionWindow:isVisible() then
    missionWindow:hide()
  else
    if g_game.isOnline() then
      g_game.getProtocolGame():sendExtendedOpcode(210, json.encode({ action = "open" }))
    end

    missionWindow:show()
    missionWindow:raise()
    missionWindow:focus()

    local minimap = missionWindow:recursiveGetChildById('missionMinimap')
    if minimap and g_game.isOnline() then
      minimap:setCameraPosition(g_game.getLocalPlayer():getPosition())
    end

    -- ? Marcar o filtro "all"
    MissionInterface.setFilter("all")

    -- ? Deixar o checkbox "mostrar concluídas" marcado por padrão
    local showCompletedCheck = missionWindow:recursiveGetChildById('showCompletedCheck')
    if showCompletedCheck then
      showCompletedCheck:setChecked(true)
    end

    -- ? Garantir que ele aplique os filtros logo na abertura
    MissionInterface.applyCurrentFilters()
  end
end



MissionInterface.jsonBuffer = ""

function MissionInterface.onExtendedOpcode(protocol, opcode, buffer)
  if opcode ~= 210 then return end

  -- Tratamento de pacotes em partes (Start, Part, End)
  local prefix = buffer:sub(1,1)
  local content = buffer:sub(2)

  if prefix == "S" then
    MissionInterface.jsonBuffer = content
  elseif prefix == "P" then
    MissionInterface.jsonBuffer = MissionInterface.jsonBuffer .. content
  elseif prefix == "E" then
    MissionInterface.jsonBuffer = MissionInterface.jsonBuffer .. content

    local success, data = pcall(function() return json.decode(MissionInterface.jsonBuffer) end)
    if not success or not data then
      print("[MissionInterface] Erro ao decodificar JSON após reconstrução")
      MissionInterface.jsonBuffer = ""
      return
    end

    -- Processa os dados recebidos (exatamente como estava antes)
    if data.action == "open" and data.missions then
      local selectedMissionName = nil
      if MissionInterface.currentSelectedMission then
        selectedMissionName = MissionInterface.currentSelectedMission.name
      end

      MissionInterface.missions = data.missions
      MissionInterface.populateMissionList(data.missions)

      if selectedMissionName then
        for _, mission in ipairs(MissionInterface.missions) do
          if mission.name == selectedMissionName then
            MissionInterface.selectMission(mission)
            break
          end
        end
      end
    end

    MissionInterface.jsonBuffer = "" -- Limpa buffer depois do uso
  else
    print("[MissionInterface] Prefixo de pacote inválido recebido: " .. prefix)
  end
end


function MissionInterface.populateMissionList(missions)
  local list = missionWindow:recursiveGetChildById('missionList')
  if not list then return end
  list:destroyChildren()

  for _, mission in ipairs(missions) do
    local entry = g_ui.createWidget('MissionEntry', list)
    entry:getChildById('missionName'):setText(mission.name)

    -- Outfit
    local outfitWidget = entry:getChildById('missionOutfit')
    if outfitWidget then
      if mission.looktype and mission.looktype > 0 then
      outfitWidget:setOutfit({ type = mission.looktype })
    else
      outfitWidget:setOutfit({ type = 128 }) -- Looktype default (exemplo: citizen)
    end

    end

    -- Checkbox de concluída
    local check = entry:getChildById('missionCompletedCheck')
    if check then
      check:setChecked(mission.completed)
    end

    -- Borda: Verde se concluída, Amarela se for a selecionada
  if mission.started then
    entry:setBorderColor("#007BFF") -- Azul (em andamento)
  elseif mission.completed then
    entry:setBorderColor("#00FF00") -- Verde (concluída)
  else
    entry:setBorderColor("#666666") -- Normal (não iniciada)
  end


    -- Callback de clique
    entry.onClick = function(widget)
      MissionInterface.selectMission(mission)
    end
  end
end

function MissionInterface.selectMission(mission)
  MissionInterface.currentSelectedMission = mission

  -- ? Limpar marcas antigas do minimap antes de adicionar novas
  local minimap = missionWindow:recursiveGetChildById('missionMinimap')
  if minimap and minimap.clearAllFlags then
    minimap:clearAllFlags()
  end
  
  if _G.clearMarkMap then
    _G.clearMarkMap() -- Caso esteja usando essa função global
  end

  MissionInterface.showMissionObjectives(mission)

  local minimapTitle = missionWindow:recursiveGetChildById('minimapTitle')
  if minimapTitle then
    minimapTitle:setText(mission.name)
  end

  -- Atualizar minimap
  if minimap then
    if mission.startPos then
      minimap:setCameraPosition(mission.startPos)
    elseif mission.objectives then
      for _, obj in ipairs(mission.objectives) do
        if obj.type == "reach" and obj.pos then
          minimap:setCameraPosition(obj.pos)
          break
        end
      end
    end
  end

  -- ? Se for missão de kill, pedir para marcar os spawns dos monstros
  if mission.objectives then
    for _, obj in ipairs(mission.objectives) do
      if obj.type == "kill" and obj.target then
        if g_game.isOnline() then
          g_game.getProtocolGame():sendExtendedOpcode(210, json.encode({
            action = "markSpawn",
            monsterName = obj.target
          }))
        end
      end
    end
  end
end


function MissionInterface.showMissionObjectives(mission)
  local objectivePanel = missionWindow:recursiveGetChildById('objectiveList')
  if not objectivePanel then return end
  objectivePanel:destroyChildren()

  -- ?? Exibir descrição da missão
  local descriptionEntry = g_ui.createWidget('DescriptionEntry', objectivePanel)
  descriptionEntry:getChildById('descriptionLabel'):setText(mission.description or "Nenhuma descrição disponível.")

  -- ?? Status da missão
  if mission.completed then
    local statusLabel = g_ui.createWidget('Label', objectivePanel)
    statusLabel:setText("[Concluído]")
    statusLabel:setColor("#00FF00") -- Verde
    statusLabel:setFont('baby-14')
  elseif mission.started then
    local statusLabel = g_ui.createWidget('Label', objectivePanel)
    statusLabel:setText("[Em andamento]")
    statusLabel:setColor("#00BFFF") -- Azul claro
    statusLabel:setFont('baby-14')
  end

  -- ?? Exibir objetivos
  if not mission.objectives or #mission.objectives == 0 then
    local label = g_ui.createWidget('Label', objectivePanel)
    label:setText("Nenhum objetivo definido.")
    label:setColor("gray")
  else
    for index, obj in ipairs(mission.objectives) do
      local entry = g_ui.createWidget('ObjectiveEntry', objectivePanel)
      entry.objectiveIndex = index

      local text = ""
      if obj.type == "kill" then
        text = string.format("Mate %d %s", obj.count, obj.target)
      elseif obj.type == "collect" then
        text = string.format("Recupere o Item")
      elseif obj.type == "reach" then
        text = string.format("Vá até a posição %d, %d, %d", obj.pos.x, obj.pos.y, obj.pos.z)
      elseif obj.type == "talk" then
        text = string.format("Fale com %s", obj.npcName or "???")
      else
        text = "Objetivo desconhecido"
      end

      local header = entry:getChildById('objectiveHeader')
      if header then
        local label = header:getChildById('objectiveLabel')
        if label then
          label:setText(text)
        end

        local check = header:getChildById('objectiveCompletedCheck')
        if check then
          check:setChecked(obj.completed or false)
        end

        local detailButton = header:getChildById('objectiveDetailButton')
        if detailButton then
          detailButton:setText("+")
          detailButton:setTooltip("Exibir mais informações")
        end
      end
    end
  end

-- ?? Exibir recompensas (Estilo Bestiary com scroll horizontal)
if mission.rewards and #mission.rewards > 0 then
    -- Título
    local rewardTitle = g_ui.createWidget('Label', objectivePanel)
    rewardTitle:setText("Recompensas:")
    rewardTitle:setColor("yellow")
    rewardTitle:setFont('baby-14')
    rewardTitle:setMarginTop(5)

    -- Painel com scroll horizontal
    local rewardPanel = g_ui.createWidget('MissionRewardPanel', objectivePanel)
    local rewardList = rewardPanel:getChildById('missionRewardList')

    for _, reward in ipairs(mission.rewards) do
        if reward.type == "item" and reward.clientId and reward.clientId > 0 then
            local slot = g_ui.createWidget('MissionRewardSlot', rewardList)
            slot:setItemId(reward.clientId)

            local countLabel = slot:getChildById('itemCount')
            if countLabel and reward.count and reward.count > 1 then
                countLabel:setText(tostring(reward.count))
            end

            local itemName = reward.itemName or string.format("Item ID %d", reward.id)
            slot:setTooltip(string.format("%dx %s", reward.count or 1, itemName))

          elseif reward.type == "exp" and reward.amount then
              local expSlot = g_ui.createWidget('MissionExpSlot', rewardList)
              local expLabel = expSlot:getChildById('expLabel')
              if expLabel then
                  expLabel:setText("EXP")
              end
              expSlot:setTooltip(string.format("%d Experiência", reward.amount))
              elseif reward.type == "powerup_points" and reward.points then
    local powerSlot = g_ui.createWidget('MissionExpSlot', rewardList)
    local label = powerSlot:getChildById('expLabel')
    if label then
        label:setText("PUP")
        label:setFont('baby-14')
        label:setColor("#FFD700")
    end
    powerSlot:setTooltip(string.format("%d Pontos de Power Up", reward.points))



        end
    end
end


-- Função utilitária para formatar o cooldown em horas, minutos e segundos
local function formatCooldown(seconds)
    if seconds >= 3600 then
        local hours = math.floor(seconds / 3600)
        local minutes = math.floor((seconds % 3600) / 60)
        return string.format("Cooldown: %dh %dmin", hours, minutes)
    elseif seconds >= 60 then
        local minutes = math.floor(seconds / 60)
        local sec = seconds % 60
        return string.format("Cooldown: %dmin %ds", minutes, sec)
    else
        return string.format("Cooldown: %ds", seconds)
    end
end

-- ??? Atualizar o botão de ação (Iniciar / Cancelar)
local actionButton = missionWindow:recursiveGetChildById('missionActionButton')
if actionButton then
    -- Oculta o botão por padrão
    actionButton:hide()

    -- Exibe e configura apenas para TASKS
    if mission.type == "task" then
        actionButton:show()

        -- Cancela qualquer evento de cooldown antigo
        if actionButton.cooldownEvent then
            removeEvent(actionButton.cooldownEvent)
            actionButton.cooldownEvent = nil
        end

        -- Se estiver em cooldown
        if mission.cooldown and mission.cooldown > 0 then
            actionButton:setText(formatCooldown(mission.cooldown))
            actionButton:setColor("#888888")
            actionButton.onClick = nil
            actionButton:setEnabled(false)

            local remaining = mission.cooldown
            actionButton.cooldownEvent = cycleEvent(function()
                remaining = remaining - 1
                if remaining > 0 then
                    actionButton:setText(formatCooldown(remaining))
                else
                    removeEvent(actionButton.cooldownEvent)
                    actionButton.cooldownEvent = nil
                    actionButton:setText("Iniciar Missão")
                    actionButton:setColor("#00FF00")
                    actionButton:setEnabled(true)
                    actionButton.onClick = function()
                        MissionInterface.toggleMissionAction()
                    end
                end
            end, 1000)

        elseif mission.started then
            -- Task já iniciada
            actionButton:setText("Cancelar Missão")
            actionButton:setColor("#FF4444")
            actionButton:setEnabled(true)
            actionButton.onHoverChange = function(widget, hovered)
                widget:setColor(hovered and "#FF8888" or "#FF4444")
            end
            actionButton.onClick = function()
                MissionInterface.toggleMissionAction()
            end

        elseif not mission.completed then
            -- Task disponível para iniciar
            actionButton:setText("Iniciar Missão")
            actionButton:setColor("#00FF00")
            actionButton:setEnabled(true)
            actionButton.onHoverChange = function(widget, hovered)
                widget:setColor(hovered and "#88FF88" or "#00FF00")
            end
            actionButton.onClick = function()
                MissionInterface.toggleMissionAction()
            end
        end
    end
end


end


function MissionInterface.setFilter(filterType)
  MissionInterface.updateFilterHighlight(filterType)

  local filteredMissions = {}

if filterType == "all" then
    filteredMissions = MissionInterface.missions or {}
else
    for _, mission in ipairs(MissionInterface.missions or {}) do
      if mission.type == filterType then
        table.insert(filteredMissions, mission)
      end
    end
  end

  MissionInterface.populateMissionList(filteredMissions)
end

function MissionInterface.updateFilterHighlight(selectedFilter)
  if not missionWindow then return end

  local tabs = {
    all = "tabAll",
    task = "tabTask",
    quest = "tabQuest",
    npc = "tabNpc"
  }

  for filter, tabId in pairs(tabs) do
    local tab = missionWindow:recursiveGetChildById(tabId)
    if tab then
      if filter == selectedFilter then
        tab:setOn(true)
      else
        tab:setOn(false)
      end
    end
  end
end

MissionInterface.currentFilter = "all"
MissionInterface.currentSearch = ""

function MissionInterface.setFilter(filterType)
  print("[MissionInterface] Filtro aplicado: " .. filterType)
  MissionInterface.currentFilter = filterType
  MissionInterface.currentSearch = "" -- Sempre limpa a busca ao trocar filtro

  local searchBox = missionWindow:recursiveGetChildById('missionSearch')
  if searchBox then
    searchBox:setText("")
  end

  MissionInterface.updateFilterHighlight(filterType)
  MissionInterface.applyCurrentFilters()
end


function MissionInterface.applyCurrentFilters(searchText)
  local filterType = MissionInterface.currentFilter
  MissionInterface.currentSearch = searchText or MissionInterface.currentSearch or ""

  local list = missionWindow:recursiveGetChildById('missionList')
  if not list then return end

  local showCompleted = false
  local checkBox = missionWindow:recursiveGetChildById('showCompletedCheck')
  if checkBox and checkBox:isChecked() then
    showCompleted = true
  end

  local filteredMissions = {}

  for _, mission in ipairs(MissionInterface.missions or {}) do
    local matchesFilter = (filterType == "all") or (mission.type == filterType)
    local matchesSearch = (MissionInterface.currentSearch == "") or (mission.name:lower():find(MissionInterface.currentSearch:lower(), 1, true))
    local matchesCompletion = showCompleted or (not mission.completed)

    if matchesFilter and matchesSearch and matchesCompletion then
      table.insert(filteredMissions, mission)
    end
  end

  MissionInterface.populateMissionList(filteredMissions)
end

function MissionInterface.toggleMissionAction()
  local mission = MissionInterface.currentSelectedMission
  if not mission then return end

  -- Se já está na missão, enviar comando para cancelar
  local action = mission.started and "cancel" or "start"

  -- Envia para o servidor via opcode
  if g_game.isOnline() then
    g_game.getProtocolGame():sendExtendedOpcode(210, json.encode({
      action = action,
      missionName = mission.name
    }))
  end
end

function MissionInterface.showObjectiveDetails(entry)
  if not entry or not MissionInterface.currentSelectedMission then return end

  local list = missionWindow:recursiveGetChildById('objectiveList')
  if not list then return end

local index = entry.objectiveIndex
local objective = MissionInterface.currentSelectedMission.objectives[index]


  if not objective then
    print("[MissionInterface] Nenhum objetivo encontrado nesse index: " .. index)
    return
  end

  local detailButton = entry:getChildById('objectiveHeader') and entry:getChildById('objectiveHeader'):getChildById('objectiveDetailButton')

  -- Se já tem descrição aberta, fecha (toggle)
  local descPanel = entry:getChildById('objectiveDescriptionPanel')
  if descPanel then
    descPanel:destroy()
    entry:setHeight(20) -- Volta altura original

    if detailButton then
      detailButton:setText("+")
      detailButton:setTooltip("Exibir mais informações")
    end
    return
  end

  -- Cria o painel de descrição
  local newDescPanel = g_ui.createWidget('ObjectiveDescriptionPanel', entry)
  newDescPanel:setId('objectiveDescriptionPanel')

  local descLabel = newDescPanel:getChildById('objectiveDescriptionLabel')
  if descLabel then
    descLabel:setText(objective.description or "Sem descrição disponível.")
  end

  -- Ajusta altura
  entry:setHeight(60)

  -- Atualiza botão pra modo "fechar"
  if detailButton then
    detailButton:setText("-")
    detailButton:setTooltip("Ocultar informações extras")
  end
end
