local rankingsWindow = nil
local rankingsCombo = nil
local rankingScroll = nil

function init()
  connect(g_game, { onGameEnd = destroy })
  ProtocolGame.registerExtendedOpcode(202, onRankingDataReceived)
end

function terminate()
  disconnect(g_game, { onGameEnd = destroy })
  ProtocolGame.unregisterExtendedOpcode(202)
  destroy()
end

function destroy()
  if rankingsWindow then
    rankingsWindow:destroy()
    rankingsWindow = nil
    rankingScroll = nil
    rankingsCombo = nil
  end
end

-- expõe o módulo para a UI
modules = modules or {}
modules.game_rankings = modules.game_rankings or {}

-- abre ou fecha a janela de rankings
function modules.game_rankings.toggleRankingsWindow()
  if rankingsWindow and rankingsWindow:isVisible() then
    rankingsWindow:hide()
  else
    openRankings()
  end
end


function openRankings()
  if not rankingsWindow then
    rankingsWindow = g_ui.loadUI('/modules/game_rankings/rankings.otui', modules.game_interface.getRootPanel())
    rankingsCombo = rankingsWindow:getChildById('skillComboBox')
    rankingScroll = rankingsWindow:getChildById('rankingScrollContainer'):getChildById('rankingScroll')
    rankingsCombo.onOptionChange = onSkillSelected
  end
  rankingsWindow:show()
  rankingsWindow:raise()
  rankingsWindow:focus()

  requestRanking(rankingsCombo:getCurrentOption() or "level")
end

function requestRanking(skill)
  local skillName = type(skill) == "table" and skill.text or skill
  g_game.getProtocolGame():sendExtendedOpcode(202, json.encode({
    action = "requestRanking",
    skill = skillName
  }))
end

function onSkillSelected(comboBox, option)
  requestRanking(option)
end


function onRankingDataReceived(protocol, opcode, buffer)
  local data = json.decode(buffer)
  if data and data.action == "open" then
    openRankings()
    return
  end
  if data and data.action == "rankingData" and data.list then
    rankingScroll:destroyChildren()
    for index, entry in ipairs(data.list) do
      local widget = g_ui.createWidget("RankEntry", rankingScroll)
      if not widget then goto continue end
  
      -- 1) posição real (#rank) se for você, caso contrário usa o índice
      local trueRank = entry.isSelf and entry.rank or index
      widget:getChildById("rankLabel"):setText("#"..trueRank)
  
      -- 2) texto e cor do nome/valor
      local nameLabel  = widget:getChildById("nameLabel")
      local valueLabel = widget:getChildById("valueLabel")
      nameLabel :setText(entry.name)
      valueLabel:setText(entry.date
        and os.date("%d/%m/%y", entry.date)
        or tostring(entry.value)
      )
  
      if entry.isSelf then
        -- pinta de azul
        widget:getChildById("rankLabel"):setColor("#00AFFF")
        nameLabel              :setColor("#00AFFF")
        valueLabel             :setColor("#00AFFF")
      end
  
      -- 3) outfit e tooltip continuam iguais...
      local outfitBox = widget:getChildById("outfitWidget"):getChildById("outfitBox")
      if entry.outfit and outfitBox then
        outfitBox:setOutfit({type = entry.outfit.lookType})
        outfitBox:setAnimate(true)
        outfitBox:setMarginRight(15)
        outfitBox:setMarginTop(-15)
  
        local tip
        if entry.date then
          local d = os.date("%d/%m/%y", entry.date)
          local t = os.date("%H:%M",   entry.date)
          tip = string.format(
            "%s morreu por %s no dia %s às %s",
            entry.name, entry.killedBy or "desconhecido", d, t
          )
        else
          tip = string.format("%s\nVocação: %s", entry.name, entry.vocation or "Desconhecida")
        end
        outfitBox:setTooltip(tip)
      end
  
      ::continue::
    end
  end
end




-- Função para fechar a janela de rankings
function closeRankingWindow()
  if rankingsWindow then
    rankingsWindow:hide()  -- Esconde a janela de rankings
  end
end