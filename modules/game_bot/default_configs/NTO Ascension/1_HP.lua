setDefaultTab("HP")

lblInfo= UI.Label("-- [[ HEAL ]] --")
lblInfo:setColor("green")
addSeparator()
Panels.Health () addSeparator() 

lblInfo= UI.Label("-- [[ FUGA ]] --")
lblInfo:setColor("green")
addSeparator()
addSeparator()

if type(storage.healing3) ~= "table" then
  storage.healing3 = {on=false, title="HP%", text="fuga", min=0, max=80}
end
if type(storage.healing4) ~= "table" then
  storage.healing4 = {on=false, title="HP%", text="fuga", min=0, max=70}
end
if type(storage.healing5) ~= "table" then
  storage.healing5 = {on=false, title="HP%", text="fuga", min=0, max=50}
end
if type(storage.healing6) ~= "table" then
  storage.healing6 = {on=false, title="HP%", text="fuga", min=0, max=30}
end

-- create 2 healing widgets
for _, healingInfo in ipairs({storage.healing3, storage.healing4, storage.healing5, storage.healing6}) do
  local healingmacro = macro(20, function()
    local hp = player:getHealthPercent()
    if healingInfo.max >= hp and hp >= healingInfo.min then
      if TargetBot then 
        TargetBot.saySpell(healingInfo.text) -- sync spell with targetbot if available
      else
        say(healingInfo.text)
      end
    end
  end)
  healingmacro.setOn(healingInfo.on)

  UI.DualScrollPanel(healingInfo, function(widget, newParams) 
    healingInfo = newParams
    healingmacro.setOn(healingInfo.on)
  end)
end UI.Separator() 

lblInfo= UI.Label("-- [[ POTS ]] --")
lblInfo:setColor("green")
addSeparator()
addSeparator()Panels.HealthItem()
Panels.HealthItem()
Panels.ManaItem() UI.Separator()



lblInfo= UI.Label("-- [[ FOOD ]] --")
lblInfo:setColor("green")
addSeparator()
addSeparator()
if type(storage.foodItems) ~= "table" then
  storage.foodItems = {3582, 3577}
end

local foodContainer = UI.Container(function(widget, items)
  storage.foodItems = items
end, true)
foodContainer:setHeight(35)
foodContainer:setItems(storage.foodItems)


macro(10000, "Eat Food", function()
  if player:getRegenerationTime() > 400 or not storage.foodItems[1] then return end
  -- search for food in containers
  for _, container in pairs(g_game.getContainers()) do
    for __, item in ipairs(container:getItems()) do
      for i, foodItem in ipairs(storage.foodItems) do
        if item:getId() == foodItem.id then
          return g_game.use(item)
        end
      end
    end
  end
end)