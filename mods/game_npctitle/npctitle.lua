local npcTitles = {
  ["Minoru"]  = { title = "E o Barquinho",  color = "#00FF00", font = "baby-10" },
  ["Kanetsugu"]  = { title = "Banker",  color = "#00FF00", font = "baby-10" },
  ["Ryouga"]  = { title = "Mercante",  color = "#00FF00", font = "baby-10" },
  ["Kurotsugi"]  = { title = "Black Market",  color = "#00FF00", font = "baby-10" },
  ["Yumeko"]  = { title = "Bless",  color = "#00FF00", font = "baby-10" },
  ["Hiromi"]  = { title = "Bags",  color = "#00FF00", font = "baby-10" },
  ["Chinatsu"]  = { title = "Potions",  color = "#00FF00", font = "baby-10" },
  ["{NPC} Anbu"]  = { title = "Task",  color = "#00FF00", font = "baby-10" },
  ["{NPC} Deidara"]  = { title = "Task",  color = "#00FF00", font = "baby-10" },
  ["{NPC} Raiga Kurosuki"]  = { title = "Task",  color = "#00FF00", font = "baby-10" },
  ["{NPC} Temari"]  = { title = "Task",  color = "#00FF00", font = "baby-10" },
  ["{NPC} Ryotaro"]  = { title = "Task",  color = "#00FF00", font = "baby-10" },
  ["{NPC} Itachi"]  = { title = "Task",  color = "#00FF00", font = "baby-10" },
  ["{NPC} Hidan"]  = { title = "Task",  color = "#00FF00", font = "baby-10" },
  ["{NPC} Kisame"]  = { title = "Task",  color = "#00FF00", font = "baby-10" },
  ["{NPC} Sasori"]  = { title = "Task",  color = "#00FF00", font = "baby-10" },
  ["{NPC} Madara"]  = { title = "Task",  color = "#00FF00", font = "baby-10" },
  ["{NPC} Markinhos"]  = { title = "Task",  color = "#00FF00", font = "baby-10" },
  ["{NPC} Raikage"]  = { title = "Task",  color = "#00FF00", font = "baby-10" },
  ["{NPC} Valhir"]  = { title = "Task",  color = "#00FF00", font = "baby-10" },
  ["{NPC} Shisui Uchiha"]  = { title = "Task",  color = "#00FF00", font = "baby-10" },
  ["{Anbu} Danzou Shimura"]  = { title = "Alliance",  color = "#00FF00", font = "baby-10" },
  ["{Akatsuki} Tobi"]  = { title = "Alliance",  color = "#00FF00", font = "baby-10" },
  ["{Mercenary} Fukurou"]  = { title = "Alliance",  color = "#00FF00", font = "baby-10" },
  ["npc9"]  = { title = "[NPC9 Title]",  color = "#00FF00", font = "baby-10" },
  ["npc10"] = { title = "[NPC10 Title]", color = "#00FF00", font = "baby-10" }
}

function init()
  connect(Creature, { onAppear = updateTitle })
end

function terminate()
  disconnect(Creature, { onAppear = updateTitle })
end

function updateTitle(creature)
  if not creature:isNpc() then return end
  local data = npcTitles[creature:getName()]
  if data then
    creature:setTitle(data.title, data.font, data.color)
  end
end
