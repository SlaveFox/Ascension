local Calendar, MonthPanel, ShopPanel, ShopScrollBar
local Key = "Ctrl+J"
local CLAN_OPCODE = 18

local TIME_REQUIRED_ONLINE = 3 * 3600 -- 8 horas em segundos
-- local onlineTime
local updateEvent

local currentMonth = os.date('*t').month
local currentYear = os.date('*t').year

function init()

  
  connect(g_game, {
    onGameStart = refresh,
    onGameEnd = refresh,
  })
  
  Calendar = g_ui.loadUI('calendar', modules.game_interface.getRootPanel())
  MonthPanel = Calendar:getChildById("monthPanel")
  ShopPanel = Calendar:getChildById("shopPanel")
  ShopScrollBar = Calendar:getChildById('shopScrollBar')
  
  -- calendarButton = modules.client_topmenu.addRightGameToggleButton('dailyRewardButton', tr('Calendar'), '/images/topbuttons/calendar', toggle, false, 1)
  -- calendarButton:setOn(true) 
  Calendar:hide()
  -- g_keyboard.bindKeyDown(Key, toggle) 
            
  ProtocolGame.registerExtendedOpcode(CLAN_OPCODE, SendClanInfo)
end

function terminate()
  disconnect(g_game, {
    onGameStart = refresh,
    onGameEnd = refresh,
  })
  
  ProtocolGame.unregisterExtendedOpcode(CLAN_OPCODE)
  Calendar:destroy()
  	if updateEvent then
     removeEvent(updateEvent)
     updateEvent = nil
  end
end

function refresh()
  Calendar:hide()
  ShopPanel:destroyChildren()
end

function toggle()
  if Calendar:isVisible() then
    Calendar:hide()
	if updateEvent then
     removeEvent(updateEvent)
     updateEvent = nil
  end
  else
    Calendar:show()
	startUpdatingProgressBar()
  end          
 g_game.getProtocolGame():sendExtendedOpcode(CLAN_OPCODE, json.encode{protocol = "Open", month = os.date('*t').month, year = os.date('*t').year})
end

function showCalendar()
  ShopPanel:hide()
  ShopScrollBar:hide()
  MonthPanel:show()
end


function showShop()
  g_game.getProtocolGame():sendExtendedOpcode(CLAN_OPCODE, json.encode{protocol = "Shop"})
  MonthPanel:hide()
  ShopPanel:show()
  ShopScrollBar:show()
end

function buyShopItem(id)
	g_game.getProtocolGame():sendExtendedOpcode(CLAN_OPCODE, json.encode{protocol = "BuyItem", id = id})
end

function requestCalendar(value)
  currentMonth = currentMonth + value
  if currentMonth == 13 then
    currentYear = currentYear + 1
	currentMonth = 1
  elseif currentMonth == 0 then
    currentYear = currentYear - 1
	currentMonth = 12
  end
  g_game.getProtocolGame():sendExtendedOpcode(CLAN_OPCODE, json.encode{protocol = "Request", month = currentMonth, year = currentYear})
end


function SendClanInfo(protocol, opcode, buffer)
  local receive = json.decode(buffer)
  local protocol = receive.protocol
	
  if protocol == "OpenCalendarFromServer" then
    -- Faz a mesma l�gica que o "toggle()" fazia:
    if Calendar:isVisible() then
      Calendar:hide()
      if updateEvent then
        removeEvent(updateEvent)
        updateEvent = nil
      end
    else
      Calendar:show()
      startUpdatingProgressBar()
    end

    -- Aqui avisamos o servidor que queremos os dados do calend�rio (dias, recompensas etc).
    g_game.getProtocolGame():sendExtendedOpcode(CLAN_OPCODE, json.encode{
      protocol = "Open",
      month = os.date('*t').month,
      year  = os.date('*t').year
    })

  elseif protocol == "rewards" then
    drawMonth(currentMonth, currentYear, receive.tab.rewards, receive.tab.currentDate, receive.OnlineTime)
    Calendar:getChildById("points"):setText(receive.tab.points .. " Daily Points")
  elseif protocol == "points" then
    local points = receive.points
	OnlineTime = receive.OnlineTime
    Calendar:getChildById("points"):setText(points .. " Daily Points")
	updateProgressBar(OnlineTime)
  elseif protocol == "shop" then
	ShopPanel:destroyChildren()
    for id, info in pairs(receive.shop) do
      local widget = g_ui.createWidget("DRShopWidget", ShopPanel)
      widget:setId("shop" .. id)
      widget:setPaddingLeft(10)
      widget:getChildById("item"):setItemId(info.itemId)
      widget:getChildById("item"):setItemCount(info.qnt)
      widget:getChildById("name"):setText(info.name .. " (" .. info.qnt .. ")")
      widget:getChildById("price"):setText(tr("Price") .. ": " .. info.price)
      widget:getChildById("buy").onClick = function()
        buyShopItem(id)
      end
    end
  end
end


--- FUN��ES DE SUPORTE

January   = 1
February  = 2
March     = 3
April     = 4
May       = 5
June      = 6
July      = 7
August    = 8
September = 9
October   = 10
November  = 11
December  = 12

Monday    = 0
Tuesday   = 1
Wednesday = 2
Thursday  = 3
Friday    = 4
Saturday  = 5
Sunday    = 6

months = {
  [January]   =  {name = "Janeiro"  },
  [February]  =  {name = "Fevereiro"},
  [March]     =  {name = "Mar�o"   },
  [April]     =  {name = "Abril"   },
  [May]       =  {name = "Maio"    },
  [June]      =  {name = "Junho"   },
  [July]      =  {name = "Julho"   },
  [August]    =  {name = "Agosto"  },
  [September] =  {name = "Setembro"},
  [October]   =  {name = "Outubro" },
  [November]  =  {name = "Novembro"},
  [December]  =  {name = "Dezembro"},
}

function drawMonth(month, year, rewards, currentDate)
  MonthPanel:getChildById("month"):setText(months[month].name.." "..year.."")
  MonthPanel:getChildById("days"):destroyChildren()
  local weekChar = {"Dom", "Seg", "Ter", "Qua", "Qui", "Sex", "Sab"}
  local line = 1
  local column = 1
  local maxColumn = 7
  local maxLine = 5
  for w=1, 7 do
    local widget = g_ui.createWidget("WeekWidget", MonthPanel:getChildById("days"))
	widget:setId(weekChar[w])
	widget:setText(weekChar[w])
    widget:setMarginTop((1 + widget:getHeight()) * (line - 1))
    widget:setMarginLeft((7 + widget:getWidth()) * (column - 1))
    if (column < maxColumn) then
      column = column+1
    else
      line = line+1
      column = 1
    end
  end

  local weekDay = getFirstMonthDay(month, year)
  local monthDays = getWeekNumDays(month, year)
  
  for day=(1-weekDay), monthDays do
    local widget = g_ui.createWidget("DayWidget", MonthPanel:getChildById("days"))
	widget:setId(tostring(day))
	
    widget:setMarginTop(((1 + (line == 1 and 20 or widget:getHeight())) * (line - 1)) - (line > 1 and 20 or 0))
    widget:setMarginLeft((7 + widget:getWidth()) * (column - 1))
    if (column < maxColumn) then
      column = column+1
    else
      line = line+1
      column = 1
    end
	if day > 0 then
	  widget:getChildById("name"):setText(day)
	  if rewards[day] then
	    widget:getChildById("item"):setItemId(rewards[day].itemid)
	    widget:getChildById("item"):setItemCount(rewards[day].count)
		widget:setTooltip(rewards[day].count .. " " .. rewards[day].rewardName)
		if day <= currentDate.day and month <= currentDate.month and year <= currentDate.year then
		  widget:getChildById("mask"):setImageSource(rewards[day].collected == 1 and "images/collected" or "images/lost")
		  widget:getChildById("mask"):setVisible(true)
		end
	  end
	  if day == currentDate.day and (rewards[day] and rewards[day].collected <= 0) then
	    widget:setTooltip("Coletar recompensa")
		widget:getChildById("mask"):setImageSource("images/collect") -- imagem antes de coletar
	    widget.onClick = function()
		  g_game.getProtocolGame():sendExtendedOpcode(CLAN_OPCODE, json.encode{protocol = "Collect"})
		end
	  end
	end
  end
  for c = column, maxColumn do
    local widget = g_ui.createWidget("DayWidget", MonthPanel:getChildById("days"))
	widget:setId("extra"..c)
    widget:setMarginTop(((1 + (line == 2 and 20 or widget:getHeight())) * (line - 1)) - (line > 2 and 20 or 0))
    widget:setMarginLeft((7 + widget:getWidth()) * (column - 1))
    if (column < maxColumn) then
      column = column+1
    else
      line = line+1
      column = 1
    end
  end
end

function getFirstMonthDay(month, year)
  local weekDay = Tuesday
  for i=1900, (year-1), 1 do
    weekDay = (weekDay + 365) % 7
	if (isYearLeap(i)) then
	  weekDay = (weekDay + 1) % 7
	end
  end
  for i=1, (month-1) do
    weekDay = (weekDay + getWeekNumDays(i, year)) % 7
  end
  return weekDay
end

function isYearLeap(year)
  return ((year % 4 == 0) and (year % 100 ~= 0)) or (year % 400 == 0)
end

function getWeekNumDays(month, year)
  if month == February then
    return isYearLeap(year) and 29 or 28
  elseif month == April or month == June or month == September or month == November then
    return 30
  else
    return 31
  end
end

function getColorsTime(onlineTime)
  if onlineTime < 3 then
    return 'red'
  elseif onlineTime < 6 then
    return 'yellow'
  else
    return 'green'
  end
end

function updateProgressBar(OnlineTime)
  local progressBar = Calendar:getChildById('progressBar')

  local timeLeft = TIME_REQUIRED_ONLINE - OnlineTime
  timeLeft = math.max(timeLeft, 0)

  if timeLeft <= 0 then
    progressBar:setValue(100)
    progressBar:setText("Recompensa dispon�vel!")
	progressBar:setBackgroundColor('green')
  else
    local percentage = (OnlineTime / TIME_REQUIRED_ONLINE) * 100
	progressBar:setValue(percentage, 0, 100)
	progressBar:setBackgroundColor(getColorsTime(OnlineTime / 3600))
    progressBar:setText("Coleta em: " .. convertSecondsToString(timeLeft))
  end
  if updateEvent then
    removeEvent(updateEvent)
  end
  -- Otimização: aumentar intervalo de 1000ms para 2000ms (2 segundos)
  -- Reduz pela metade a frequência de atualizações
  updateEvent = scheduleEvent(function() updateProgressBar(OnlineTime + 2) end, 2000)
end

function convertSecondsToString(seconds)
  local hours = math.floor(seconds / 3600)
  local minutes = math.floor((seconds % 3600) / 60)
  local seconds = seconds % 60
  return string.format("%02d:%02d:%02d", hours, minutes, seconds)
end

function startUpdatingProgressBar()
  if updateEvent then
    removeEvent(updateEvent)
  end
  updateProgressBar(0) -- Come�a a atualizar com o tempo inicial
end