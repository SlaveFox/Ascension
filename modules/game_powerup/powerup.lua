local powerUpWindow
local POWERUPButton = nil
local unlockedWindow = nil
local unlockedIsClicked = false

local statsList = {
    {name = "Health", image = "health"},
    {name = "Mana", image = "mana"},
    {name = "Strength", image = "strength"},
    {name = "Resilience", image = "resilience"},
    {name = "ChakraRegeneration", image = "chakra_regen"},
    {name = "LifeLeech", image = "life_leech"},
    {name = "Healing", image = "healing"},
    {name = "LifeRegeneration", image = "life_regen"},
    {name = "ManaLeech", image = "mana_leech"},
    {name = "Reflect", image = "reflect"},
    {name = "CriticalDamage", image = "crit_damage"},
    {name = "Critical", image = "critical"},
}

local idMap = {}
for _, v in ipairs(statsList) do
    idMap[v.name] = v.name:lower()
end

--------------------------------------------------
-- ?? Funções principais
--------------------------------------------------

function init()
    connect(g_game, { onGameStart = naoexibir, onGameEnd = naoexibir })

    powerUpWindow = g_ui.displayUI("powerup", modules.game_interface.getRootPanel())
    POWERUPButton = modules.client_topmenu.addRightGameToggleButton(
        'powerUP', "Power Up", '/images/topbuttons/powerup', exibir, true
    )
    POWERUPButton:setOn(false)

    ProtocolGame.registerExtendedOpcode(103, onReceiveChangePowerUp)

    powerUpWindow:hide()
end

function terminate()
    disconnect(g_game, { onGameStart = naoexibir, onGameEnd = naoexibir })
    ProtocolGame.unregisterExtendedOpcode(103)
    powerUpWindow:hide()
end

function exibir()
    if POWERUPButton:isOn() then
        naoexibir()
    else
        requestPowerUpData()
        powerUpWindow:show()
        powerUpWindow:raise()
        powerUpWindow:focus()
        POWERUPButton:setOn(true)
        createStatWidgets()
    end
end

function naoexibir()
    powerUpWindow:hide()
    POWERUPButton:setOn(false)
    closeUnlocked()
end

--------------------------------------------------
-- ?? Request PowerUp
--------------------------------------------------
function requestPowerUpData()
    g_game.getProtocolGame():sendExtendedOpcode(103, json.encode({}))
end

--------------------------------------------------
-- ?? Cálculo de posição circular com margin
--------------------------------------------------
local function calculateCircleMargin(radius, index, total)
    local angle = (index - 1) * (2 * math.pi / total) - math.pi / 2
    local x = radius * math.cos(angle)
    local y = radius * math.sin(angle)
    return math.floor(x), math.floor(y)
end

--------------------------------------------------
-- ?? Cria os botões e fills dinamicamente
--------------------------------------------------
function createStatWidgets()
    local ring   = powerUpWindow:recursiveGetChildById("statsRing")
    local radius = 125
    local total  = #statsList
    ring:destroyChildren()

    for index, stat in ipairs(statsList) do
        local offsetX, offsetY = calculateCircleMargin(radius, index, total)

        local btn = g_ui.createWidget('PowerUpButton', ring)
        btn:setId(stat.name:lower())
        btn:setImageSource("images/stats/" .. stat.image)
        btn:setSize({width = 63, height = 63})
        btn:addAnchor(AnchorHorizontalCenter, "parent", AnchorHorizontalCenter)
        btn:addAnchor(AnchorVerticalCenter,   "parent", AnchorVerticalCenter)
        btn:setMarginLeft(offsetX)
        btn:setMarginTop(offsetY)

        local fill = g_ui.createWidget('PowerUpFill', ring)
        fill:setId(stat.name:lower() .. "_fill")
        fill:setSize({width = 20, height = 20})
        fill:addAnchor(AnchorHorizontalCenter, btn:getId(), AnchorHorizontalCenter)
        fill:addAnchor(AnchorVerticalCenter,   btn:getId(), AnchorVerticalCenter)

        local btnIndex = ring:getChildIndex(btn)
        ring:lowerChild(fill, btnIndex)
    end
end

--------------------------------------------------
-- ?? Atualiza preenchimento
--------------------------------------------------
local function updateStatFill(statId, current, max)
    local fillWidget = powerUpWindow:recursiveGetChildById(statId .. "_fill")
    if not fillWidget then return end

    local percent = math.min(current / max, 1)

    local totalSize = 60
    local minSize = 0

    local dynamicSize = math.floor(minSize + (totalSize - minSize) * percent)
    local margin = math.floor((totalSize - dynamicSize) / 2)

    fillWidget:setWidth(dynamicSize)
    fillWidget:setHeight(dynamicSize)

    fillWidget:setMarginTop(margin)
    fillWidget:setMarginBottom(margin)
    fillWidget:setMarginLeft(margin)
    fillWidget:setMarginRight(margin)

    if percent >= 1 then
        fillWidget:setImageColor("#FFD700DD")
    elseif percent >= 0.66 then
        fillWidget:setImageColor("#00FF00AA")
    elseif percent >= 0.33 then
        fillWidget:setImageColor("#FFFF00AA")
    else
        fillWidget:setImageColor("#FF0000AA")
    end
end

--------------------------------------------------
-- ?? Dados recebidos
--------------------------------------------------
function onReceiveChangePowerUp(protocol, opcode, payload)
    local status, json_data = pcall(function() return json.decode(payload) end)
    if not status then return end

    if powerUpWindow.points then
        powerUpWindow.points:setText("Power Up\nPoints\n{" .. json_data.playerpoints .. "}")
    end

    for _, statsData in ipairs(json_data.statsData) do
        local statId = idMap[statsData.name:gsub("%s+", "")] or statsData.name:lower():gsub("%s+", "")
        local statWidget = powerUpWindow:recursiveGetChildById(statId)

        if statWidget then
            statWidget:setTooltip(string.format(
                "%s\n\nDescrição: %s\nBônus Atual: +%d%%\nLimite: %d%%\nPróximo Custo: %d pontos\nStatus: %s",
                statsData.name,
                statsData.description,
                statsData.statspoints,
                statsData.limit,
                statsData.nextPoints,
                statsData.unlocked and "Desbloqueado" or "Bloqueado"
            ))

            statWidget:setText("")

            if statsData.unlocked then
                statWidget:setOpacity(1.0)
                statWidget:setImageColor("#FFFFFF")
            else
                statWidget:setOpacity(0.7)
                statWidget:setImageColor("#281c1c")
            end

            statWidget.onClick = function()
                if statsData.isBlocked and not statsData.unlocked then
                    unlocked(statsData.name)
                else
                    g_game.getProtocolGame():sendExtendedOpcode(103, json.encode({
                        action = "addPoint",
                        category = statsData.name
                    }))
                end
            end

            updateStatFill(statId, statsData.statspoints, statsData.limit)
        else
        end
    end
end

--------------------------------------------------
-- ?? Reset
--------------------------------------------------
function doPlayerResetPowerUpPoints()
    g_game.getProtocolGame():sendExtendedOpcode(103, json.encode({action = "reset"}))
end

local resetWindow = nil
local resetIsClicked = false

function closeReset()
    if resetWindow then
        resetWindow:destroy()
        resetWindow = nil
        resetIsClicked = false
    end
end

function confirmResetPowerUpPoints()
    if not resetIsClicked then
        closeReset()
        resetIsClicked = true

        local yesCallback = function()
            closeReset()
            doPlayerResetPowerUpPoints()
        end

        local noCallback = function()
            closeReset()
        end

        resetWindow = displayGeneralBox(
            tr("Reset Power Up"),
            tr("Você deseja resetar todos os seus pontos de Power Up?\nIsso removerá todos os bônus aplicados."),
            {
                {text = tr('Yes'), callback = yesCallback},
                {text = tr('No'), callback = noCallback},
                anchor = AnchorHorizontalCenter
            },
            yesCallback,
            noCallback
        )
    end
end


--------------------------------------------------
-- ?? Desbloqueio
--------------------------------------------------
function closeUnlocked()
    if unlockedWindow then
        unlockedWindow:destroy()
        unlockedWindow = nil
        unlockedIsClicked = false
    end
end

function unlocked(name)
    if not unlockedIsClicked then
        closeUnlocked()
        unlockedIsClicked = true

        local yesCallback = function()
            closeUnlocked()
            g_game.getProtocolGame():sendExtendedOpcode(103, json.encode({
                action = "unlock",
                category = name
            }))
        end

        local noCallback = function()
            closeUnlocked()
        end

        unlockedWindow = displayGeneralBox(
            tr(name),
            tr("Você deseja desbloquear o stats " .. name .. "?"),
            {
                {text = tr('Yes'), callback = yesCallback},
                {text = tr('No'), callback = noCallback},
                anchor = AnchorHorizontalCenter
            },
            yesCallback,
            noCallback
        )
    end
end
