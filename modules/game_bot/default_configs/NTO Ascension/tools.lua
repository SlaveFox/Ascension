-- tools tab
setDefaultTab("Tools")


UI.Separator()

comboss = macro(200, "Combo",  function()
if g_game.isAttacking() then
say(storage.ComboText)
say(storage.Combo1Text)
say(storage.Combo2Text)
say(storage.Combo3Text)
say(storage.Combo4Text)
say(storage.Combo5Text)
say(storage.Combo6Text)
end

end)
addTextEdit("ComboText", storage.ComboText or "magia 1", function(widget, text) 
storage.ComboText = text
end)
addTextEdit("Combo1Text", storage.Combo1Text or "magia 2", function(widget, text) storage.Combo1Text = text
end)
addTextEdit("Combo2Text", storage.Combo2Text or "magia 3", function(widget, text) storage.Combo2Text = text
end)
addTextEdit("Combo3Text", storage.Combo3Text or "magia 4", function(widget, text) storage.Combo3Text = text
end)
addTextEdit("Combo4Text", storage.Combo4Text or "magia 5", function(widget, text) storage.Combo4Text = text
end)
addTextEdit("Combo5Text", storage.Combo5Text or "magia 6", function(widget, text) storage.Combo5Text = text
end)
addTextEdit("Combo6Text", storage.Combo6Text or "magia 7", function(widget, text) storage.Combo6Text = text
end)



addIcon("Combo", {item=2660, text="Combo"},comboss)
























UI.Separator()


-- allows to test/edit bot lua scripts ingame, you can have multiple scripts like this, just change storage.ingame_lua
UI.Button("Hotkeys", function(newText)
  UI.MultilineEditorWindow(storage.ingame_hotkeys or "", {title="Hotkeys editor", description="Adicione suas scripts aqui!\nBy: @Luiz"}, function(text)
    storage.ingame_hotkeys = text
    reload()
  end)
end)



for _, scripts in pairs({storage.ingame_hotkeys}) do
  if type(scripts) == "string" and scripts:len() > 3 then
    local status, result = pcall(function()
      assert(load(scripts, "ingame_editor"))()
    end)
    if not status then 
      error("Hotkeys:\n" .. result)
    end
  end
end

UI.Separator()



playSound("/sounds/click.ogg")
      warn("Bem-vindo a custom free\nBy: @Luiz")