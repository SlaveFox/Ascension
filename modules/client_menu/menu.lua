local OpcodeReceivePlayerInfo = 222

local OtherTopMenu, buttonsWindow, menuWindow
local defaultHeight = 0

local function formatValueMenu(value)
    if value >= 1000000 then
        return string.format("%.2fkk", value / 1000000)
    elseif value >= 1000 then
        return string.format("%.2fk", value / 1000)
    else
        return tostring(value)
    end
end

function init()
	connect(g_game, {
		onGameStart = onGameStart,
		onGameEnd = onGameEnd
	})
    buttonsWindowExtra = g_ui.loadUI("extramenu", modules.game_interface.getRootPanel())

	buttonsWindow = g_ui.loadUI("buttons", g_ui.getRootWidget())
	for _, buttonMenu in ipairs(buttonsWindow:getChildren()) do
	  buttonMenu.onClick = onMenuChange
	end

	menuWindow = g_ui.loadUI("menu", g_ui.getRootWidget())
	menuWindow:hide()
	defaultHeight = menuWindow:getHeight()

	OtherTopMenu = menuWindow:getChildById("otherMenu")
	OtherTopMenu:setMarginTop(buttonsWindow:getChildById("otherMenu"):getHeight() + 6)
	OtherTopMenu:hide()

	ProtocolGame.registerExtendedOpcode(OpcodeReceivePlayerInfo, OpenMenuClient)
	if g_game.isOnline() then
		onGameStart()
	end
end

function terminate()
	disconnect(g_game, {onGameEnd = onGameEnd})
	ProtocolGame.unregisterExtendedOpcode(OpcodeReceivePlayerInfo)
	menuWindow:destroy()
	buttonsWindow:destroy()
	OtherTopMenu:destroy()
end

function getMenuWindow()
	return buttonsWindow
end

function onGameEnd()
	menuWindow:getChildById("menuButton"):setOn(false)
	buttonsWindow:getChildById("otherMenu"):setOn(false)
	buttonsWindow:hide()
	OtherTopMenu:hide()
	menuWindow:hide()
end

function onGameStart()
	menuWindow:show()
	menuWindow:getChildById("menuButton"):setOn(true)
	menuWindow:setFocusable(false)
	buttonsWindow:show()
end

function onMenuChange(self)

	if self:getId() == "Shop" then
		modules.game_shop.sendShopInfo()
	elseif self:getId() == "Options" then
		modules.client_options.toggle()
	elseif self:getId() == "Pass" then
        modules.game_pass.toggle()
	elseif self:getId() == "Goal" then
		modules.game_goal.toggle()
	elseif self:getId() == "Battle" then
		modules.game_battle.toggle()
	elseif self:getId() == "Minimap" then
		modules.game_minimap.toggle()
	elseif self:getId() == "Bestiary" then
		modules.game_bestiary.toggle()
	elseif self:getId() == "ZoomIn" then
		g_app.scaleUp()
	elseif self:getId() == "ZoomOut" then
		g_app.scaleDown()
	elseif self:getId() == "otherMenu" then
		toggleButtonsExtra()
	end
end

function onToggleOtherMenu(button)
	if OtherTopMenu:isVisible() then
		menuWindow:setHeight(defaultHeight)
		OtherTopMenu:hide()
		button:setOn(false)
		return
	end

	button:setOn(true)
	menuWindow:setHeight(menuWindow:getHeight() + OtherTopMenu:getHeight())
	OtherTopMenu:show()
end

function toggleButtons()
	if buttonsWindow:isVisible() then
		menuWindow:getChildById("menuButton"):setOn(false)
		buttonsWindow:getChildById("otherMenu"):setOn(false)
		g_effects.fadeOut(buttonsWindow, 350)

		if OtherTopMenu:isVisible() then
			onToggleOtherMenu(menuWindow:getChildById("otherMenu"))
		end
		
		scheduleEvent(function ()
			buttonsWindow:hide()
			buttonsWindowExtra:hide()
		end, 400)
		g_effects.fadeOut(buttonsWindowExtra, 350)
        scheduleEvent(function ()
            buttonsWindowExtra:hide()
        end, 400)
	else
		menuWindow:getChildById("menuButton"):setOn(true)
		menuWindow:setFocusable(false)
		buttonsWindow:show()
		g_effects.fadeIn(buttonsWindow, 350)
	end
end

local function addButton(id, description, icon, callback, panel)
	local class = 'OtherMenuButton'
	local button = panel:getChildById(id)

	if not button then
		button = g_ui.createWidget(class, panel)
	end

	button:setId(id)
	button:setTooltip(description)
	button:setImageSource(icon)

	button.onMouseRelease = function(widget, mousePos, mouseButton)
		if widget:containsPoint(mousePos) and mouseButton ~= MouseMidButton and mouseButton ~= MouseTouch then
			callback()
			return true
		end
	end

  return button
end

function addOtherMenuGameButton(id, description, icon, callback)
	local button = addButton(id, description, icon, callback, OtherTopMenu.moduleList)
	return button
end

function OpenMenuClient(protocol, opcode, buffer)
	local status, json_data = pcall(function ()
		return json.decode(buffer)
	end)

	if json_data.type == "update" then
		local player = g_game.getLocalPlayer()
		buttonsWindow.playerInfo.name:setText(player:getName())
		buttonsWindow.playerInfo.money:setText(formatValueMenu(json_data.playerMoney))
		buttonsWindow.playerInfo.classe:setText(json_data.playerClasse)
	elseif json_data.type == "updatePoints" then
		buttonsWindow.playerInfo.points:setText(json_data.points)
	end
end

function toggleButtonsExtra()
    if buttonsWindowExtra:isVisible() then
        -- menuextra = menuWindow:getChildById("menuButton")
        menuWindow:getChildById("menuButton")
        g_effects.fadeOut(buttonsWindowExtra, 350)
        scheduleEvent(function ()
            buttonsWindowExtra:hide()
        end, 400)
    else
        menuWindow:getChildById("menuButton")
        buttonsWindowExtra:show()
        g_effects.fadeIn(buttonsWindowExtra, 350)
		-- menuextra:setFocusable(false)
		menuWindow:setFocusable(false)
    end
end
