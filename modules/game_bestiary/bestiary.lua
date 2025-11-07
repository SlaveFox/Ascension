local function updateCharmUI(main, charmWidget, canOutfit, selectPoints)
    local purchased = charmWidget.purchased
    local hasRune = charmWidget.rune
    local removeCostValue = tonumber(charmWidget:recursiveGetChildById('ValueFix'):getText()) or 0
    local canUpgrade = charmWidget.canUpgrade or false
    local nextLevelPrice = charmWidget.nextLevelPrice or 0
    local charmsPoints = tonumber(main:recursiveGetChildById('charmsPoints'):getText()) or 0
    local extraCharmsPoints = tonumber(main:recursiveGetChildById('extraCharmsPoints'):getText()) or 0

    if not purchased then
        main:recursiveGetChildById('UnlockButton'):setText("Desbloquear")
        local charmCoinValue = charmWidget.charmCoin or selectPoints
        local hasEnoughPoints = false
        if charmWidget.category == "minor" then
          hasEnoughPoints = extraCharmsPoints >= charmCoinValue
        else
          hasEnoughPoints = charmsPoints >= charmCoinValue
        end
        main:recursiveGetChildById('UnlockButton'):setEnabled(hasEnoughPoints)
        
        main:recursiveGetChildById('PriceBaseMain'):getChildById('Value'):setText(charmCoinValue)
        main:recursiveGetChildById('PriceBaseMain'):getChildById('Gold'):setVisible(false)
        main:recursiveGetChildById('PriceBaseMain'):getChildById('Charm'):setVisible(true)
        if charmWidget.category == "minor" then
          main:recursiveGetChildById('PriceBaseMain'):getChildById('Charm'):setImageSource("images/ui/minor-charm-echoes")
        else
          main:recursiveGetChildById('PriceBaseMain'):getChildById('Charm'):setImageSource("images/ui/icon_charms")
        end
        main:recursiveGetChildById('PriceBaseMain'):setVisible(true)
        
        main:recursiveGetChildById('UnlockCost'):setVisible(false)
        main:recursiveGetChildById('UpgradeButton'):setVisible(false)
        main:recursiveGetChildById('CreatureList'):hide()
    else
        if not hasRune then
            main:recursiveGetChildById('UnlockButton'):setText("Selecionar")
            main:recursiveGetChildById('UnlockButton'):setEnabled(canOutfit)
        else
            main:recursiveGetChildById('UnlockButton'):setText("Remover")
            main:recursiveGetChildById('UnlockButton'):setEnabled(true)
        end
        main:recursiveGetChildById('CreatureList'):show()
        
        if canUpgrade and nextLevelPrice > 0 then
            main:recursiveGetChildById('UpgradeButton'):setVisible(true)
            local hasEnoughPoints = false
            if charmWidget.category == "minor" then
                hasEnoughPoints = extraCharmsPoints >= nextLevelPrice
            else
                hasEnoughPoints = charmsPoints >= nextLevelPrice
            end
            main:recursiveGetChildById('UpgradeButton'):setEnabled(hasEnoughPoints)
            main:recursiveGetChildById('UpgradeButton'):setText('Upgrade')
            
            main:recursiveGetChildById('UnlockCost'):getChildById('UnlockValue'):setText(nextLevelPrice)
            main:recursiveGetChildById('UnlockCost'):getChildById('UnlockGoldIcon'):setVisible(false)
            main:recursiveGetChildById('UnlockCost'):getChildById('UnlockCharmIcon'):setVisible(true)
            if charmWidget.category == "minor" then
                main:recursiveGetChildById('UnlockCost'):getChildById('UnlockCharmIcon'):setImageSource("images/ui/minor-charm-echoes")
            else
                main:recursiveGetChildById('UnlockCost'):getChildById('UnlockCharmIcon'):setImageSource("images/ui/icon_charms")
            end
            main:recursiveGetChildById('UnlockCost'):setVisible(true)
            
            main:recursiveGetChildById('PriceBaseMain'):getChildById('Value'):setText(formatMoney(removeCostValue))
            main:recursiveGetChildById('PriceBaseMain'):getChildById('Gold'):setVisible(true)
            main:recursiveGetChildById('PriceBaseMain'):getChildById('Charm'):setVisible(false)
            main:recursiveGetChildById('PriceBaseMain'):setVisible(true)
        else
            main:recursiveGetChildById('UpgradeButton'):setVisible(true)
            main:recursiveGetChildById('UpgradeButton'):setEnabled(false)
            main:recursiveGetChildById('UpgradeButton'):setText('Upgrade')
            main:recursiveGetChildById('UnlockCost'):setVisible(false)
            
            main:recursiveGetChildById('PriceBaseMain'):getChildById('Value'):setText(formatMoney(removeCostValue))
            main:recursiveGetChildById('PriceBaseMain'):getChildById('Gold'):setVisible(true)
            main:recursiveGetChildById('PriceBaseMain'):getChildById('Charm'):setVisible(false)
            main:recursiveGetChildById('PriceBaseMain'):setVisible(true)
        end
    end
end

local function setItemBaseBackdrop(main, purchased, level)
    local itemBase = main:recursiveGetChildById('ItemBase')
    if not itemBase then return end

    local bg = "images/ui/bestiary-charm-bg"
    if purchased then
        local lv = tonumber(level) or 1
        if lv >= 3 then
            bg = "images/ui/backdrop_charmgrade3"
        elseif lv == 2 then
            bg = "images/ui/backdrop_charmgrade2"
        else
            bg = "images/ui/backdrop_charmgrade1"
        end
    end

    itemBase:setImageSource(bg)
    if itemBase.setImageBorder then
        itemBase:setImageBorder(10)
    end
end
G_BESTIARY = {}

G_BESTIARY.COLORS = {
    primary = {
        bg = "#484848",
        border = "#666666", 
        text = "#C0C0C0",
        hover = "#5A5A5A",
        hoverBorder = "#888888"
    },
    
    selection = {
        bg = "#6B8E23",
        border = "#90EE90",
        text = "#FFFFFF",
        hoverBg = "#7BA023",
        hoverBorder = "#A0EEA0"
    },
    
    state = {
        success = "#4CAF50",
        warning = "#FF9800", 
        error = "#F44336",
        info = "#2196F3",
        disabled = "#666666"
    },
    
    background = {
        main = "#2C2C2C",
        panel = "#3C3C3C",
        card = "#404040",
        overlay = "#00000080"
    }
}

G_BESTIARY.SPACING = {
    xs = 2,
    sm = 5,
    md = 10,
    lg = 15,
    xl = 20,
    xxl = 25
}

G_BESTIARY.ANIMATIONS = {
    duration = {
        fast = 150,
        normal = 250,
        slow = 400
    },
    easing = "ease-in-out"
}


local CONFIG = {
    CLIENT_OPCODE = 91,
    SERVER_OPCODE = 92
}

local BACK_TYPE = {
    NONE = 0,
    CATEGORIES = 1,
    CREATURES = 2,
    CREATURE = 3,
    SEARCH = 4
}

local difficultys = {
    [1] = "Inofensivo",
    [2] = "Trivial",
    [3] = "Facil",
    [4] = "Medio",
    [5] = "Dificil"
}

local lootTypes = {
    [1] = "Comum",
    [2] = "Incomum",
    [3] = "Semi-Raro",
    [4] = "Muito Raro"
}

local occurrences = {
    [1] = "Comum",
    [2] = "Incomum",
    [3] = "Raro",
    [4] = "Muito Raro"
}

local categories = {
    [1] = {class = "amphibic", image = "images/creatures/amphibic"},
    [2] = {class = "aquatic", image = "images/creatures/aquatic"},
    [3] = {class = "bird", image = "images/creatures/bird"},
    [4] = {class = "construct", image = "images/creatures/construct"},
    [5] = {class = "dragon", image = "images/creatures/dragon"},
    [6] = {class = "elemental", image = "images/creatures/elemental"},
    [7] = {class = "extra dimensional", image = "images/creatures/extra_dimensional"},
    [8] = {class = "fey", image = "images/creatures/fey"},
    [9] = {class = "giant", image = "images/creatures/giant"},
    [10] = {class = "human", image = "images/creatures/human"},
    [11] = {class = "humanoid", image = "images/creatures/humanoid"},
    [12] = {class = "lycanthrope", image = "images/creatures/lycanthrope"},
    [13] = {class = "magical", image = "images/creatures/magical"},
    [14] = {class = "mammal", image = "images/creatures/mammal"},
    [15] = {class = "plant", image = "images/creatures/plant"},
    [16] = {class = "slime", image = "images/creatures/slime"},
    [17] = {class = "undead", image = "images/creatures/undead"},
    [18] = {class = "vermin", image = "images/creatures/vermin"},
    [19] = {class = "reptile", image = "images/creatures/reptile"},
    [20] = {class = "immortals", image = "images/creatures/immortals"},
    [21] = {class = "demon", image = "images/creatures/demon"}
}

function formatWidgetName(name)
    local maxLen = 20
    if name:len() > maxLen then
        return name:sub(1, maxLen) .. "..."
    end

    return name
end

function closeBestiaryWindow()
    G_BESTIARY.UI:hide()
    modules.game_interface.getRootPanel():focus()
    if G_BESTIARY.Tracker.UI.bestiaryWindowButton then
        G_BESTIARY.Tracker.UI.bestiaryWindowButton:setOn(false)
    end
    resetAllWidgetOpacity(G_BESTIARY.UI)
    
    if G_BESTIARY.UI and G_BESTIARY.UI:getChildById("search") then
        G_BESTIARY.UI:getChildById("search"):setText("")
    end
    if G_BESTIARY.UI and G_BESTIARY.UI:getChildById("SearchEdit") then
        G_BESTIARY.UI:getChildById("SearchEdit"):setText("")
    end
end

function openBestiaryWindow()

    
    if G_BESTIARY.Tracker.UI.bestiaryWindowButton then
        G_BESTIARY.Tracker.UI.bestiaryWindowButton:setOn(true)
    end
    G_BESTIARY.UI:show()

    if not G_BESTIARY.Tracker.UI:isVisible() then
        G_BESTIARY.Tracker.UI:open()
    end

    G_BESTIARY.UI.panel.creature:setVisible(false)
    G_BESTIARY.UI.panel.categories:setVisible(true)
    G_BESTIARY.UI.closeButton.backType = BACK_TYPE.NONE

    if G_BESTIARY.UI:getChildById("search") then
        G_BESTIARY.UI:getChildById("search"):setText("")
    end
    
    scheduleEvent(function()
        applyVisualImprovements()
        setupCreatureFilters()
        setupResponsiveLayout()
    end, 100)
    if G_BESTIARY.UI:getChildById("SearchEdit") then
        G_BESTIARY.UI:getChildById("SearchEdit"):setText("")
    end

    if G_BESTIARY.needUpdateData() then

        G_BESTIARY.categories = {}
        G_BESTIARY.send("requestData")
    else

    end
    

end

function toggle()
    if G_BESTIARY.Tracker.UI.bestiaryWindowButton and G_BESTIARY.Tracker.UI.bestiaryWindowButton:isOn() then
        closeBestiaryWindow()
    else
        openBestiaryWindow()
    end
end

local function getKillStage(kills, stages)
    if kills >= stages[3] then
        return 3
    elseif kills >= stages[2] then
        return 2
    elseif kills >= stages[1] then
        return 1
    end
    return 0
end

local function formatFileName(str) 
    if string.find(str, " ") then
        return string.gsub(str, " ", "_")
    else
        return str
    end
end

local function getElementColor(element)
	if element == 66 then
		return "white"
	end
	return "red"
end

local function updateBestiaryKill(name, kills)
    for _, data in pairs(G_BESTIARY.data) do
        for _, creature in ipairs(data) do
            if creature.name == name then
                if creature.kills <= creature.stages[3] then
                    creature.kills = kills
                end
                return true
            end
        end
    end
    return false
end

local function updateBestiaryCreature(data)
    for i, t_data in pairs(G_BESTIARY.data) do
        for y, creature in ipairs(t_data) do
            if creature.name == data.name then
                G_BESTIARY.data[i][y] = data
                return true
            end
        end
    end
    return false
end

local function getCreatureByName(name)
    if not name or name == "" then
        return nil
    end
    
    local searchName = name:lower()
    for _, data in pairs(G_BESTIARY.data) do
        for _, creature in ipairs(data) do
            if creature.name:lower() == searchName then
                return creature
            end
        end
    end
    return nil
end

local function searchCreaturesByName(searchText)
    if not searchText or searchText == "" then
        return {}
    end
    
    local results = {}
    local searchLower = searchText:lower()
    
    for _, data in pairs(G_BESTIARY.data) do
        for _, creature in ipairs(data) do
            if creature.name:lower():find(searchLower, 1, true) then
                table.insert(results, creature)
            end
        end
    end
    
    return results
end

local function getCreatureClass(name)
    local creature = getCreatureByName(name) 
    if creature then
        return creature.class
    end
    return nil
end


local function getCategoryByName(name)
    for _, categorie in ipairs(categories) do
        if categorie.class:lower() == name:lower() then
            return categorie
        end
    end
    return nil
end

local function getRarity(chance)
    if chance <= 1000 then
        return 4
    elseif chance <= 5000 then
        return 3
    elseif chance <= 20000 then
        return 2
    else
        return 1
    end
end

G_BESTIARY.init = function()
    G_BESTIARY.UI = g_ui.displayUI("bestiary", modules.game_interface.getRightPanel())
    
    if not G_BESTIARY.UI then
        error("[Bestiary] Failed to load bestiary UI")
        return
    end

    G_BESTIARY.Tracker = {}
    G_BESTIARY.Tracker.UI = g_ui.loadUI("bestiary_tracker", modules.game_interface.getRightPanel())
    
    if not G_BESTIARY.Tracker.UI then
        error("[Bestiary] Failed to load bestiary tracker UI")
        return
    end
    
    G_BESTIARY.Tracker.UI:setContentMinimumHeight(43)

    G_BESTIARY.trackerData = {}
    G_BESTIARY.data = {}
    G_BESTIARY.categories = {}
    G_BESTIARY.playerName = ""
    G_BESTIARY.charmsData = { major = {}, minor = {} }
    G_BESTIARY.currentCharmCategory = "major"
    G_BESTIARY.selectedCharmId = nil

    G_BESTIARY.Tracker.UI.closeButton = toggleTracker
    
    G_BESTIARY.define()

    if G_BESTIARY.UI and G_BESTIARY.UI.closeButton then
        G_BESTIARY.UI:hide()
        G_BESTIARY.UI.closeButton.backType = BACK_TYPE.NONE
    end

    ProtocolGame.registerExtendedJSONOpcode(CONFIG.SERVER_OPCODE, G_BESTIARY.reciver)
    connect(g_game, {onGameStart = G_BESTIARY.onStart, onGameEnd = G_BESTIARY.onEnd})
    
    if(g_game.isOnline()) then
        G_BESTIARY.onStart()
    end
end

G_BESTIARY.terminate = function()
    disconnect(g_game, {onGameStart = G_BESTIARY.onStart, onGameEnd = G_BESTIARY.onEnd})
    ProtocolGame.unregisterExtendedJSONOpcode(CONFIG.SERVER_OPCODE)
    G_BESTIARY.UI:destroy()
    G_BESTIARY.UI = nil

    G_BESTIARY.Tracker.UI:destroy()
    G_BESTIARY.Tracker.UI = nil
    G_BESTIARY.playerName = nil
end

G_BESTIARY.onStart = function()
    G_BESTIARY.playerName =  g_game.getLocalPlayer():getName()
    
    G_BESTIARY.dataReceived = false
    G_BESTIARY.charmsReceived = false
    G_BESTIARY.requestsSent = 0
    G_BESTIARY.responsesReceived = 0
    
    G_BESTIARY.send("requestData")
    G_BESTIARY.load()
    G_BESTIARY.Tracker.UI:setup()
	G_BESTIARY.send("requestCharms")
end

G_BESTIARY.onEnd = function()
    if G_BESTIARY.UI:isVisible() then
        closeBestiaryWindow()
    end
    G_BESTIARY.save()
	for _, charm in pairs(G_BESTIARY.UI:recursiveGetChildById('charmsList'):getChildren()) do
		charm:destroy()
	end
end

G_BESTIARY.define = function()
    G_BESTIARY.resetDifficulty = function()
        for i = 1, 5 do
            G_BESTIARY.UI.panel.creature.difficultyList[i]:setImageSource("images/icons/difficulty-inactive")
        end
    end

    G_BESTIARY.resetOccurrence = function()
        for i = 1, 4 do
            G_BESTIARY.UI.panel.creature.occurrenceList[i]:setImageSource("images/icons/occurrence-inactive")
        end
    end

    G_BESTIARY.selectCreature = function(widget)
        G_BESTIARY.UI.panel.creature.lootPanel.list:destroyChildren()
        G_BESTIARY.UI.panel.categories:setVisible(false)
        G_BESTIARY.UI.panel.creature:setVisible(true)

        G_BESTIARY.resetDifficulty()
        G_BESTIARY.resetOccurrence()

        local creatureWindow = G_BESTIARY.UI.panel.creature
        local creature = widget:getParent().object
        local stage = getKillStage(creature.kills, creature.stages)
        local playerName = g_game.getLocalPlayer():getName()

        G_BESTIARY.selectedCreature = creature

        if not G_BESTIARY.trackerData then
            G_BESTIARY.trackerData = {}
        end

        if not G_BESTIARY.trackerData[creature.name] then
            G_BESTIARY.trackerData[creature.name] = false
        end

        creatureWindow.progressFillLeft.fill:setImageSource("")
        creatureWindow.progressFillMiddle.fill:setImageSource("")
        creatureWindow.progressFillRight.fill:setImageSource("")

        creatureWindow.progressFillLeft.fill:setTooltip("")
        creatureWindow.progressFillMiddle.fill:setTooltip("")
        creatureWindow.progressFillRight.fill:setTooltip("")

        creatureWindow:setText(creature.name)
        creatureWindow.trackKills:setChecked(G_BESTIARY.trackerData[creature.name])

        local formated_loot = {}
        local item_names = {}
        
        if creature.loot and type(creature.loot) == "table" then
            for i, lootItem in ipairs(creature.loot) do
                if lootItem and lootItem.rarity then
                    local rarity = getRarity(tonumber(lootItem.rarity))
                    if not formated_loot[rarity] then
                        formated_loot[rarity] = {}
                    end
                    
                    local itemId = (lootItem.itemId ~= "?") and tonumber(lootItem.itemId) or i
                    local count = (lootItem.count ~= "?") and tonumber(lootItem.count) or 1
                    
                    formated_loot[rarity][itemId] = count
                    
                    if lootItem.name ~= "?" then
                        item_names[itemId] = lootItem.name
                    else
                        item_names[itemId] = "Item Desconhecido"
                    end
                end
            end
        end


        local hasLoot = false
        for rarity, items in pairs(formated_loot) do
            hasLoot = true
            break
        end

        if hasLoot then
            for rarity, items in pairs(formated_loot) do
                local loot = g_ui.createWidget("BestiaryLootObject", creatureWindow.lootPanel.list)
                loot.type:setText(lootTypes[rarity] .. ":")

                local i = 1
                for id, count in pairs(items) do
                    if id <= 0 then
                        loot.items[i].item:setImageSource("images/undefined-item")
                        loot.items[i].item:setShowCount(false)
                        loot.items[i].item:setTooltip("Item Desconhecido")
                    else
                        local isUnknownItem = (id <= #creature.loot and creature.loot[id] and creature.loot[id].itemId == "?")
                        
                        if isUnknownItem then
                            loot.items[i].item:setImageSource("images/undefined-item")
                            loot.items[i].item:setShowCount(false)
                            loot.items[i].item:setTooltip("Item Desconhecido - Mate a criatura para revelar")
                        else
                            loot.items[i].item:setItemId(id)
                            loot.items[i].item:setItemCount(count)
                            loot.items[i].item:setShowCount(true)
                            local itemName = item_names[id] or "Item Desconhecido"
                            loot.items[i].item:setTooltip(itemName)
                        end
                    end

                    i = i + 1
                end
            end
        else
            local noLootMessage = g_ui.createWidget("Label", creatureWindow.lootPanel.list)
            noLootMessage:setText("Nenhuma informacao de loot disponivel.")
            noLootMessage:setTextAlign(AlignCenter)
            noLootMessage:setColor("#888888")
        end

        for i = 1, 5 do
            if i <= creature.difficulty then
                creatureWindow.difficultyList[i]:setImageSource("images/icons/difficulty-active")
            end
            creatureWindow.difficultyList[i]:setTooltip(
                string.format("Dificuldade: %s", difficultys[creature.difficulty])
            )
        end

        for i = 1, 4 do
            if i <= creature.occurrence then
                creatureWindow.occurrenceList[i]:setImageSource("images/icons/occurrence-active")
            end
            creatureWindow.occurrenceList[i]:setTooltip(
                string.format("Ocorrencia: %s", occurrences[creature.occurrence])
            )
        end

  
        if creature.kills > 0 then
            local fill = creatureWindow.progressFillLeft.fill
            fill:setImageSource("images/fill")
            local Yhppc = math.floor(fill:getWidth() * (1 - math.min(1, creature.kills / creature.stages[1])))
            local rect = { x = 0, y = 0, width = math.max(2, fill:getWidth() - Yhppc), height = fill:getHeight() }
            fill:setImageClip(rect)
            fill:setImageRect(rect)
        end

        if stage >= 1 then
            local fill = creatureWindow.progressFillMiddle.fill
            fill:setImageSource("images/fill")

            local Yhppc = math.floor(fill:getWidth() * (1 - math.min(1, (creature.kills - creature.stages[1]) / (creature.stages[2] - creature.stages[1]))))
            local rect = { x = 0, y = 0, width = (creature.kills > 0 and math.max(2, fill:getWidth() - Yhppc) or 0), height =
            fill:getHeight() }
            fill:setImageClip(rect)
            fill:setImageRect(rect)
        end

        if stage >= 2 then
            local fill = creatureWindow.progressFillRight.fill
            fill:setImageSource("images/fill")
            
            local Yhppc = math.floor(fill:getWidth() * (1 - math.min(1, (creature.kills - creature.stages[2]) / (creature.stages[3] - creature.stages[2]))))
            local rect = { x = 0, y = 0, width = (creature.kills > 0 and math.max(2, fill:getWidth() - Yhppc) or 0), height =
            fill:getHeight() }
            fill:setImageClip(rect)
            fill:setImageRect(rect)
        end

        for i = 1, 3 do
            local tooltip = string.format("%d/%d", creature.kills, creature.stages[i])
            if creature.kills >= creature.stages[3] then
                tooltip = tooltip .. " (totalmente desbloqueado)"
            end
            if i == 1 then
                if creature.kills >= creature.stages[3] then
                    creatureWindow.progressFillLeft.fill:setImageSource("images/fill_completed")
                end
                creatureWindow.progressFillLeft:setTooltip(tooltip)
            elseif i == 2 then
                if creature.kills >= creature.stages[3] then
                    creatureWindow.progressFillMiddle.fill:setImageSource("images/fill_completed")
                end
                creatureWindow.progressFillMiddle:setTooltip(tooltip)
            elseif i == 3 then
                if creature.kills >= creature.stages[3] then
                    creatureWindow.progressFillRight.fill:setImageSource("images/fill_completed")
                end
                creatureWindow.progressFillRight:setTooltip(tooltip)
            end
        end

        creatureWindow.progressFillMiddle.value:setText(creature.kills)

        creatureWindow.creaturePanel.lookType:setOutfit(creature.outfit)
        creatureWindow.creaturePanel.lookType:setAnimate(true)

        local resistData = {
            {icon = "images/icons/death-resist.png", tooltip = "Death Resist", resistType = "death"},
            {icon = "images/icons/fire-resist.png", tooltip = "Fire Resist", resistType = "fire"}, 
            {icon = "images/icons/ice-resist.png", tooltip = "Ice Resist", resistType = "ice"},
            {icon = "images/icons/energy-resist.png", tooltip = "Energy Resist", resistType = "energy"},
            {icon = "images/icons/earth-resist.png", tooltip = "Earth Resist", resistType = "earth"},
            {icon = "images/icons/holy-resist.png", tooltip = "Holy Resist", resistType = "holy"}
        }
        
        local hasResistanceData = creature.resistances and type(creature.resistances) == "table"
        local isRevealed = stage > 0
        
        for i = 1, 6 do
            local greenBar = creatureWindow.greenBarsContainer:recursiveGetChildById('greenBar' .. i)
            if greenBar then
                local resistIcon = greenBar:recursiveGetChildById('resistIcon')
                if resistIcon and resistData[i] then
                    resistIcon:setImageSource(resistData[i].icon)
                end
                
                local section1 = greenBar:recursiveGetChildById('section1')
                local section2 = greenBar:recursiveGetChildById('section2')
                local section3 = greenBar:recursiveGetChildById('section3')
                
                if section1 and section2 and section3 then
                    local resistValue = 0
                    local tooltipText = resistData[i].tooltip .. ": ?"
                    
                    if hasResistanceData and isRevealed then
                        resistValue = creature.resistances[resistData[i].resistType] or 0
                        tooltipText = resistData[i].tooltip .. ": " .. resistValue .. "%"
                    end
                    
                    local section1Value = 0
                    local section2Value = 0
                    local section3Value = 0
                    
                    if resistValue > 0 then
                        section1Value = math.min((resistValue / 33.33) * 100, 100)
                        
                        if resistValue > 33.33 then
                            local remainingValue = resistValue - 33.33
                            section2Value = math.min((remainingValue / 33.33) * 100, 100)
                        end
                        
                        if resistValue > 66.66 then
                            local remainingValue = resistValue - 66.66
                            section3Value = math.min((remainingValue / 33.33) * 100, 100)
                        end
                    end
                    
                    pcall(function()
                        section1:setPercent(section1Value)
                        section2:setPercent(section2Value)
                        section3:setPercent(section3Value)
                    end)
                    
                    greenBar:setTooltip(tooltipText)
                    
                    if resistIcon then
                        resistIcon:setTooltip(tooltipText)
                    end
                end
            end
        end

        local attributesPanel = creatureWindow:recursiveGetChildById('attributesList')
        if attributesPanel then
            local hitpointsAttr = attributesPanel:recursiveGetChildById('hitpointsAttribute')
            local experienceAttr = attributesPanel:recursiveGetChildById('experienceAttribute')
            local speedAttr = attributesPanel:recursiveGetChildById('speedAttribute')
            local armorAttr = attributesPanel:recursiveGetChildById('armorAttribute')
            
            local hasAttributeData = creature.attributes and type(creature.attributes) == "table"
            
            if hitpointsAttr then
                local hitpointsValue = hasAttributeData and isRevealed and creature.attributes.hitpoints or "?"
                hitpointsAttr:recursiveGetChildById('hitpointsValue'):setText(tostring(hitpointsValue))
            end
            
            if experienceAttr then
                local experienceValue = hasAttributeData and isRevealed and creature.attributes.experience or "?"
                experienceAttr:recursiveGetChildById('experienceValue'):setText(tostring(experienceValue))
            end
            
            if speedAttr then
                local speedValue = hasAttributeData and isRevealed and creature.attributes.speed or "?"
                speedAttr:recursiveGetChildById('speedValue'):setText(tostring(speedValue))
            end
            
            if armorAttr then
                local armorValue = hasAttributeData and isRevealed and creature.attributes.armor or "?"
                armorAttr:recursiveGetChildById('armorValue'):setText(tostring(armorValue))
            end
        end
        
        local charmDifficulty = creatureWindow:recursiveGetChildById('charmDifficulty')
        if charmDifficulty then
            local charmValue = creature.charmPoints and isRevealed and creature.charmPoints or "?"
            charmDifficulty:recursiveGetChildById('charmValue'):setText(tostring(charmValue))
        end

        local locationsList = creatureWindow:recursiveGetChildById('locationsList')
        if locationsList then
            local locationsText = locationsList:getChildById('locationsText')
            if locationsText then
                if creature.locations and type(creature.locations) == "table" and #creature.locations > 0 then
                    if isRevealed then
                        local locationsString = table.concat(creature.locations, ", ")
                        locationsText:setText(locationsString)
                        locationsText:setColor("#FFFFFF")
                    else
                        locationsText:setText("?")
                        locationsText:setColor("#888888")
                    end
                else
                    locationsText:setText("Nenhuma localização disponível")
                    locationsText:setColor("#888888")
                end
            end
        end

        G_BESTIARY.UI.closeButton.backType = BACK_TYPE.CREATURE
        G_BESTIARY.UI.closeButton:setText("Voltar")
    end

    G_BESTIARY.onTracker = function(widget)
        local creature = G_BESTIARY.selectedCreature
        local playerName = g_game.getLocalPlayer():getName()
        local checked = widget:isChecked()
        G_BESTIARY.trackerData[creature.name] = checked
        G_BESTIARY.Tracker.load()
    end

    G_BESTIARY.selectCategory = function(widget)
        local categoryName = widget:getId()
        if not G_BESTIARY.data[categoryName] and widget:getParent() then
            categoryName = widget:getParent():getId()
        end
        
        G_BESTIARY.UI.panel.categories.list:destroyChildren()

        if not G_BESTIARY.data[categoryName] then
            return error(string.format("[Bestiary] - Bestiary category %s not found.", categoryName))
        end

        for _, obj in pairs(G_BESTIARY.data[categoryName]) do
            local creatureExists = G_BESTIARY.UI.panel.categories.list:getChildById(string.lower(obj.name))
            if not creatureExists then
                local creature = g_ui.createWidget("BestiaryCreature", G_BESTIARY.UI.panel.categories.list)
                local button = creature.button
                creature:setId(string.lower(obj.name))
                creature:setText(formatWidgetName(obj.name))

                if obj.kills > 0 then
                    creature.unlocked:setText(string.format("%d / 3", getKillStage(obj.kills, obj.stages)))
                    button.onClick = G_BESTIARY.selectCreature
                    obj.outfit.shader = ""
                else
                    creature.unlocked:setText("?")
                    obj.outfit.shader = "outfit_black"
                end

                creature.object = obj
                button.creature:setOutfit(obj.outfit)
                button.creature:setAnimate(true)

				creature.outfit = obj.outfit
            end
        end

        G_BESTIARY.UI.closeButton.backType = BACK_TYPE.CREATURES
        G_BESTIARY.UI.closeButton:setText("Voltar")
        G_BESTIARY.selectedCategory = categoryName
    end

    G_BESTIARY.closeBackButton = function(widget)
        if G_BESTIARY.UI.closeButton.backType == BACK_TYPE.CREATURES then
            G_BESTIARY.loadCategories()
            G_BESTIARY.UI.closeButton.backType = BACK_TYPE.CATEGORIES
            return true
        elseif G_BESTIARY.UI.closeButton.backType == BACK_TYPE.CREATURE then
            G_BESTIARY.UI.panel.creature:setVisible(false)
            G_BESTIARY.UI.panel.categories:setVisible(true)
            G_BESTIARY.UI.closeButton.backType = BACK_TYPE.CREATURES
            return true
        elseif G_BESTIARY.UI.closeButton.backType == BACK_TYPE.SEARCH then
            G_BESTIARY.UI.panel.creature:setVisible(false)
            G_BESTIARY.UI.panel.categories:setVisible(true)

            G_BESTIARY.UI.panel.categories.list:destroyChildren()

            local category = g_ui.createWidget("BestiaryCategory", G_BESTIARY.UI.panel.categories.list)
            local creatureClass = getCreatureClass(G_BESTIARY.UI.panel.creature:getText())
            if creatureClass then
                category:setId(creatureClass:lower())
                G_BESTIARY.selectCategory(category)
            end
            G_BESTIARY.UI.closeButton:setText("Voltar")
            return true
        end

        closeBestiaryWindow()
        G_BESTIARY.UI.closeButton.backType = BACK_TYPE.NONE
        return false
    end

    G_BESTIARY.search = function(widget)
        local text = widget:getParent():getChildById("search"):getText()
        
        G_BESTIARY.UI.panel.categories.list:destroyChildren()

        if G_BESTIARY.UI.panel.creature:isVisible() then
            G_BESTIARY.UI.panel.creature:setVisible(false)
            G_BESTIARY.UI.panel.categories:setVisible(true)
        end

        if not text or text == "" then
            G_BESTIARY.loadCategories()
            G_BESTIARY.UI.closeButton.backType = BACK_TYPE.CATEGORIES
            return
        end

        local results = searchCreaturesByName(text)

        if #results > 0 then
            for _, creature in ipairs(results) do
                local c_widget = g_ui.createWidget("BestiaryCreature", G_BESTIARY.UI.panel.categories.list)
                local button = c_widget.button
                c_widget:setId(string.lower(creature.name))
                c_widget:setText(formatWidgetName(creature.name))

                if creature.kills > 0 then
                    c_widget.unlocked:setText(string.format("%d / 3", getKillStage(creature.kills, creature.stages)))
                    button.onClick = function(widget) 
                        G_BESTIARY.selectCreature(widget)
                        G_BESTIARY.UI.closeButton.backType = BACK_TYPE.SEARCH
                    end
                    creature.outfit.shader = ""
                else
                    c_widget.unlocked:setText("?")
                    creature.outfit.shader = "outfit_black"
                end

                c_widget.object = creature
                button.creature:setOutfit(creature.outfit)
                button.creature:setAnimate(true)
            end
        end

        G_BESTIARY.UI.closeButton.backType = BACK_TYPE.CREATURES
    end

    G_BESTIARY.loadCategories = function()
        G_BESTIARY.UI.panel.categories.list:destroyChildren()

        for name, values in pairs(G_BESTIARY.categories) do
            local obj = getCategoryByName(name)
            if not obj then
                return error("[Bestiary] - creature %s not found.", name)
            end

            local category = g_ui.createWidget("BestiaryCategory", G_BESTIARY.UI.panel.categories.list)
            category:setId(obj.class)
            category:setText(
                obj.class:gsub(
                    "(%w%S*)",
                    function(w)
                        return w:gsub("^%l", string.upper)
                    end
                )
            )
            category.total:setText(string.format("Total: %d", values.count))
            category.known:setText(string.format("Conhecidas: %d", values.know))
            category.button:setIcon(obj.image)
            category.button.onClick = G_BESTIARY.selectCategory
        end

        G_BESTIARY.UI.closeButton:setText("Fechar")
    end


    G_BESTIARY.reciver = function(protocol, code, buffer)
        local playerName = g_game.getLocalPlayer():getName()
        local data = buffer.data
        G_BESTIARY.responsesReceived = (G_BESTIARY.responsesReceived or 0) + 1
        
        if buffer.action == "bestiaryData" then
            G_BESTIARY.dataReceived = true
            G_BESTIARY.loadData(data.creature)
            if data.finished then
                G_BESTIARY.loadCategories()
                G_BESTIARY.Tracker.load()
            end
        elseif buffer.action == "prepareBestiaryData" then
            G_BESTIARY.data = nil
            G_BESTIARY.data = {}
        elseif buffer.action == "bestiaryKill" then
            for name, kills in pairs(data) do
                updateBestiaryKill(name, kills)
                
                if G_BESTIARY.trackerData[name] and G_BESTIARY.Tracker.UI:isVisible() then
                    G_BESTIARY.Tracker.load()
                end
            end
        elseif buffer.action == "bestiaryBalance" then
            G_BESTIARY.UI.bestiaryPoints:setText(data.value)
            if data.label then
                G_BESTIARY.UI.bestiaryPoints:setTooltip(data.label)
            end
		elseif buffer.action == "charms" then
            onReceiveCharms(buffer.data)
		elseif buffer.action == "msg" then
            onReceiveMsg(buffer.data)
		elseif buffer.action == "coins" then
            onReceiveCoins(buffer.data)
        end

		addCreaturesCharmsList()
    end

    G_BESTIARY.loadData = function(creature)
        if not creature then
            return
        end

         if not getCategoryByName(creature.class) then
            return error(string.format("[Bestiary] class %s not found.", creature.class))
         end

         local classLower = creature.class:lower()
         if not G_BESTIARY.categories[classLower] then
            G_BESTIARY.categories[classLower] = {
                count = 0,
                know = 0
            }
         end
         G_BESTIARY.categories[classLower].count = G_BESTIARY.categories[classLower].count + 1
         if creature.kills > 0 then
            G_BESTIARY.categories[classLower].know = G_BESTIARY.categories[classLower].know + 1
        end

        if not G_BESTIARY.data[classLower] then
            G_BESTIARY.data[classLower] = {}
        end

        table.insert(G_BESTIARY.data[classLower], creature)
    end

    G_BESTIARY.send = function(action, data)
        G_BESTIARY.requestsSent = (G_BESTIARY.requestsSent or 0) + 1
        
        if not g_game.getFeature(GameExtendedOpcode) then
            return
        end
        local protocolGame = g_game.getProtocolGame()
        if data == nil then
            data = {}
        end

        if protocolGame then
            local payload = {action = action, data = data}
            protocolGame:sendExtendedJSONOpcode(CONFIG.CLIENT_OPCODE, payload)
        end
    end

    G_BESTIARY.save = function()
        if not g_resources.directoryExists("/bestiary/") then
            g_resources.makeDir("/bestiary/")
        end

        if not table.empty(G_BESTIARY.trackerData) then

            local name = formatFileName(G_BESTIARY.playerName)
            local file = string.format("/bestiary/bestiary_%s.json", name)

            local result = json.encode(G_BESTIARY.trackerData, 2)
            if result:len() > 100 * 1024 * 1024 then
                return onError(
                           "Algo deu errado, arquivo acima de 100MB, nao sera salvo")
            end
            g_resources.writeFileContents(file, result)
        end
    end

    G_BESTIARY.load = function()
        if not g_resources.directoryExists("/bestiary/") then
            g_resources.makeDir("/bestiary/")
        end

        local name = formatFileName(G_BESTIARY.playerName)
        local file = string.format("/bestiary/bestiary_%s.json", name)

        if g_resources.fileExists(file) then
          local result = json.decode(g_resources.readFileContents(file))
          G_BESTIARY.trackerData = result
        end

        if not table.empty(G_BESTIARY.trackerData) then
            G_BESTIARY.Tracker.load()
        end
    end

    G_BESTIARY.needUpdateData = function()
        return true
    end

    G_BESTIARY.Tracker.load = function()
        G_BESTIARY.Tracker.UI.contentsPanel:destroyChildren()

        for name, actived in pairs(G_BESTIARY.trackerData) do
            if actived then
                local trackCreature = getCreatureByName(name)
                if trackCreature then
                    local stage = getKillStage(trackCreature.kills, trackCreature.stages)

                    local obj = g_ui.createWidget("TrackerCreature", G_BESTIARY.Tracker.UI.contentsPanel)
                    obj.name:setText(
                        formatWidgetName(trackCreature.name:gsub(
                            "(%w%S*)",
                            function(w)
                                return w:gsub("^%l", string.upper)
                            end
                        ))
                    )
                    local outfitWithShader = trackCreature.outfit
                    if trackCreature.kills > 0 then
                        outfitWithShader.shader = ""
                    else
                        outfitWithShader.shader = "outfit_black"
                    end
                    
                    obj.creature:setOutfit(outfitWithShader)
                    obj.creature:setAnimate(true)

                    obj.progressFillMiddle.value:setText(trackCreature.kills)

                    obj.progressFillLeft.fill:setImageSource("")
                    obj.progressFillMiddle.fill:setImageSource("")
                    obj.progressFillRight.fill:setImageSource("")

                    obj.progressFillLeft.fill:setTooltip("")
                    obj.progressFillMiddle.fill:setTooltip("")
                    obj.progressFillRight.fill:setTooltip("")
                    

                    if trackCreature.kills > 0 then
                        local fill = obj.progressFillLeft.fill

                        fill:setImageSource("images/fill")
                        local Yhppc = math.floor(fill:getWidth() * (1 - math.min(1, trackCreature.kills / trackCreature.stages[1])))
                        local rect = {x = 0, y = 0, width = math.max(2, fill:getWidth() - Yhppc - 1), height = fill:getHeight() - 1}
                        fill:setImageClip(rect)
                        fill:setImageRect(rect)
                    end

                    if stage >= 1 then
                        local fill = obj.progressFillMiddle.fill

                        fill:setImageSource("images/fill")
                        local Yhppc = math.floor(fill:getWidth() * (1 - math.min(1, (trackCreature.kills - trackCreature.stages[1]) / (trackCreature.stages[2] - trackCreature.stages[1]))))
                        local rect = {x = 0, y = 0, width = (trackCreature.kills > 0 and math.max(2, fill:getWidth() - Yhppc - 1) or 0), height = fill:getHeight() - 1}
                        fill:setImageClip(rect)
                        fill:setImageRect(rect)
                    end

                    if stage >= 2 then
                        local fill = obj.progressFillRight.fill

                        fill:setImageSource("images/fill")
                        local Yhppc = math.floor(fill:getWidth() * (1 - math.min(1, (trackCreature.kills - trackCreature.stages[2]) / (trackCreature.stages[3] - trackCreature.stages[2]))))
                        local rect = {x = 0, y = 0, width = (trackCreature.kills > 0 and math.max(2, fill:getWidth() - Yhppc - 1) or 0), height = fill:getHeight() - 1}
                        fill:setImageClip(rect)
                        fill:setImageRect(rect)
                    end

                    for i = 1, 3 do
                        local tooltip = string.format("%d/%d", trackCreature.kills, trackCreature.stages[i])
                        if trackCreature.kills >= trackCreature.stages[3] then
                            tooltip = tooltip .. " (totalmente desbloqueado)"
                        end

                        if i == 1 then
                            if trackCreature.kills >= trackCreature.stages[3] then
                                obj.progressFillLeft.fill:setImageSource("images/fill_completed")
                            end
                            obj.progressFillLeft:setTooltip(tooltip)
                        elseif i == 2 then
                            if trackCreature.kills >= trackCreature.stages[3] then
                                obj.progressFillMiddle.fill:setImageSource("images/fill_completed")
                            end
                            obj.progressFillMiddle:setTooltip(tooltip)
                        elseif i == 3 then
                            if trackCreature.kills >= trackCreature.stages[3] then
                                obj.progressFillRight.fill:setImageSource("images/fill_completed")
                            end
                            obj.progressFillRight:setTooltip(tooltip)
                        end
                    end
                end
            end
        end
    end
end

function toggleTracker()
    if G_BESTIARY.Tracker.UI:isVisible() then
        G_BESTIARY.Tracker.UI:close()
    else
        G_BESTIARY.Tracker.UI:open()
    end
end

_G.toggleTracker = toggleTracker

G_BESTIARY.charmsData = {
	major = {},
	minor = {}
}

function showCharmsByCategory(category)
	if not G_BESTIARY.UI then return end
	
	for _, charm in pairs(G_BESTIARY.UI:recursiveGetChildById('charmsList'):getChildren()) do
		charm:destroy()
	end
	
	local charmsData = {}
	if category == "major" then
		charmsData = G_BESTIARY.charmsData.major or {}
	elseif category == "minor" then
		charmsData = G_BESTIARY.charmsData.minor or {}
	end
	
	local allCharms = {}
	for charmName, charm in pairs(charmsData) do
		table.insert(allCharms, charm)
	end
	
	local function compareWidgets(widgetA, widgetB)
		return widgetA.order < widgetB.order
	end
	
	table.sort(allCharms, compareWidgets)
	
	for i = 1, #allCharms do
		addCharm(allCharms[i], allCharms[i].name, category)
	end
	
	local majorBtn = G_BESTIARY.UI:recursiveGetChildById('majorCharmsBtn')
	local minorBtn = G_BESTIARY.UI:recursiveGetChildById('minorCharmsBtn')
	
	if majorBtn and minorBtn then
		if category == "major" then
			majorBtn:setOn(true)
			minorBtn:setOn(false)
		else
			majorBtn:setOn(false)
			minorBtn:setOn(true)
		end
	end
end

function onMajorCharmsButtonClick(widget)
	G_BESTIARY.currentCharmCategory = "major"
	showCharmsByCategory("major")
end

function onMinorCharmsButtonClick(widget)
	G_BESTIARY.currentCharmCategory = "minor"
	showCharmsByCategory("minor")
end

	function onReceiveCharms(info)
	if not info then
		return
	end
	
	local savedCategory = G_BESTIARY.currentCharmCategory or "major"
	local savedCharmId = G_BESTIARY.selectedCharmId
	
	G_BESTIARY.UI:recursiveGetChildById('UnlockButton'):setEnabled(false)
	G_BESTIARY.UI:recursiveGetChildById('ItemBase'):getChildById('image'):setImageSource()

	for _, charm in pairs(G_BESTIARY.UI:recursiveGetChildById('charmsList'):getChildren()) do
		charm:destroy()
	end

	if not G_BESTIARY.charmsData then
		G_BESTIARY.charmsData = { major = {}, minor = {} }
	else
		G_BESTIARY.charmsData.major = {}
		G_BESTIARY.charmsData.minor = {}
	end
	
	if info.major then
		for charmName, charm in pairs(info.major) do
			G_BESTIARY.charmsData.major[charmName] = charm
		end
	end
	
	if info.minor then
		for charmName, charm in pairs(info.minor) do
			G_BESTIARY.charmsData.minor[charmName] = charm
		end
	end
	
	local minorIsEmpty = not info.minor or next(info.minor) == nil
	if info.all and minorIsEmpty then
		local minorCharmNames = {
			["Bless"] = true,
			["Scavenge"] = true,
			["Gut"] = true,
			["Low Blow"] = true
		}
		
		for charmName, charm in pairs(info.all) do
			local isMinor = charm.category == 1 or charm.category == "minor" or 
			                charm.categoryName == "minor" or
			                minorCharmNames[charmName] == true
			
			local isMajor = charm.category == 0 or charm.category == "major" or 
			                (charm.categoryName == "major" and not isMinor)
			
			if isMinor then
				if G_BESTIARY.charmsData.major[charmName] then
					G_BESTIARY.charmsData.major[charmName] = nil
				end
				G_BESTIARY.charmsData.minor[charmName] = charm
			elseif isMajor then
				if not G_BESTIARY.charmsData.major[charmName] then
					G_BESTIARY.charmsData.major[charmName] = charm
				end
			else
				if not G_BESTIARY.charmsData.major[charmName] then
					G_BESTIARY.charmsData.major[charmName] = charm
				end
			end
		end
	end
	
	showCharmsByCategory(savedCategory)
	
	if savedCharmId then
		scheduleEvent(function()
			local charmsList = G_BESTIARY.UI:recursiveGetChildById('charmsList')
			if charmsList then
				local charmWidget = charmsList:recursiveGetChildById(savedCharmId)
				if charmWidget then
					onCharmItemClick(charmWidget)
				end
			end
		end, 100)
	end
	
end

function addCharm(charm, charmName, category)
	if not category then
		if charm.categoryName then
			category = charm.categoryName
		elseif charm.category == "major" or charm.category == 0 then
			category = "major"
		elseif charm.category == "minor" or charm.category == 1 then
			category = "minor"
		else
			category = "major"
		end
	end
	
	local createCharm = g_ui.createWidget("CharmItem", G_BESTIARY.UI:recursiveGetChildById('charmsList'))

	createCharm:setId(charmName)
	createCharm.order = charm.order or 0
	createCharm.category = category
	
	if type(charm.category) == "string" then
		createCharm.charmCategory = charm.category
		createCharm.charmCategoryName = charm.category
	elseif charm.categoryName then
		createCharm.charmCategory = charm.categoryName
		createCharm.charmCategoryName = charm.categoryName
	else
		createCharm.charmCategory = category
		createCharm.charmCategoryName = category
	end
	createCharm.charmType = charm.type or "unknown"
	createCharm.charmBase.image:setImageSource("images/charms/"..charmName.."")
	createCharm:setText(charmName)
	createCharm.desc = charm.desc
	createCharm.monster = (charm.monster and charm.monster or "nil")
	createCharm.purchased = charm.purchased or false
	createCharm.rune = charm.rune or false
	createCharm:recursiveGetChildById('outfit'):setOutfit({type = charm.outfit and charm.outfit.lookType or 0,auxType = charm.outfit and charm.outfit.lookTypeEx or 0, head = charm.outfit and charm.outfit.lookHead or 0, body = charm.outfit and charm.outfit.lookBody or 0, legs = charm.outfit and charm.outfit.lookLegs or 0, feet = charm.outfit and charm.outfit.lookFeet or 0, addons = 0, wings = 0, aura = 0, shader = ""})
	createCharm:recursiveGetChildById('outfit'):setAnimate(charm.outfit and true or false)
	createCharm:recursiveGetChildById('outfit'):setEnabled(charm.outfit and true or false)

	local listBg = "images/ui/bestiary-charm-bg"
	if charm.purchased then
		local lv = tonumber(charm.level or charm.grade or charm.upgrade) or 1
		if lv >= 3 then
			listBg = "images/ui/backdrop_charmgrade3"
		elseif lv == 2 then
			listBg = "images/ui/backdrop_charmgrade2"
		else
			listBg = "images/ui/backdrop_charmgrade1"
		end
	end
	createCharm.charmBase:setImageSource(listBg)
	if createCharm.charmBase.setImageBorder then
		createCharm.charmBase:setImageBorder(10)
	end
	
	createCharm.charmCoin = charm.charmCoin or 0
	createCharm.removeCost = charm.removeCost or 0
	createCharm.level = charm.level or 1
	createCharm.price = charm.price or 0
	createCharm.priceLevel2 = charm.priceLevel2 or 0
	createCharm.priceLevel3 = charm.priceLevel3 or 0
	createCharm.nextLevelPrice = charm.nextLevelPrice or 0
	createCharm.canUpgrade = charm.canUpgrade or false
	
	if charm.purchased then
		if charm.rune then
			createCharm.PriceBase.Gold:setVisible(true)
			createCharm.PriceBase.Charm:setVisible(false)
			createCharm.charmBase.lockedMask:setVisible(false)
			local removeCostValue = charm.removeCost or 0
			createCharm.PriceBase.Value.ValueFix:setText(removeCostValue)
			createCharm.PriceBase.Value:setText(formatMoney(removeCostValue))
		else
			createCharm.PriceBase.Gold:setVisible(true)
			createCharm.PriceBase.Charm:setVisible(false)
			createCharm.charmBase.lockedMask:setVisible(false)
			local removeCostValue = charm.removeCost or 0
			createCharm.PriceBase.Value.ValueFix:setText(removeCostValue)
			createCharm.PriceBase.Value:setText(formatMoney(removeCostValue))
		end
	else
		createCharm.PriceBase.Gold:setVisible(false)
		createCharm.PriceBase.Charm:setVisible(true)
		if category == "minor" then
			createCharm.PriceBase.Charm:setImageSource("images/ui/minor-charm-echoes")
		else
			createCharm.PriceBase.Charm:setImageSource("images/ui/icon_charms")
		end
		createCharm.charmBase.lockedMask:setVisible(true)
		local charmCoinValue = charm.charmCoin or 0
		createCharm.PriceBase.Value:setText(charmCoinValue)
		createCharm.PriceBase.Value.ValueFix:setText(charmCoinValue)
	end
end

local randomColor = "#414141"
function addCreaturesCharmsList()
	local allMonsters = {}
	local totalCreatures = 0
	local knownCreatures = 0
	
	local creatureList = G_BESTIARY.UI:recursiveGetChildById('CreatureList')
	if creatureList then
		creatureList:destroyChildren()
	end
	
	local function getTableKeys(t)
		local keys = {}
		for k, v in pairs(t or {}) do
			table.insert(keys, k)
		end
		return keys
	end
	
	if not G_BESTIARY.data or table.empty(G_BESTIARY.data) then
		return
	end
	
	for catId, creatures in pairs(G_BESTIARY.data) do
		for _, obj in pairs(creatures) do
			totalCreatures = totalCreatures + 1
			if obj.kills > 0 then
				knownCreatures = knownCreatures + 1
				
				if obj.kills >= obj.stages[3] then
					local creature = {}
					creature.id = string.lower(obj.name)
					creature.name = formatWidgetName(obj.name)
					creature.outfit = obj.outfit
					table.insert(allMonsters, creature)
				end
			end
		end
	end

	local function compareWidgets(widgetA, widgetB)
		return widgetA.id:lower() < widgetB.id:lower()
	end

	table.sort(allMonsters, compareWidgets)

	local addedToCharmList = 0
	for i = 1, #allMonsters do
		if not G_BESTIARY.UI:recursiveGetChildById('CreatureList'):getChildById(allMonsters[i].id) then
			local newCreature = g_ui.createWidget("CharmCreatureName", G_BESTIARY.UI:recursiveGetChildById('CreatureList'))
			newCreature:setId(allMonsters[i].id)
			newCreature:setText(allMonsters[i].name)
			newCreature:setBackgroundColor(randomColor == "#414141" and "#484848" or "#414141")
			randomColor = randomColor == "#414141" and "#484848" or "#414141"
			newCreature.outfit = allMonsters[i].outfit
			newCreature.monster = allMonsters[i].name
			addedToCharmList = addedToCharmList + 1
		end
	end
	
	local creatureList = G_BESTIARY.UI:recursiveGetChildById('CreatureList')
	if creatureList then
		if #creatureList:getChildren() > 0 then
			creatureList:show()
		end
	end
end

function forceUpdateCharmCreatureList()
	addCreaturesCharmsList()
end

function showCharmCreatureList()
	local creatureList = G_BESTIARY.UI:recursiveGetChildById('CreatureList')
	if creatureList then
		creatureList:show()
		return true
	else
		return false
	end
end

function onReceiveMsg(info)
	G_BESTIARY.UI:recursiveGetChildById('message'):setVisible(true)
	G_BESTIARY.UI:recursiveGetChildById('msgLabel'):setText(info.msg)
end

function onReceiveCoins(info)
	G_BESTIARY.UI:recursiveGetChildById('goldCoinsValue'):setText(info.gold)
	G_BESTIARY.UI:recursiveGetChildById('goldCoins'):setText(formatMoney(info.gold))
	G_BESTIARY.UI:recursiveGetChildById('charmsPoints'):setText(info.charm)
	G_BESTIARY.UI:recursiveGetChildById('extraCharmsPoints'):setText(info.extracharm)
	
	if info.charmLabel then
		G_BESTIARY.UI:recursiveGetChildById('charmsPoints'):setTooltip(info.charmLabel)
	end
	if info.extracharmLabel then
		G_BESTIARY.UI:recursiveGetChildById('extraCharmsPoints'):setTooltip(info.extracharmLabel)
	end
	
	scheduleEvent(function()
		local main = G_BESTIARY.UI
		local imageID = main:recursiveGetChildById('imageID')
		if imageID and imageID:getText() and imageID:getText() ~= "" then
			local sendCharm = imageID:getText()
			local selectedCharm = nil
			for _, charm in pairs(main:recursiveGetChildById('charmsList'):getChildren()) do
				if charm:getId() == sendCharm then
					selectedCharm = charm
					break
				end
			end
			
			if selectedCharm and selectedCharm.purchased then
				local canUpgrade = selectedCharm.canUpgrade or false
				local nextLevelPrice = selectedCharm.nextLevelPrice or 0
				local charmsPoints = tonumber(main:recursiveGetChildById('charmsPoints'):getText()) or 0
				local extraCharmsPoints = tonumber(main:recursiveGetChildById('extraCharmsPoints'):getText()) or 0
				
				if canUpgrade and nextLevelPrice > 0 then
					local hasEnoughPoints = false
					if selectedCharm.category == "minor" then
						hasEnoughPoints = extraCharmsPoints >= nextLevelPrice
					else
						hasEnoughPoints = charmsPoints >= nextLevelPrice
					end
					main:recursiveGetChildById('UpgradeButton'):setVisible(true)
					main:recursiveGetChildById('UpgradeButton'):setEnabled(hasEnoughPoints)
					main:recursiveGetChildById('UpgradeButton'):setText('Upgrade')
					
					main:recursiveGetChildById('UnlockCost'):getChildById('UnlockValue'):setText(nextLevelPrice)
					main:recursiveGetChildById('UnlockCost'):getChildById('UnlockGoldIcon'):setVisible(false)
					main:recursiveGetChildById('UnlockCost'):getChildById('UnlockCharmIcon'):setVisible(true)
					if selectedCharm.category == "minor" then
						main:recursiveGetChildById('UnlockCost'):getChildById('UnlockCharmIcon'):setImageSource("images/ui/minor-charm-echoes")
					else
						main:recursiveGetChildById('UnlockCost'):getChildById('UnlockCharmIcon'):setImageSource("images/ui/icon_charms")
					end
					main:recursiveGetChildById('UnlockCost'):setVisible(true)
					
					local removeCostValue = tonumber(selectedCharm:recursiveGetChildById('ValueFix'):getText()) or 0
					main:recursiveGetChildById('PriceBaseMain'):getChildById('Value'):setText(formatMoney(removeCostValue))
					main:recursiveGetChildById('PriceBaseMain'):getChildById('Gold'):setVisible(true)
					main:recursiveGetChildById('PriceBaseMain'):getChildById('Charm'):setVisible(false)
					main:recursiveGetChildById('PriceBaseMain'):setVisible(true)
				else
					main:recursiveGetChildById('UpgradeButton'):setVisible(true)
					main:recursiveGetChildById('UpgradeButton'):setEnabled(false)
					main:recursiveGetChildById('UpgradeButton'):setText('Upgrade')
					main:recursiveGetChildById('UnlockCost'):setVisible(false)
					
					local removeCostValue = tonumber(selectedCharm:recursiveGetChildById('ValueFix'):getText()) or 0
					main:recursiveGetChildById('PriceBaseMain'):getChildById('Value'):setText(formatMoney(removeCostValue))
					main:recursiveGetChildById('PriceBaseMain'):getChildById('Gold'):setVisible(true)
					main:recursiveGetChildById('PriceBaseMain'):getChildById('Charm'):setVisible(false)
					main:recursiveGetChildById('PriceBaseMain'):setVisible(true)
				end
			end
		end
	end, 100)
end

function formatMoney(money)
    if money >= 10^6 then
        return string.format("%.2fkk", money / 10^6)
    elseif money >= 10^3 then
        return string.format("%.2fk", money / 10^3)
    else
        return tostring(money)
    end
end

function searchMonsterCharm(search)
    for _, monster in pairs(G_BESTIARY.UI:recursiveGetChildById('CreatureList'):getChildren()) do
		if string.find(monster:getId():lower(), search:lower()) or not search or search == "" then
			monster:show()
		else
			monster:hide()
		end
	end
end

function onCharmItemClick(widget)
    local main = widget:getParent():getParent():getParent():getParent()
    local selectPoints = tonumber(widget:recursiveGetChildById('ValueFix'):getText()) and tonumber(widget:recursiveGetChildById('ValueFix'):getText()) or 0
    local goldCoins = tonumber(main:recursiveGetChildById('goldCoinsValue'):getText()) and tonumber(main:recursiveGetChildById('goldCoinsValue'):getText())*g_game:getLocalPlayer():getLevel() or 0
    local charmsPoints = tonumber(main:recursiveGetChildById('charmsPoints'):getText()) and tonumber(main:recursiveGetChildById('charmsPoints'):getText()) or 0
    local extraCharmsPoints = tonumber(main:recursiveGetChildById('extraCharmsPoints'):getText()) and tonumber(main:recursiveGetChildById('extraCharmsPoints'):getText()) or 0
    local canOutfit = widget:recursiveGetChildById('outfit'):getOutfit().type ~= 0 and true or false
    
    G_BESTIARY.selectedCharmId = widget:getId()
    if widget.category then
        G_BESTIARY.currentCharmCategory = widget.category
    end

    animateElement(widget, 'scaleIn', G_BESTIARY.ANIMATIONS.duration.fast)

    widget:getParent():focusChild(widget, ActiveFocusReason)
    main:recursiveGetChildById('showCreatureID'):setText(widget.monster)
    main:recursiveGetChildById('showCreature'):setOutfit(widget:recursiveGetChildById('outfit'):getOutfit())
    main:recursiveGetChildById('showCreature'):setAnimate(canOutfit)
    main:recursiveGetChildById('showCreature'):setEnabled(canOutfit)
    main:recursiveGetChildById('ItemBase'):getChildById('image'):getChildById('imageID'):setText(widget:getId())
    main:recursiveGetChildById('ItemBase'):getChildById('image'):setImageSource("images/charms/"..widget:getId().."")
    setItemBaseBackdrop(main, widget.purchased, widget.level or widget.grade or widget.upgrade)
    main:recursiveGetChildById('TextBase'):setText(widget.desc)

    updateCharmUI(main, widget, canOutfit, selectPoints)
    
    if widget.purchased and widget.rune then
      if widget.monster and widget.monster ~= "nil" and widget.monster ~= "" then
        scheduleEvent(function()
          local creatureList = main:recursiveGetChildById('CreatureList')
          if creatureList then
            for _, creature in pairs(creatureList:getChildren()) do
              creature:setChecked(false)
            end
            
            for _, creature in pairs(creatureList:getChildren()) do
              if creature.monster == widget.monster then
                creature:setChecked(true)
                animateElement(creature, 'fadeIn', G_BESTIARY.ANIMATIONS.duration.fast)
                break
              end
            end
          end
        end, 100)
      end
    end

    modules.game_bestiary.G_BESTIARY.send("coins")
    
    modules.game_bestiary.addCreaturesCharmsList()
end

function onCharmCreatureClick(widget)
    local main = widget:getParent():getParent():getParent():getParent():getParent()
    
    for _, creature in pairs(main:recursiveGetChildById('CreatureList'):getChildren()) do
      creature:setChecked(false)
    end
    
    widget:setChecked(true)
    
    animateElement(widget, 'fadeIn', G_BESTIARY.ANIMATIONS.duration.fast)
    
    main:recursiveGetChildById('showCreature'):setOutfit(widget.outfit)
    main:recursiveGetChildById('showCreature'):setAnimate(widget.outfit)
    main:recursiveGetChildById('showCreatureID'):setText(widget.monster)
    local selectPoints = tonumber(main:recursiveGetChildById('PriceBaseMain'):getChildById('Value'):getText()) and tonumber(main:recursiveGetChildById('PriceBaseMain'):getChildById('Value'):getText()) or 0
    local goldCoins = tonumber(main:recursiveGetChildById('goldCoinsValue'):getText()) and tonumber(main:recursiveGetChildById('goldCoinsValue'):getText()) or 0
    if goldCoins >= selectPoints then
      main:recursiveGetChildById('UnlockButton'):setEnabled(true)
    else
      main:recursiveGetChildById('UnlockButton'):setEnabled(false)
    end
end

function onBestiaryButtonClick(widget)
    widget:getParent():getChildById('panel'):show()
    widget:getParent():getChildById('searchLabel'):show()
    widget:getParent():getChildById('search'):show()
    widget:getParent():getChildById('searchBtn'):show()
    widget:getParent():getChildById('charmsPanel'):hide()
end

function onCharmsButtonClick(widget)
    widget:getParent():getChildById('panel'):hide()
    widget:getParent():getChildById('searchLabel'):hide()
    widget:getParent():getChildById('search'):hide()
    widget:getParent():getChildById('searchBtn'):hide()
    widget:getParent():getChildById('charmsPanel'):show()
    
    scheduleEvent(function()
      local charmsList = widget:getParent():recursiveGetChildById('charmsList')
      if charmsList and charmsList:getFirstChild() then
        local firstCharm = charmsList:getFirstChild()
        local main = widget:getParent()
        local selectPoints = tonumber(firstCharm:recursiveGetChildById('ValueFix'):getText()) and tonumber(firstCharm:recursiveGetChildById('ValueFix'):getText()) or 0
        local goldCoins = tonumber(main:recursiveGetChildById('goldCoinsValue'):getText()) and tonumber(main:recursiveGetChildById('goldCoinsValue'):getText())*g_game:getLocalPlayer():getLevel() or 0
        local charmsPoints = tonumber(main:recursiveGetChildById('charmsPoints'):getText()) and tonumber(main:recursiveGetChildById('charmsPoints'):getText()) or 0
        local extraCharmsPoints = tonumber(main:recursiveGetChildById('extraCharmsPoints'):getText()) and tonumber(main:recursiveGetChildById('extraCharmsPoints'):getText()) or 0
        local canOutfit = firstCharm:recursiveGetChildById('outfit'):getOutfit().type ~= 0 and true or false

        firstCharm:getParent():focusChild(firstCharm, ActiveFocusReason)
        main:recursiveGetChildById('showCreatureID'):setText(firstCharm.monster)
        main:recursiveGetChildById('showCreature'):setOutfit(firstCharm:recursiveGetChildById('outfit'):getOutfit())
        main:recursiveGetChildById('showCreature'):setAnimate(canOutfit)
        main:recursiveGetChildById('showCreature'):setEnabled(canOutfit)
        main:recursiveGetChildById('ItemBase'):getChildById('image'):getChildById('imageID'):setText(firstCharm:getId())
        main:recursiveGetChildById('ItemBase'):getChildById('image'):setImageSource("images/charms/"..firstCharm:getId().."")
        setItemBaseBackdrop(main, firstCharm.purchased, firstCharm.level or firstCharm.grade or firstCharm.upgrade)
        main:recursiveGetChildById('TextBase'):setText(firstCharm.desc)
        updateCharmUI(main, firstCharm, canOutfit, selectPoints)

        if not firstCharm.purchased then
          main:recursiveGetChildById('UnlockButton'):setText("Desbloquear")
          local charmCoinValue = firstCharm.charmCoin or selectPoints
          if charmsPoints+extraCharmsPoints >= charmCoinValue then
            main:recursiveGetChildById('UnlockButton'):setEnabled(true)
          else
            main:recursiveGetChildById('UnlockButton'):setEnabled(false)
          end
          main:recursiveGetChildById('UnlockButton'):setText("Desbloquear")
          main:recursiveGetChildById('PriceBaseMain'):getChildById('Gold'):setVisible(false)
          main:recursiveGetChildById('PriceBaseMain'):getChildById('Charm'):setVisible(true)
          if firstCharm.category == "minor" then
            main:recursiveGetChildById('PriceBaseMain'):getChildById('Charm'):setImageSource("images/ui/minor-charm-echoes")
          else
            main:recursiveGetChildById('PriceBaseMain'):getChildById('Charm'):setImageSource("images/ui/icon_charms")
          end
          main:recursiveGetChildById('CreatureList'):hide()
        else
          if not firstCharm.rune then
            main:recursiveGetChildById('UnlockButton'):setText("Selecionar")
            if canOutfit then
              main:recursiveGetChildById('UnlockButton'):setEnabled(true)
            else
              main:recursiveGetChildById('UnlockButton'):setEnabled(false)
            end
          else
            main:recursiveGetChildById('UnlockButton'):setText("Remover")
            
            if firstCharm.monster and firstCharm.monster ~= "nil" and firstCharm.monster ~= "" then
              scheduleEvent(function()
                local creatureList = main:recursiveGetChildById('CreatureList')
                if creatureList then
                  for _, creature in pairs(creatureList:getChildren()) do
                    creature:setChecked(false)
                  end
                  
                  for _, creature in pairs(creatureList:getChildren()) do
                    if creature.monster == firstCharm.monster then
                      creature:setChecked(true)
                      break
                    end
                  end
                end
              end, 100)
            end
            
            main:recursiveGetChildById('UnlockButton'):setEnabled(true)
          end
            local removeCostValue = tonumber(firstCharm:recursiveGetChildById('ValueFix'):getText()) or 0
            main:recursiveGetChildById('PriceBaseMain'):getChildById('Value'):setText(formatMoney(removeCostValue))
            main:recursiveGetChildById('PriceBaseMain'):getChildById('Gold'):setVisible(true)
            main:recursiveGetChildById('PriceBaseMain'):getChildById('Charm'):setVisible(false)
          main:recursiveGetChildById('CreatureList'):show()
        end

        G_BESTIARY.send("coins")
        
        if firstCharm.purchased then
          local canUpgrade = firstCharm.canUpgrade or false
          local nextLevelPrice = firstCharm.nextLevelPrice or 0
          local charmsPoints = tonumber(main:recursiveGetChildById('charmsPoints'):getText()) or 0
          local extraCharmsPoints = tonumber(main:recursiveGetChildById('extraCharmsPoints'):getText()) or 0
          
          if canUpgrade and nextLevelPrice > 0 then
            local hasEnoughPoints = false
            if firstCharm.category == "minor" then
              hasEnoughPoints = extraCharmsPoints >= nextLevelPrice
            else
              hasEnoughPoints = charmsPoints >= nextLevelPrice
            end
            main:recursiveGetChildById('UpgradeButton'):setVisible(true)
            main:recursiveGetChildById('UpgradeButton'):setEnabled(hasEnoughPoints)
            main:recursiveGetChildById('UpgradeButton'):setText('Upgrade')
            
            main:recursiveGetChildById('UnlockCost'):getChildById('UnlockValue'):setText(nextLevelPrice)
            main:recursiveGetChildById('UnlockCost'):getChildById('UnlockGoldIcon'):setVisible(false)
            main:recursiveGetChildById('UnlockCost'):getChildById('UnlockCharmIcon'):setVisible(true)
            if firstCharm.category == "minor" then
              main:recursiveGetChildById('UnlockCost'):getChildById('UnlockCharmIcon'):setImageSource("images/ui/minor-charm-echoes")
            else
              main:recursiveGetChildById('UnlockCost'):getChildById('UnlockCharmIcon'):setImageSource("images/ui/icon_charms")
            end
            main:recursiveGetChildById('UnlockCost'):setVisible(true)
            
            local removeCostValue = tonumber(firstCharm:recursiveGetChildById('ValueFix'):getText()) or 0
            main:recursiveGetChildById('PriceBaseMain'):getChildById('Value'):setText(formatMoney(removeCostValue))
            main:recursiveGetChildById('PriceBaseMain'):getChildById('Gold'):setVisible(true)
            main:recursiveGetChildById('PriceBaseMain'):getChildById('Charm'):setVisible(false)
            main:recursiveGetChildById('PriceBaseMain'):setVisible(true)
          else
            main:recursiveGetChildById('UpgradeButton'):setVisible(true)
            main:recursiveGetChildById('UpgradeButton'):setEnabled(false)
            main:recursiveGetChildById('UpgradeButton'):setText('Upgrade')
            main:recursiveGetChildById('UnlockCost'):setVisible(false)
            
            local removeCostValue = tonumber(firstCharm:recursiveGetChildById('ValueFix'):getText()) or 0
            main:recursiveGetChildById('PriceBaseMain'):getChildById('Value'):setText(formatMoney(removeCostValue))
            main:recursiveGetChildById('PriceBaseMain'):getChildById('Gold'):setVisible(true)
            main:recursiveGetChildById('PriceBaseMain'):getChildById('Charm'):setVisible(false)
            main:recursiveGetChildById('PriceBaseMain'):setVisible(true)
          end
        else
          main:recursiveGetChildById('UpgradeButton'):setVisible(false)
        end
        
        addCreaturesCharmsList()
      end
    end, 10)
end

function onUpgradeButtonClick(widget)
    local main = widget:getParent():getParent():getParent():getParent()
    local sendCharm = main:recursiveGetChildById('imageID'):getText()
    
    local selectedCharm = nil
    for _, charm in pairs(main:recursiveGetChildById('charmsList'):getChildren()) do
      if charm:getId() == sendCharm then
        selectedCharm = charm
        break
      end
    end
    
    if selectedCharm then
        if not selectedCharm.canUpgrade then
            return
        end
        
        G_BESTIARY.selectedCharmId = sendCharm
        if selectedCharm.category then
            G_BESTIARY.currentCharmCategory = selectedCharm.category
        end
        
        local nextLevelPrice = selectedCharm.nextLevelPrice or 0
        local charmsPoints = tonumber(main:recursiveGetChildById('charmsPoints'):getText()) or 0
        local extraCharmsPoints = tonumber(main:recursiveGetChildById('extraCharmsPoints'):getText()) or 0
        
        local hasEnoughPoints = false
        if selectedCharm.category == "minor" then
            hasEnoughPoints = extraCharmsPoints >= nextLevelPrice
        else
            hasEnoughPoints = charmsPoints >= nextLevelPrice
        end
        
        if not hasEnoughPoints then
            return
        end
        
        animateElement(widget, 'scaleIn', G_BESTIARY.ANIMATIONS.duration.fast)
        G_BESTIARY.send("upgrade", {charm = sendCharm})
    end
end

function onUnlockButtonClick(widget)
    local main = widget:getParent():getParent():getParent():getParent()
    local sendCharm = main:recursiveGetChildById('imageID'):getText()
    local sendCreature = main:recursiveGetChildById('showCreatureID'):getText()
    
    local selectedCharm = nil
    for _, charm in pairs(main:recursiveGetChildById('charmsList'):getChildren()) do
      if charm:getId() == sendCharm then
        selectedCharm = charm
        break
      end
    end
    
    if selectedCharm then
        G_BESTIARY.selectedCharmId = sendCharm
        if selectedCharm.category then
            G_BESTIARY.currentCharmCategory = selectedCharm.category
        end
        
        local action = ''
        if not selectedCharm.purchased then
            action = 'desbloquear'
        elseif not selectedCharm.rune then
            action = 'selecionar'
        else
            action = 'remover'
        end
        
        local validation = validateCharmAction(selectedCharm, action)
        
        if not validation.valid then
            showFeedback(validation.type, validation.message)
            return
        end
        
        setLoadingState(widget, true, 'Processando...')
        
        animateElement(widget, 'scaleIn', G_BESTIARY.ANIMATIONS.duration.fast)
        
        if not selectedCharm.purchased then
            G_BESTIARY.send("desbloquear", {charm = sendCharm, monster = sendCreature or ""})
            showFeedback('info', 'Charm desbloqueado com sucesso!')
        elseif not selectedCharm.rune then
            if sendCreature and sendCreature ~= "nil" and sendCreature ~= "" then
                G_BESTIARY.send("selecionar", {monster = sendCreature, charm = sendCharm})
                showFeedback('success', 'Charm atribuído á criatura!')
            else
                showFeedback('warning', 'Selecione uma criatura primeiro!')
                setLoadingState(widget, false)
                return
            end
        else
            G_BESTIARY.send("remover", {charm = sendCharm})
            showFeedback('info', 'Charm removido da criatura!')
        end
        
        scheduleEvent(function()
            setLoadingState(widget, false)
        end, 1000)
    end
end

function onStoreButtonClick(widget)
    modules.game_store.toggle()
    modules.game_interface.getRootPanel():focus()
    if G_BESTIARY.Tracker.UI.bestiaryWindowButton then
      G_BESTIARY.Tracker.UI.bestiaryWindowButton:setOn(false)
    end
    resetAllWidgetOpacity(G_BESTIARY.UI)
end

function onCloseButtonClick(widget)
    G_BESTIARY.closeBackButton(widget)
    widget:getParent():recursiveGetChildById('CreatureList'):hide()
end

function applyVisualImprovements()
    if not G_BESTIARY.UI then return end
    
    applyCentralizedColors()
    
    applyStandardizedSpacing()
    
    addInformativeTooltips()
    
    setupEnhancedVisualStates()
end

function applyCentralizedColors()
    local elements = {
        {id = 'charmsList', type = 'background'},
        {id = 'CreatureList', type = 'background'},
        {id = 'panel', type = 'background'}
    }
    
    for _, element in pairs(elements) do
        local widget = G_BESTIARY.UI:recursiveGetChildById(element.id)
        if widget then
            if element.type == 'background' then
                widget:setBackgroundColor(G_BESTIARY.COLORS.background.panel)
            end
        end
    end
end

function applyStandardizedSpacing()
    local layouts = {
        {id = 'charmsList', spacing = G_BESTIARY.SPACING.sm},
        {id = 'CreatureList', spacing = G_BESTIARY.SPACING.xs}
    }
    
    for _, layout in pairs(layouts) do
        local widget = G_BESTIARY.UI:recursiveGetChildById(layout.id)
        if widget and widget.layout then
            widget.layout.cellSpacing = layout.spacing
        end
    end
end

function addInformativeTooltips()
    local tooltips = {
        {id = 'UnlockButton', text = 'Clique para desbloquear/selecionar/remover charm'},
        {id = 'goldCoins', text = 'Moedas de ouro disponíveis'},
        {id = 'charmsPoints', text = 'Pontos de charm disponíveis'},
        {id = 'bestiaryPoints', text = 'Pontos de bestiário disponíveis'},
        {id = 'search', text = 'Digite para buscar criaturas'},
        {id = 'bestiaryBtn', text = 'Visualizar bestiário'},
        {id = 'charmsBtn', text = 'Gerenciar charms'}
    }
    
    for _, tooltip in pairs(tooltips) do
        local widget = G_BESTIARY.UI:recursiveGetChildById(tooltip.id)
        if widget then
            widget:setTooltip(tooltip.text)
        end
    end
end

function setupEnhancedVisualStates()
    local interactiveElements = {
        'bestiaryBtn', 'charmsBtn', 'UnlockButton', 'searchBtn'
    }
    
    for _, elementId in pairs(interactiveElements) do
        local widget = G_BESTIARY.UI:recursiveGetChildById(elementId)
        if widget then
            widget.onHoverChange = function(self, hovered)
                if hovered then
                    self:setOpacity(0.8)
                else
                    self:setOpacity(1.0)
                end
            end
        end
    end
end

function showFeedback(type, message, duration)
    duration = duration or 3000
    
    if not G_BESTIARY.UI then
        return
    end
    
    local existingFeedback = G_BESTIARY.UI:recursiveGetChildById('feedbackMessage')
    if existingFeedback then
        existingFeedback:destroy()
    end
    
    local feedbackWidget = g_ui.createWidget('UIWidget', G_BESTIARY.UI)
    feedbackWidget:setId('feedbackMessage')
    feedbackWidget:setSize({width = 300, height = 40})
    
    local parentSize = G_BESTIARY.UI:getSize()
    local widgetSize = feedbackWidget:getSize()
    local x = (parentSize.width - widgetSize.width) / 2
    local y = (parentSize.height - widgetSize.height) / 2
    feedbackWidget:setPosition({x = x, y = y})
    
    local borderColor = G_BESTIARY.COLORS.state[type] or "#FFFFFF"
    feedbackWidget:setBackgroundColor(G_BESTIARY.COLORS.background.overlay or "#000000CC")
    
    local label = g_ui.createWidget('Label', feedbackWidget)
    label:setText(message)
    label:setColor(borderColor)
    label:setTextAlign(AlignCenter)
    label:setSize({width = 300, height = 40})
    label:setPosition({x = 0, y = 0})
    
    feedbackWidget:setOpacity(0)
    scheduleEvent(function()
        feedbackWidget:setOpacity(1)
    end, 100)
    
    scheduleEvent(function()
        feedbackWidget:setOpacity(0)
        scheduleEvent(function()
            feedbackWidget:destroy()
        end, 300)
    end, duration)
end

function setLoadingState(widget, loading, message)
    if loading then
        widget:setEnabled(false)
        widget:setOpacity(0.6)
        if message then
            widget:setTooltip(message)
        end
    else
        widget:setEnabled(true)
        widget:setOpacity(1.0)
        widget:setTooltip('')
    end
end

function setupCreatureFilters()
    if not G_BESTIARY.UI then return end
    
    local creatureList = G_BESTIARY.UI:recursiveGetChildById('CreatureList')
    if not creatureList then return end
    
    creatureList.filters = {
        type = 'all',
        level = 'all',
        completed = true
    }
    
    creatureList.applyFilters = function(self)
        local children = self:getChildren()
        for _, creature in pairs(children) do
            local shouldShow = true
            
            if self.filters.type ~= 'all' then
            end
            
            if self.filters.level ~= 'all' then
            end
            
            if self.filters.completed then
            end
            
            if shouldShow then
                creature:show()
            else
                creature:hide()
            end
        end
    end
end

function animateElement(widget, animationType, duration)
    duration = duration or G_BESTIARY.ANIMATIONS.duration.normal
    
    if animationType == 'fadeIn' then
        widget:setOpacity(0)
        scheduleEvent(function()
            widget:setOpacity(1)
        end, 50)
    elseif animationType == 'fadeOut' then
        widget:setOpacity(1)
        scheduleEvent(function()
            widget:setOpacity(0)
        end, duration)
    elseif animationType == 'scaleIn' then
        widget:setOpacity(0.5)
        scheduleEvent(function()
            widget:setOpacity(1)
        end, 50)
    elseif animationType == 'slideIn' then
        local originalY = widget:getY()
        widget:setY(originalY + 20)
        widget:setOpacity(0)
        scheduleEvent(function()
            widget:setY(originalY)
            widget:setOpacity(1)
        end, 50)
    end
end

function setupResponsiveLayout()
    if not G_BESTIARY.UI then return end
    
    local mainWindow = G_BESTIARY.UI
    local screenWidth = g_window.getWidth()
    local screenHeight = g_window.getHeight()
    
    if screenWidth < 1024 then
        mainWindow:setSize({width = 600, height = 450})
    elseif screenWidth > 1920 then
        mainWindow:setSize({width = 800, height = 600})
    else
        mainWindow:setSize({width = 725, height = 550})
    end
    
end

function validateCharmAction(charm, action)
    local validation = {
        valid = true,
        message = '',
        type = 'info'
    }
    
    if action == 'desbloquear' then
        if not charm.charmCoin or charm.charmCoin <= 0 then
            validation.valid = false
            validation.message = 'Charm não pode ser desbloqueado'
            validation.type = 'error'
        end
    elseif action == 'selecionar' then
        if not charm.purchased then
            validation.valid = false
            validation.message = 'Charm deve ser comprado primeiro'
            validation.type = 'error'
        end
    elseif action == 'remover' then
        if not charm.rune then
            validation.valid = false
            validation.message = 'Charm não está atribuído'
            validation.type = 'error'
        end
    end
    
    return validation
end