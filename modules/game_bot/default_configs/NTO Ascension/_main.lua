UI.Separator()
local showhp = macro(20000, "Monstro Hp %", function() end)
onCreatureHealthPercentChange(function(creature, healthPercent)
    if showhp:isOff() then  return end
    if creature:isMonster() or creature:isPlayer() and creature:getPosition() and pos() then
        if getDistanceBetween(pos(), creature:getPosition()) <= 5 then
            creature:setText(healthPercent .. "%")
        else
            creature:clearText()
  

      end
    end
end)

UI.Separator ()

macro(1000, "Juntar itens", function()
  local containers = g_game.getContainers()
  local toStack = {}
  for index, container in pairs(containers) do
    if not container.lootContainer then -- ignore monster containers
      for i, item in ipairs(container:getItems()) do
        if item:isStackable() and item:getCount() < 100 then
          local stackWith = toStack[item:getId()]
          if stackWith then
            g_game.move(item, stackWith[1], math.min(stackWith[2], item:getCount()))
            return
          end
          toStack[item:getId()] = {container:getSlotPosition(i - 1), 100 - item:getCount()}
        end
      end
    end
  end
end)

UI.Separator()

macro(250, "Atacar Seguindo", "Shift+R", function()
   if g_game.isOnline() and g_game.isAttacking() then
         g_game.setChaseMode(1)
           end
           end)

UI.Separator()

macro(1000, "Abrir proxima Bag", function()
  local containers = getContainers()
  for i, container in pairs(containers) do
    if container:getItemsCount() == container:getCapacity() then
      for _, item in ipairs(container:getItems()) do
        if item:isContainer() then
          g_game.open(item, container)
        end
      end
    end
  end
end)

UI.Separator()

local pt = false
addSwitch("pt", "Auto PT = falar pt", function(widget)
    pt = not pt
    widget:setOn(pt)
end)

onTalk(function(name, level, mode, text, channelId, pos)
if name == player:getName() then return end
    if mode ~= 1 then  return end
    if string.find(text, "pt")  and pt == true then
        local friend = getPlayerByName(name)
        g_game.partyInvite(friend:getId())
    end
end)

UI.Separator()

macro(1000, "Abrir Bag Principal", function()
    bpItem = getBack()
    bp = getContainer(0)

    if not bp and bpItem ~= nil then
        g_game.open(bpItem)
    end

end)
UI.Separator()


if type(storage.moneyItems) ~= "table" then
  storage.moneyItems = {3031, 3035}
end
macro(1000, "Converter dinheiro", function()
  if not storage.moneyItems[1] then return end
  local containers = g_game.getContainers()
  for index, container in pairs(containers) do
    if not container.lootContainer then -- ignore monster containers
      for i, item in ipairs(container:getItems()) do
        if item:getCount() == 100 then
          for m, moneyId in ipairs(storage.moneyItems) do
            if item:getId() == moneyId.id then
              return g_game.use(item)
            end
          end
        end
      end
    end
  end
end)

local moneyContainer = UI.Container(function(widget, items)
  storage.moneyItems = items
end, true)
moneyContainer:setHeight(35)
moneyContainer:setItems(storage.moneyItems)
UI.Separator()

local afkMsg = false
addSwitch("afkMsg", "Responder PM AFK", function(widget)
    afkMsg = not afkMsg
    widget:setOn(afkMsg)
end)

onTalk(function(name, level, mode, text, channelId, pos) --quando receber uma pm vai responder com a mensagem escolhida abaixo
    if mode == 4 and afkMsg == true then
        g_game.talkPrivate(5, name, storage.afkMsg)
        delay(5000)
    end
end)
UI.TextEdit(storage.afkMsg or "MENSAGEM", function(widget, newText)
storage.afkMsg = newText
end)

UI.Separator()

macro(60000, "Msg trade", function()
  local Trade = getChannelId("advertising")
  if not Trade then
    Trade = getChannelId("Trade")
  end
  if Trade and storage.autoTradeMessage:len() > 0 then    
    sayChannel(Trade, storage.autoTradeMessage)
  end
end)
UI.TextEdit(storage.autoTradeMessage or "hi ", function(widget, text)    
  storage.autoTradeMessage = text
end)

UI.Separator()
macro(60000, "Msg Help", function()
  local Help = getChannelId("advertising")
  if not Help then
    Help = getChannelId("Help")
  end
  if Help and storage.autoHelpMessage:len() > 0 then    
    sayChannel(Help, storage.autoHelpMessage)
  end
end)
UI.TextEdit(storage.autoHelpMessage or "hi", function(widget, text)    
  storage.autoHelpMessage = text
end)

UI.Separator()