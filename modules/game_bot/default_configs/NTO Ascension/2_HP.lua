 -- config
setDefaultTab("HP")
 


lblInfo= UI.Label("-- [[ ANTI-PARALYZE ]] --")
lblInfo:setColor("green")
addSeparator()
addSeparator() Panels.AntiParalyze() UI.Separator() 

lblInfo= UI.Label("-- [[ SPEED ]] --")
lblInfo:setColor("green")
addSeparator()
addSeparator() Panels.Haste() UI.Separator() 

lblInfo= UI.Label("-- [[ BUFF ]] --")
lblInfo:setColor("green")
addSeparator()
addSeparator()


buffz = macro(1000, "Buff", function()
if not hasPartyBuff() and not isInPz() then
 say(storage.buff)
schedule(1300, function() say(storage.buff2) end)
end
end)



addTextEdit("buff", storage.buff or "buff", function(widget, text) storage.buff = text
end)

        color= UI.Label("Buff 2:",hpPanel4)
color:setColor("green")


addTextEdit("buff2", storage.buff2 or "buff 2", function(widget, text) storage.buff2 = text
end) UI.Separator()

addIcon("Buff", {item=2660, text="Buff"},buffz)




lblInfo= UI.Label("-- [[ TREINO ]] --")
lblInfo:setColor("green")
addSeparator()
addSeparator()
if type(storage.manatrainer) ~= "table" then
  storage.manatrainer = {on=false, title="mana%", text="Power Down", min=0, max=90}
end

for _, healingInfos in ipairs({storage.manatrainer}) do
  local healingmacro = macro(20, function()
    local mana = manapercent()
    if healingInfos.max <= mana and mana >= healingInfos.min then
      if TargetBot then 
        TargetBot.saySpell(healingInfos.text) -- sync spell with targetbot if available
      else
        say(healingInfos.text)
      end
    end
  end)
  healingmacro.setOn(healingInfos.on)

  UI.DualScrollPanel(healingInfos, function(widget, newParams) 
    healingInfos = newParams
    healingmacro.setOn(healingInfos.on)
  end)
end 
healingmacro = macro(20, "Dance", function()
    turn(math.random(0, 3))
end)



