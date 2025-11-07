local OPCODE_PARTY = 32

local minimap = modules.game_minimap
local minimapWidget = minimap.minimapWindow:recursiveGetChildById('minimap')

local partyMembers = {}

function init()
  g_ui.displayUI('game_partyicons')
  ProtocolGame.registerExtendedOpcode(OPCODE_PARTY, onPartyUpdate)
end
  
function terminate()
  ProtocolGame.unregisterExtendedOpcode(OPCODE_PARTY, onPartyUpdate)
  for name, data in pairs(partyMembers) do
    removeMemberIcon(name)
  end
end

function updateMemberWidget(member)
  local localPlayerName = g_game.getLocalPlayer():getName()
  if member.name == localPlayerName then
    return
  end

  local data = partyMembers[member.name]
  if not data then
    local widget = g_ui.createWidget("PlayerIcon", minimapWidget)
    widget:setImageSource("icons/" .. member.vocation)
    widget.name:setText(member.name)
    data = {
      widget = widget,
      timer = nil
    }
    partyMembers[member.name] = data
  else
    data.widget:setImageSource("icons/" .. member.vocation)
  end

  local pos = member.pos
  pos.z = minimapWidget:getCameraPosition().z
  minimapWidget:centerInPosition(data.widget, pos)
  data.widget.name:setMarginTop(-10)
  minimapWidget:centerInPosition(data.widget.name, pos)

  if data.timer then
    removeEvent(data.timer)
  end
  data.timer = scheduleEvent(function() removeMemberIcon(member.name) end, 1500)
end

function removeMemberIcon(name)
  local data = partyMembers[name]
  if data then
    if data.widget then
      data.widget:destroy()
    end
    if data.timer then
      removeEvent(data.timer)
    end
    partyMembers[name] = nil
  end
end

function onPartyUpdate(protocol, opcode, buffer)
  local status, data = pcall(function() return json.decode(buffer) end)
  if not status then
    -- print("Error decoding JSON from server.")
    return
  end

  if data.type == "join" or data.type == "update" then
    for _, member in pairs(data.members) do
      updateMemberWidget(member)
    end
  elseif data.type == "leave" then
    removeMemberIcon(data.name)
  end
end