modules.game_pass = {}
local Pass = modules.game_pass

-- =========================
-- Constantes / Estado
-- =========================
local OPCODE = 17
local window, timeLeft, timeUpdateEvent
local HAS_VIP = false

-- ? Config vindas do servidor (fallbacks até chegar o pacote passConfig)
local XP_PER_LEVEL, VIP_PRICE, LEVEL_PRICE
local function getXpPerLevel() return XP_PER_LEVEL or 100 end
local function getVipPrice()   return VIP_PRICE    or 500 end
local function getLevelPrice() return LEVEL_PRICE  or 100 end

Pass.TypeIcons = {
  kill    = nil, -- usa looktype do monstro
  npc     = nil, -- usa looktype do npc
  pvp     = "images/mission/pvp.png",
  quest   = "images/mission/quest.png",
  upgrade = "images/mission/upgrade.png"
}
-- =========================
-- Helpers
-- =========================
local function sendOpcode(payload)
  if g_game.isOnline() then
    g_game.getProtocolGame():sendExtendedOpcode(OPCODE, json.encode(payload))
  end
end

local function applyVipState()
  if not window then return end
  local upgradeButton = window:recursiveGetChildById('headerButton') -- botão ?UPGRADE / Comprar Passe VIP?
  if upgradeButton then
    upgradeButton:setVisible(not HAS_VIP)   -- invisível se já for VIP
  end
  -- (opcional) mostrar uma fitinha ?VIP? se tiver no .otui:
  local vipRibbon = window:recursiveGetChildById('vipRibbon')
  if vipRibbon then vipRibbon:setVisible(HAS_VIP) end
end

local function confirm(title, message, onYes)
  local box
  box = displayGeneralBox(title, message, {
    { text = "Sim", callback = function() if onYes then onYes() end if box then box:destroy() end end },
    { text = "Não", callback = function()                        if box then box:destroy() end end },
  })
end

local function killTimer()
  if timeUpdateEvent then
    removeEvent(timeUpdateEvent)
    timeUpdateEvent = nil
  end
end

-- =========================
-- Ciclo de vida
-- =========================
function Pass.init() end

function Pass.terminate()
  Pass.hide()
end

-- =========================
-- Janela
-- =========================
function Pass.toggle()
  if window and window:isVisible() then
    Pass.hide()
  else
    Pass.show()
  end
end

function Pass.show()
  if not window then
    window = g_ui.displayUI('pass')

    -- Comprar Passe VIP
    local upgradeButton = window:recursiveGetChildById('headerButton')
    if upgradeButton then
      upgradeButton.onClick = function()
        local price = getVipPrice()
        confirm("Confirmação",
          string.format("Deseja adquirir o Passe VIP por %d Premium Points?", price),
          function()
            -- feedback imediato
            upgradeButton:setEnabled(false)
            upgradeButton:setText("Processando...")

            sendOpcode({ action = "buyVipPass" })
            -- peça ao servidor para reenviar passData (ver passo 3)
            scheduleEvent(function()
              sendOpcode({ action = "passDataRequest" })
            end, 300)
          end
        )
      end
    end

    -- Coletar todas
    local collectAllButton = window:recursiveGetChildById('collectAllButton')
    if collectAllButton then
      collectAllButton.onClick = function()
        confirm("Confirmação",
          "Deseja coletar todas as recompensas pendentes do Passe de Batalha?",
          function() sendOpcode({ action = "claimAllRewards" }) end
        )
      end
    end

    -- Comprar +1 nível
    local buyLevelButton = window:recursiveGetChildById('buyLevelButton')
    if buyLevelButton then
      buyLevelButton.onClick = function()
        local price = getLevelPrice()
        confirm("Confirmação",
          string.format("Deseja comprar +1 nível no Passe de Batalha por %d Premium Points?", price),
          function() sendOpcode({ action = "buyLevel" }) end
        )
      end
    end
  end
  applyVipState() -- aplica visibilidade inicial
  sendOpcode({ action = "passDataRequest" })
  window:show()
  window:raise()
  window:focus()
  Pass.loadProgressPreview()
  Pass.loadMissions()
  Pass.loadRewards()
end


function Pass.hide()
  if not window then return end
  killTimer()
  window:hide()
end

-- =========================
-- Protocolo
-- =========================
ProtocolGame.registerExtendedOpcode(OPCODE, function(_, _, buffer)
  local data = json.decode(buffer)
  if not data or not data.action then return end
  if not window or not window:isVisible() then return end

  -- passData: vem com passLevel, passXP e isVip
  if data.action == "passData" then
    if data.isVip ~= nil then
      HAS_VIP = (tonumber(data.isVip) == 1) or (data.isVip == true)
      applyVipState()
    end
    return
  end

  -- Config global do passe
  if data.action == "passConfig" then
  if data.xpPerLevel then XP_PER_LEVEL = tonumber(data.xpPerLevel) end
  if data.vipPrice   then VIP_PRICE    = tonumber(data.vipPrice)   end
  if data.levelPrice then LEVEL_PRICE  = tonumber(data.levelPrice) end
  return
end


  -- Progresso
  if data.action == "progressInfo" then
    local progressPanel = window:getChildById("progressPanel"); if not progressPanel then return end

    local nameLabel       = progressPanel:recursiveGetChildById("characterNameLabel")
    local passLevelLabel  = progressPanel:recursiveGetChildById("passLevelLabel")
    local xpLabel         = progressPanel:recursiveGetChildById("xpLabel")
    local progressBarFill = progressPanel:recursiveGetChildById("progressBarFill")
    local progressBarPane = progressPanel:recursiveGetChildById("progressBarPanel")
    local timeLabel       = progressPanel:recursiveGetChildById("headerTime")
    local outfitPanel     = progressPanel:recursiveGetChildById("characterOutfit")
    local outfitBox       = outfitPanel and outfitPanel:getChildById("outfitBox")

    if nameLabel      then nameLabel:setText("Nome: " .. (data.playerName or "Desconhecido")) end
    if passLevelLabel then passLevelLabel:setText("Nível do Passe: " .. (data.passLevel or 0)) end

    if xpLabel and progressBarFill and progressBarPane then
      local currentXP = data.passXP or 0
      local required  = getXpPerLevel()
      local percent   = math.min(100, math.floor((currentXP / required) * 100))
      xpLabel:setText(string.format("XP: %d/%d", currentXP, required))
      progressBarFill:setWidth(math.floor(percent * progressBarPane:getWidth() / 100))
    end
    if data.action == "passData" then
      -- servidor envia: passLevel, passXP, isVip
      if data.isVip ~= nil then
        HAS_VIP = (tonumber(data.isVip) == 1) or (data.isVip == true)
        applyVipState()
      end
      return
    end

    if outfitBox and data.outfit then
      outfitBox:setOutfit({ type = data.outfit })
      outfitBox:setAnimate(true)
    end

    if timeLabel and data.timeLeft then
      timeLeft = tonumber(data.timeLeft) or 0
      killTimer()
      local function tick()
        if not timeLabel then return end
        if timeLeft <= 0 then timeLabel:setText("0 dias 00:00:00"); return end
        local days    = math.floor(timeLeft / 86400)
        local hours   = math.floor((timeLeft % 86400) / 3600)
        local minutes = math.floor((timeLeft % 3600) / 60)
        local seconds = timeLeft % 60
        timeLabel:setText(string.format("%d dias %02d:%02d:%02d", days, hours, minutes, seconds))
        timeLeft = timeLeft - 1
        timeUpdateEvent = scheduleEvent(tick, 1000)
      end
      tick()
    end
  end

  -- Missões
  if data.action == "missionsInfo" and data.missions then
    local missionScroll = window:recursiveGetChildById("missionScroll"); if not missionScroll then return end
    missionScroll:destroyChildren()

    for _, mission in ipairs(data.missions) do
      local iconPath = (not mission.isCreature and mission.type) and Pass.TypeIcons[mission.type] or nil
      local progress = mission.progress or 0
      local count    = math.max(mission.count or 1, 1)
      local pct      = math.min(1, progress / count)

      addMissionCard(
        missionScroll,
        iconPath,
        mission.name,
        mission.description,
        pct,
        mission.isCreature,
        mission.creatureLooktype,
        mission.isCompleted or false,
        mission.rewards or {}
      )
    end
  end

  -- Recompensas
  if data.action == "rewardsInfo" and data.rewards then
    local rewards    = data.rewards
    local freeList   = rewards.free or {}
    local vipList    = rewards.vip or {}
    local playerLvl  = rewards.passLevel or 0

    local freePanel = window:recursiveGetChildById('rewardsListFree')
    local vipPanel  = window:recursiveGetChildById('rewardsListVip')
    local mainPanel = window:recursiveGetChildById('rewardsMainPanel')
    if not freePanel or not vipPanel or not mainPanel then return end

    freePanel:destroyChildren()
    vipPanel:destroyChildren()

    local function addReward(reward, container)
      local widget = g_ui.createWidget('RewardItemTemplate', container); if not widget then return end

      local label       = widget:recursiveGetChildById('rewardLabel')
      local item        = widget:getChildById('rewardItem')
      local icon        = widget:getChildById('rewardTypeIcon')
      local statusIcon  = widget:recursiveGetChildById('rewardStatusIcon')
      local progressBar = widget:recursiveGetChildById('rewardProgressBar')

      local isVip = container:getId() == "rewardsListVip"
      local level = reward.level or container:getChildCount()

      if icon then
        icon:setIcon(isVip and "images/icons/diamond.png" or "images/icons/present.png")
        icon:setTooltip(isVip and "Recompensa VIP" or "Recompensa Free")
      end

      if statusIcon then
        if reward.status == "claimed" then
          statusIcon:setImageSource("images/icons/complete.png")
          statusIcon:setTooltip("Recompensa coletada")
        elseif reward.status == "available" then
          statusIcon:setImageSource("images/icons/loading.png")
          statusIcon:setTooltip("Clique para coletar esta recompensa")
        else
          statusIcon:setImageSource("images/icons/loading.png")
          statusIcon:setTooltip("Em progresso")
        end
      end

      if label then label:setText(string.format("Nível %d", level)) end
      if item  then
        item:setItemId(reward.itemId)
        item:setTooltip(string.format("%s x%d", reward.name, reward.count or 1))
      end

      if progressBar then
        local playerXP = rewards.playerXP or 0
        local percent  = 0
        if level <= playerLvl then
          percent = 100
        elseif level == playerLvl + 1 then
          local need = tonumber(reward.requiredXP) or getXpPerLevel()
          percent = math.min(100, math.floor((playerXP / need) * 100))
        else
          percent = 0
        end 

        progressBar:setPercent(percent)
        progressBar:setTooltip(string.format("%d%%", percent))
        progressBar:setColor(percent >= 100 and '#00FF00' or '#FFD700')
      end

      -- Clique para coletar
      widget.onClick = function()
        sendOpcode({
          action     = "claimReward",
          rewardType = isVip and "vip" or "free",
          level      = level
        })
      end
    end

    for _, r in ipairs(freeList) do addReward(r, freePanel) end
    for _, r in ipairs(vipList)  do addReward(r, vipPanel)  end

    local function setPanelHeight(panel, count)
      local h, gap = 70, 6
      if count <= 0 then panel:setHeight(0) return end
      panel:setHeight((h * count) + (gap * (count - 1)))
    end

    setPanelHeight(freePanel, #freeList)
    setPanelHeight(vipPanel,  #vipList)

    local maxCount       = math.max(#freeList, #vipList)
    local mainBaseHeight = (65 * maxCount) + (3 * math.max(maxCount - 1, 0))
    local marginTop      = 80
    mainPanel:setHeight(mainBaseHeight + marginTop)

    -- Próximas recompensas
    Pass.updateUpcomingRewards(freeList, vipList, playerLvl)
  end
end)

-- =========================
-- Abas / Requests
-- =========================
function Pass.switchToTab(tabId)
  if not window then return end

  local panels = {
    missionsPanel = window:getChildById('missionsPanel'),
    progressPanel = window:getChildById('progressPanel'),
    rewardsPanel  = window:getChildById('rewardsPanel'),
  }

  for id, panel in pairs(panels) do
    if panel then panel:setVisible(id == tabId) end
  end

  if     tabId == "progressPanel" then sendOpcode({ action = "progressRequest" })
  elseif tabId == "missionsPanel" then sendOpcode({ action = "missionsRequest" })
  elseif tabId == "rewardsPanel"  then Pass.loadRewards(); sendOpcode({ action = "rewardsRequest" }) end
end

function Pass.loadProgressPreview()
  if not window then return end
  sendOpcode({ action = "progressRequest" })
end

function Pass.loadMissions()
  if not window then return end
  sendOpcode({ action = "missionsRequest" })
end

function Pass.loadRewards()
  if not window then return end
  sendOpcode({ action = "rewardsRequest" })
end

-- =========================
-- Missões ? Card
-- =========================
function addMissionCard(parent, iconPath, name, description, progressPercent, isCreature, creatureLooktype, isCompleted, rewards)
  rewards = rewards or {}

  local card = g_ui.createWidget("MissionCard", parent); if not card then return end

  local iconPanel = card:getChildById("missionIconPanel")
  if iconPanel then
    if isCreature then
      local outfit = g_ui.createWidget("CreatureOutfitPass", iconPanel)
      outfit:setId("CreatureOutfitPassWidget")
      outfit:addAnchor(AnchorHorizontalCenter, "parent", AnchorHorizontalCenter)
      outfit:addAnchor(AnchorVerticalCenter,   "parent", AnchorVerticalCenter)
      outfit:setPhantom(true)

      if outfit.outfitBox then
        local outfitBox = outfit.outfitBox
        outfitBox:setOutfit({ type = creatureLooktype or 1 })
        outfitBox:setTooltip(name)
        outfitBox:setSize("72 72")
        outfitBox:setMargin(0)
      end
    else
      local icon = g_ui.createWidget("UIWidget", iconPanel)
      icon:setImageSource(iconPath)
      icon:setSize({ width = 84, height = 84 })
      icon:addAnchor(AnchorHorizontalCenter, "parent", AnchorHorizontalCenter)
      icon:addAnchor(AnchorVerticalCenter,   "parent", AnchorVerticalCenter)
      icon:setId("staticIcon")
    end

    local badgeRight = iconPanel:recursiveGetChildById("badgeIconRight")
    if badgeRight then
      if isCompleted then
        badgeRight:setImageSource("images/icons/complete.png")
        badgeRight:setTooltip("Missão concluída")
      else
        badgeRight:setImageSource("images/icons/loading.png")
        badgeRight:setTooltip("Missão em andamento")
      end
    end

    local badge1 = iconPanel:recursiveGetChildById("badgeIcon1")
    if badge1 then
      if rewards.exp and rewards.exp > 0 then
        badge1:setTooltip(rewards.exp .. " XP")
        badge1:setOpacity(1.0)
      else
        badge1:setTooltip("Sem recompensa de XP")
        badge1:setOpacity(0.25)
      end
    end

    local badge2 = iconPanel:recursiveGetChildById("badgeIcon2")
    if badge2 then
      if rewards.graduation and rewards.graduation > 0 then
        badge2:setTooltip(rewards.graduation .. " Elo Points")
        badge2:setOpacity(1.0)
      else
        badge2:setTooltip("Sem recompensa de Elo")
        badge2:setOpacity(0.25)
      end
    end

    local badge3 = iconPanel:recursiveGetChildById("badgeIcon3")
    if badge3 then
      if rewards.defensive and rewards.defensive > 0 then
        badge3:setTooltip(rewards.defensive .. " Defesa")
        badge3:setOpacity(1.0)
      else
        badge3:setTooltip("Sem recompensa defensiva")
        badge3:setOpacity(0.25)
      end
    end
  end

  local title = card:getChildById("missionName"); if title then title:setText(name) end
  local desc  = card:getChildById("missionDescription"); if desc then desc:setText(description) end

  local progressBar = card:getChildById("missionProgressBar")
  if progressBar then
    local fill  = progressBar:getChildById("missionProgressFill")
    local label = progressBar:getChildById("missionProgressLabel")
    if fill  then fill:setPercent((progressPercent or 0) * 100) end
    if label then label:setText(string.format("%d%%", math.floor((progressPercent or 0) * 100))) end
  end
end

-- =========================
-- Recompensas ? Próximas
-- =========================
function Pass.updateUpcomingRewards(freeRewards, vipRewards, playerLevel)
  if not window then return end

  local freeLeft  = window:recursiveGetChildById("freeRewardItemsLeft")
  local freeRight = window:recursiveGetChildById("freeRewardItemsRight")
  local vipLeft   = window:recursiveGetChildById("vipRewardItemsLeft")
  local vipRight  = window:recursiveGetChildById("vipRewardItemsRight")

  local function setItem(panel, slotId, reward)
    if not panel then return end
    local item = panel:getChildById(slotId)
    if not item then return end
    if reward then
      item:setItemId(reward.itemId)
      item:setTooltip(string.format("%s x%d", reward.name, reward.count or 1))
    else
      item:setItemId(0)
      item:setTooltip("")
    end
  end

  local nextFree, nextVip = {}, {}
  for _, r in ipairs(freeRewards) do
    if r.level > playerLevel then table.insert(nextFree, r); if #nextFree >= 2 then break end end
  end
  for _, r in ipairs(vipRewards) do
    if r.level > playerLevel then table.insert(nextVip, r);  if #nextVip  >= 2 then break end end
  end

  setItem(freeLeft,  "item1", nextFree[1])
  setItem(freeRight, "item2", nextFree[2])
  setItem(vipLeft,   "item1", nextVip[1])
  setItem(vipRight,  "item2", nextVip[2])
end
