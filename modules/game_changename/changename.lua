local name, searchName, buttonChange = nil
local opcodeOpenModule = 250  -- para abrir a interface
local Change_name = nil
local MIN_CHARACTERS = 5
local MAX_CHARACTERS = 16

function init()
  connect(g_game, { onGameStart = naoexibir, onGameEnd = naoexibir })
  connect(LocalPlayer, { onPositionChange = onPositionChange })

  Change_name = modules.client_topmenu.addRightGameToggleButton('Change name', tr('Change name'), '/images/topbuttons/healthinfo', exibir)
  Change_name:setWidth(32)
  Change_name:setOn(false)
  
  name = g_ui.displayUI("changename", modules.game_interface.getRootPanel())
  searchName = name:getChildById("searchName")
  buttonChange = name:getChildById("changeNick")
  
  name:hide()
  
  ProtocolGame.registerExtendedOpcode(opcodeOpenModule, function(protocol, opcode, buffer)
    onReceiveChangeName(buffer)
  end)
  
  -- Configuração dos handlers para o campo de texto e botão
  searchName.onTextChange = function(self, value)
    if not value or value == "" then return end
    if string.match(value, "%d") then
      displayErrorBox(tr("Trocar de nome"), "Você não pode colocar números em seu nome.")
      self:setText("")
      return
    end
    if #value > MAX_CHARACTERS then
      displayErrorBox(tr("Trocar de nome"), "Limite máximo de 16 caracteres.")
      self:setText("")
      return
    end
  end

  buttonChange.onClick = function()
    local newName = searchName:getText()
    if not newName or newName == "" then
      displayErrorBox(tr("Trocar de nome"), "Você precisa digitar um nome para trocar o nome.")
      return
    end
    if #newName < MIN_CHARACTERS then
      displayErrorBox(tr("Trocar de nome"), "O nome precisa ter no mínimo 5 caracteres.")
      return
    end
    -- Envia a solicitação de troca de nome usando o opcode **251** e JSON.
    local payload = json.encode({ action = "changeName", newName = newName })
    g_game.getProtocolGame():sendExtendedOpcode(251, payload)
  end
end

function onPositionChange(creature, newPos, oldPos)
  if creature:isLocalPlayer() and name:isVisible() then
    naoexibir()
  end
end

function terminate()
  disconnect(g_game, { onGameStart = naoexibir, onGameEnd = naoexibir })
  disconnect(Creature, { onPositionChange = onPositionChange })
  ProtocolGame.unregisterExtendedOpcode(opcodeOpenModule)
  Change_name:setOn(false)
  name:hide()
end

function exibir()
  if name:isVisible() then
    Change_name:setOn(false)
    naoexibir()
  else
    Change_name:setOn(true)
    name:show()
    addEvent(function() g_effects.fadeIn(name, 500) end)
  end
end

function naoexibir()
  name:hide()
  searchName:clearText()
  Change_name:setOn(false)
end

function onReceiveChangeName(buffer)
  local data = json.decode(buffer)
  if data and data.action == "open" then
    exibir()
  end
end
